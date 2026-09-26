"""Reconcile declared RustFS buckets and local IAM users without logging secrets."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import sys
import time
import xml.etree.ElementTree as ET
from urllib.parse import urlencode

import boto3
from botocore.auth import SigV4Auth
from botocore.awsrequest import AWSRequest
from botocore.config import Config
from botocore.credentials import Credentials
from botocore.exceptions import ClientError
import requests


class ProvisionError(Exception):
    pass


def credential(directory, name):
    value = (directory / name).read_text().strip()
    if not value or any(c.isspace() for c in value):
        raise ProvisionError(f"Invalid credential file: {name}")
    return value


def policy(statements):
    return {"Version": "2012-10-17", "Statement": statements}


def writer_policy(buckets):
    return policy([
        {"Effect": "Allow", "Action": ["s3:GetBucketLocation", "s3:ListBucket", "s3:ListBucketMultipartUploads"],
         "Resource": [f"arn:aws:s3:::{name}" for name in buckets]},
        {"Effect": "Allow", "Action": ["s3:GetObject", "s3:PutObject", "s3:DeleteObject",
                                         "s3:AbortMultipartUpload", "s3:ListMultipartUploadParts"],
         "Resource": [f"arn:aws:s3:::{name}/*" for name in buckets]},
    ])


class Admin:
    def __init__(self, endpoint, region, access, secret):
        self.endpoint = endpoint
        self.region = region
        self.credentials = Credentials(access, secret)
        self.session = requests.Session()
        self.session.trust_env = False

    def call(self, method, operation, query=None, body=None, missing_ok=False):
        url = self.endpoint + "/rustfs/admin/v3/" + operation
        if query:
            url += "?" + urlencode(query)
        data = json.dumps(body).encode() if body is not None else b""
        request = AWSRequest(method=method, url=url, data=data, headers={
            "Content-Type": "application/json", "X-Amz-Content-SHA256": hashlib.sha256(data).hexdigest()
        })
        SigV4Auth(self.credentials, "s3", self.region).add_auth(request)
        response = self.session.request(method, url, data=data, headers=dict(request.headers), timeout=30)
        code = "UnknownError"
        if not response.ok:
            try:
                code = ET.fromstring(response.content).findtext("Code", code)
            except ET.ParseError:
                try:
                    code = response.json().get("Code", code)
                except ValueError:
                    pass
            if not re.fullmatch(r"[A-Za-z0-9]+", str(code)):
                code = "UnknownError"
        if missing_ok and (response.status_code == 404 or code in {"NoSuchUser", "XMinioAdminNoSuchUser"}):
            return False
        if not response.ok:
            # Do not emit response bodies, signed headers, URLs containing keys, or request payloads.
            raise ProvisionError(f"RustFS admin {operation} failed (HTTP {response.status_code}, {code})")
        return True


def reconcile(config, credentials, state_directory):
    access = credential(credentials, "root-access")
    secret = credential(credentials, "root-secret")
    endpoint, region = config["endpoint"], config["region"]
    admin = Admin(endpoint, region, access, secret)
    deadline = time.monotonic() + 120
    while True:
        try:
            if admin.session.get(endpoint + "/health/ready", timeout=5).status_code == 200:
                break
        except requests.RequestException:
            pass
        if time.monotonic() >= deadline:
            raise ProvisionError("RustFS did not become ready within 120 seconds")
        time.sleep(2)

    client = boto3.client("s3", endpoint_url=endpoint, region_name=region,
                          aws_access_key_id=access, aws_secret_access_key=secret,
                          config=Config(s3={"addressing_style": "path"},
                                        retries={"max_attempts": 3, "mode": "standard"},
                                        connect_timeout=5, read_timeout=30,
                                        request_checksum_calculation="when_required"))
    # Validate every credential before changing policies or users.
    desired = {}
    seen = {access}
    for name, spec in config["writers"].items():
        key = credential(credentials, f"{name}-access")
        value = credential(credentials, f"{name}-secret")
        if not re.fullmatch(r"[A-Za-z0-9]{3,64}", key) or len(value) < 8 or key in seen:
            raise ProvisionError(f"Invalid or duplicate writer credential: {name}")
        seen.add(key)
        desired[name] = {"key": key, "secret": value, "spec": spec}

    state_directory.mkdir(mode=0o700, parents=True, exist_ok=True)
    state_file = state_directory / "writers.json"
    previous = json.loads(state_file.read_text()) if state_file.exists() else {}
    # Revocation is scoped to identities previously managed by this module.
    for name, old in previous.items():
        if name not in desired or desired[name]["key"] != old["key"]:
            if admin.call("GET", "user-info", {"accessKey": old["key"]}, missing_ok=True):
                admin.call("PUT", "set-user-status", {"accessKey": old["key"], "status": "disabled"})

    for name, spec in config["buckets"].items():
        try:
            client.head_bucket(Bucket=name)
        except ClientError as error:
            if error.response["ResponseMetadata"]["HTTPStatusCode"] != 404:
                raise
            args = {"Bucket": name}
            if region != "us-east-1":
                args["CreateBucketConfiguration"] = {"LocationConstraint": region}
            client.create_bucket(**args)
        if spec["publicRead"]:
            client.put_bucket_policy(Bucket=name, Policy=json.dumps(policy([
                {"Effect": "Allow", "Principal": "*", "Action": ["s3:GetObject"],
                 "Resource": [f"arn:aws:s3:::{name}/*"]}
            ])))
        else:
            # IAM still grants access to scoped writers; no anonymous policy remains.
            client.delete_bucket_policy(Bucket=name)
        lifecycle = {
            "ID": "nixos-cache-retention", "Status": "Enabled", "Filter": {"Prefix": ""},
            "AbortIncompleteMultipartUpload": {"DaysAfterInitiation": spec["abortMultipartDays"]},
        }
        if spec["retentionDays"] is not None:
            lifecycle["Expiration"] = {"Days": spec["retentionDays"]}
            lifecycle["NoncurrentVersionExpiration"] = {"NoncurrentDays": spec["retentionDays"]}
        client.put_bucket_lifecycle_configuration(Bucket=name, LifecycleConfiguration={"Rules": [lifecycle]})
        print(f"Reconciled bucket: {name}", flush=True)

    updated = {}
    for name, entry in desired.items():
        key, value = entry["key"], entry["secret"]
        digest = hashlib.sha256(value.encode()).hexdigest()
        exists = admin.call("GET", "user-info", {"accessKey": key}, missing_ok=True)
        if not exists:
            admin.call("PUT", "add-user", {"accessKey": key}, {"secretKey": value, "status": "enabled"})
        elif previous.get(name) != {"key": key, "digest": digest}:
            admin.call("PUT", "set-user-secret-key", {"accessKey": key}, {"secret_key": value})
        policy_name = "nixos-" + name
        admin.call("PUT", "add-canned-policy", {"name": policy_name}, writer_policy(entry["spec"]["buckets"]))
        # Replace the user's policy mapping, rather than accumulating old grants.
        admin.call("PUT", "set-user-or-group-policy",
                   {"policyName": policy_name, "userOrGroup": key, "isGroup": "false"})
        admin.call("PUT", "set-user-status", {"accessKey": key, "status": "enabled"})
        updated[name] = {"key": key, "digest": digest}
        print(f"Reconciled writer: {name}", flush=True)
    temporary = state_directory / "writers.json.new"
    temporary.write_text(json.dumps(updated))
    temporary.chmod(0o600)
    temporary.replace(state_file)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("config", type=Path)
    parser.add_argument("--state-directory", type=Path, default=Path("/var/lib/rustfs-provision"))
    args = parser.parse_args()
    os.umask(0o077)
    try:
        reconcile(json.loads(args.config.read_text()), Path(os.environ["CREDENTIALS_DIRECTORY"]), args.state_directory)
    except ClientError as error:
        print(f"S3 provisioning failed: {error.operation_name} ({error.response['Error']['Code']})", file=sys.stderr)
        return 1
    except Exception as error:
        # SDK exceptions can contain signed request details. Only deliberate messages are safe.
        message = str(error) if isinstance(error, ProvisionError) else type(error).__name__
        print(f"RustFS provisioning failed: {message}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
