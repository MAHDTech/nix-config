"""Live integration test: run with the module's Python environment and a RustFS binary.

Usage: python3 tests/test_rustfs_integration.py /path/to/rustfs
Optional arguments: generated-nginx.conf nginx-binary openssl-binary.
Uses only disposable local storage and generated test credentials.
"""
import importlib.util
import json
import os
import re
from pathlib import Path
import secrets
import socket
import subprocess
import sys
import tempfile
import time

import boto3
from botocore.config import Config
from botocore.exceptions import ClientError
import requests

MODULE = Path(__file__).resolve().parents[1] / "nixos/system/config/services/rustfs/reconcile.py"
spec = importlib.util.spec_from_file_location("reconciler", MODULE)
reconciler = importlib.util.module_from_spec(spec)
spec.loader.exec_module(reconciler)


def port():
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        return sock.getsockname()[1]


def assert_denied(call):
    try:
        call()
    except ClientError as error:
        assert error.response["ResponseMetadata"]["HTTPStatusCode"] == 403, error
    else:
        raise AssertionError("Operation unexpectedly permitted")


def main():
    with tempfile.TemporaryDirectory(prefix="rustfs-test-") as directory:
        root = Path(directory)
        creds = root / "credentials"
        creds.mkdir(mode=0o700)
        values = {}
        for name in ["root", "actions", "packages"]:
            for field in ["access", "secret"]:
                value = secrets.token_hex(16 if field == "access" else 32)
                values[f"{name}-{field}"] = value
                path = creds / f"{name}-{field}"
                path.write_text(value)
                path.chmod(0o600)
        api, console = port(), port()
        endpoint = f"http://127.0.0.1:{api}"
        data = root / "data"
        data.mkdir()
        env = {**os.environ, "RUSTFS_ADDRESS": f"127.0.0.1:{api}",
               "RUSTFS_CONSOLE_ADDRESS": f"127.0.0.1:{console}", "RUSTFS_CONSOLE_ENABLE": "true",
               "RUSTFS_ACCESS_KEY_FILE": str(creds / "root-access"),
               "RUSTFS_SECRET_KEY_FILE": str(creds / "root-secret"),
               "RUSTFS_OBS_LOG_DIRECTORY": str(root / "logs")}
        log = (root / "server.log").open("w")
        process = subprocess.Popen([sys.argv[1], str(data)], env=env, stdout=log, stderr=log, cwd=root)

        proxy = None
        verify = True
        console_url = f"http://127.0.0.1:{console}/rustfs/console/"
        if len(sys.argv) > 2:
            tls_port, http_port = port(), port()
            certificates = root / "certificates"
            certificates.mkdir()
            cert = certificates / "fullchain.pem"
            subprocess.run([sys.argv[4], "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-days", "1",
                            "-subj", "/CN=localhost", "-addext", "subjectAltName=DNS:localhost,IP:127.0.0.1",
                            "-keyout", str(certificates / "key.pem"), "-out", str(cert)],
                           check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            (certificates / "chain.pem").write_bytes(cert.read_bytes())
            text = Path(sys.argv[2]).read_text()
            text = text.replace("/var/lib/acme/s3.slopageddon.app", str(certificates))
            text = text.replace("/var/lib/acme/s3-console.slopageddon.app", str(certificates))
            text = text.replace("s3-console.slopageddon.app", "127.0.0.1").replace("s3.slopageddon.app", "localhost")
            text = text.replace(":443", f":{tls_port}")
            text = text.replace("listen 0.0.0.0:80;", f"listen 127.0.0.1:{http_port};")
            text = text.replace(f"listen 0.0.0.0:{tls_port}", f"listen 127.0.0.1:{tls_port}")
            text = re.sub(r"listen \[::0\]:[^;]+;", "", text)
            text = text.replace("127.0.0.1:9000", f"127.0.0.1:{api}").replace("127.0.0.1:9001", f"127.0.0.1:{console}")
            text = text.replace("/run/nginx/nginx.pid", str(root / "nginx.pid"))
            temp_paths = " ".join(f"{name}_temp_path {root}/{name};"
                                  for name in ["client_body", "proxy", "fastcgi", "uwsgi", "scgi"])
            text = text.replace("http {", f"http {{ access_log off; {temp_paths}", 1)
            conf = root / "nginx.conf"
            conf.write_text(text)
            (root / "logs").mkdir(exist_ok=True)
            subprocess.run([sys.argv[3], "-e", "stderr", "-t", "-p", str(root), "-c", str(conf)], check=True)
            proxy = subprocess.Popen([sys.argv[3], "-e", "stderr", "-p", str(root), "-c", str(conf)], stdout=log, stderr=log)
            time.sleep(0.3)
            assert proxy.poll() is None
            endpoint = f"https://localhost:{tls_port}"
            console_url = f"https://127.0.0.1:{tls_port}/rustfs/console/"
            verify = str(cert)

        def client(name):
            return boto3.client("s3", endpoint_url=endpoint, region_name="us-east-1", verify=verify,
                                aws_access_key_id=(creds / f"{name}-access").read_text(),
                                aws_secret_access_key=(creds / f"{name}-secret").read_text(),
                                config=Config(s3={"addressing_style": "path"}, retries={"max_attempts": 0},
                                              request_checksum_calculation="when_required"))

        config = {"endpoint": f"http://127.0.0.1:{api}", "region": "us-east-1", "buckets": {
            name: {"publicRead": name != "private-test", "retentionDays": 30, "abortMultipartDays": 1}
            for name in ["github-actions", "github-packages", "private-test"]}, "writers": {
            "actions": {"buckets": ["github-actions", "private-test"]},
            "packages": {"buckets": ["github-packages"]}}}
        try:
            reconciler.reconcile(config, creds, root / "state")
            reconciler.reconcile(config, creds, root / "state")
            print("PASS: readiness, credential files, bucket creation, repeat reconciliation")
            admin, actions, packages = client("root"), client("actions"), client("packages")
            for bucket, writer in [("github-actions", actions), ("github-packages", packages), ("private-test", actions)]:
                writer.put_object(Bucket=bucket, Key="hello.txt", Body=b"cache fixture")
                assert writer.get_object(Bucket=bucket, Key="hello.txt")["Body"].read() == b"cache fixture"
                lifecycle = admin.get_bucket_lifecycle_configuration(Bucket=bucket)["Rules"][0]
                assert lifecycle["Expiration"]["Days"] == 30
                assert lifecycle["AbortIncompleteMultipartUpload"]["DaysAfterInitiation"] == 1
            http = requests.Session()
            http.trust_env = False
            http.verify = verify
            assert http.get(endpoint + "/github-actions/hello.txt").status_code == 200
            assert http.get(endpoint + "/github-actions?list-type=2").status_code == 403
            assert http.get(endpoint + "/private-test/hello.txt").status_code == 403
            assert http.put(endpoint + "/github-actions/anonymous", data=b"denied").status_code == 403
            assert_denied(lambda: actions.put_object(Bucket="github-packages", Key="denied", Body=b"denied"))
            assert_denied(lambda: packages.get_object(Bucket="private-test", Key="hello.txt"))
            assert_denied(lambda: actions.create_bucket(Bucket="not-authorized"))
            print("PASS: public reads, private bucket, no anonymous listing/writes, writer isolation")
            # Multipart uploads are used by Actions archives and S3 clients.
            upload = actions.create_multipart_upload(Bucket="github-actions", Key="multipart")
            part = actions.upload_part(Bucket="github-actions", Key="multipart", UploadId=upload["UploadId"],
                                       PartNumber=1, Body=b"multipart fixture")
            actions.complete_multipart_upload(Bucket="github-actions", Key="multipart", UploadId=upload["UploadId"],
                                              MultipartUpload={"Parts": [{"PartNumber": 1, "ETag": part["ETag"]}]})
            assert actions.get_object(Bucket="github-actions", Key="multipart")["Body"].read() == b"multipart fixture"
            print("PASS: multipart upload")
            config["buckets"]["github-actions"]["publicRead"] = False
            config["buckets"]["github-actions"]["retentionDays"] = 7
            config["writers"]["actions"]["buckets"] = ["github-actions"]
            (creds / "actions-secret").write_text(secrets.token_hex(32))
            reconciler.reconcile(config, creds, root / "state")
            assert http.get(endpoint + "/github-actions/hello.txt").status_code == 403
            assert_denied(lambda: actions.put_object(Bucket="github-actions", Key="old-secret", Body=b"denied"))
            actions = client("actions")
            assert actions.get_object(Bucket="github-actions", Key="hello.txt")["Body"].read() == b"cache fixture"
            assert_denied(lambda: actions.get_object(Bucket="private-test", Key="hello.txt"))
            assert admin.get_bucket_lifecycle_configuration(Bucket="github-actions")["Rules"][0]["Expiration"]["Days"] == 7
            print("PASS: secret rotation, reduced grants, public-to-private, retention changes")
            (creds / "actions-access").write_text(secrets.token_hex(16))
            reconciler.reconcile(config, creds, root / "state")
            assert_denied(lambda: actions.get_object(Bucket="github-actions", Key="hello.txt"))
            actions = client("actions")
            actions.put_object(Bucket="github-actions", Key="new-key", Body=b"ok")
            del config["writers"]["actions"]
            del config["buckets"]["github-actions"]
            reconciler.reconcile(config, creds, root / "state")
            assert_denied(lambda: actions.get_object(Bucket="github-actions", Key="hello.txt"))
            assert admin.get_object(Bucket="github-actions", Key="hello.txt")["Body"].read() == b"cache fixture"
            print("PASS: access-key rotation, removed writer disabled, removed bucket retained")
            response = http.get(console_url)
            assert response.status_code == 200 and "text/html" in response.headers.get("Content-Type", "")
            print("PASS: bundled console serves HTML")
        except Exception:
            # Fixture credentials are disposable, but don't print the server's request log.
            print("FAIL: RustFS integration check", file=sys.stderr)
            raise
        finally:
            if proxy is not None:
                proxy.terminate()
                proxy.wait(timeout=15)
            process.terminate()
            try:
                process.wait(timeout=15)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
            log.close()


if __name__ == "__main__":
    main()
