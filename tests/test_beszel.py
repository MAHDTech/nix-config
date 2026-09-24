"""Run with BESZEL_BIN pointing at a directory containing Beszel's two binaries."""

import importlib.util
import json
import os
from pathlib import Path
import secrets
import shutil
import socket
import subprocess
import tempfile
import time
import unittest
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen


PREPARE = Path(__file__).resolve().parents[1] / "nixos/system/config/services/beszel/hub/prepare.py"
spec = importlib.util.spec_from_file_location("beszel_prepare", PREPARE)
prepare = importlib.util.module_from_spec(spec)
spec.loader.exec_module(prepare)


def unused_port():
    with socket.socket() as listener:
        listener.bind(("127.0.0.1", 0))
        return listener.getsockname()[1]


class BeszelIntegration(unittest.TestCase):
    def test_inventory_credentials_and_live_agent(self):
        binary = Path(os.environ["BESZEL_BIN"])
        with tempfile.TemporaryDirectory(prefix="beszel-test-", dir=os.environ.get("TMPDIR")) as temp:
            root = Path(temp)
            credentials = root / "credentials"
            credentials.mkdir(mode=0o700)
            key = credentials / "hub-private-key"
            keygen = shutil.which("ssh-keygen")
            subprocess.run([keygen, "-q", "-t", "ed25519", "-N", "", "-f", str(key)], check=True)
            token = secrets.token_urlsafe(32)
            (credentials / "token-fixture").write_text(token)
            email = "fixture@example.test"
            password = secrets.token_urlsafe(32)
            env = {**os.environ, "USER_EMAIL": email, "USER_PASSWORD": password}
            manifest = {"privateKey": True, "managed": True, "systems": {"fixture": {
                "host": "fixture", "port": 45876, "users": [email],
                "tokenCredential": "token-fixture"}}}
            data = root / "beszel_data"
            prepare.prepare(manifest, data, credentials, keygen)
            self.assertEqual((data / "config.yml").stat().st_mode & 0o777, 0o600)
            self.assertEqual((data / "id_ed25519").stat().st_mode & 0o777, 0o600)
            previous = (data / "config.yml").read_bytes()
            (credentials / "token-fixture").write_text("\n")
            with self.assertRaises(ValueError):
                prepare.prepare(manifest, data, credentials, keygen)
            self.assertEqual((data / "config.yml").read_bytes(), previous)
            (credentials / "token-fixture").write_text(token)
            endpoint = f"http://127.0.0.1:{unused_port()}"
            processes = []

            def launch(command, process_env):
                process = subprocess.Popen(command, cwd=root, env=process_env,
                                           stdout=log, stderr=log)
                processes.append(process)
                return process

            def request(path, payload=None, auth=None, method=None):
                headers = {"Content-Type": "application/json"}
                if auth:
                    headers["Authorization"] = auth
                req = Request(endpoint + path, data=None if payload is None else json.dumps(payload).encode(),
                              headers=headers, method=method)
                with urlopen(req, timeout=3) as response:
                    body = response.read()
                    return json.loads(body) if body else None

            def eventually(function, seconds=45):
                until = time.monotonic() + seconds
                while time.monotonic() < until:
                    try:
                        if result := function():
                            return result
                    except (URLError, TimeoutError):
                        pass
                    time.sleep(0.25)
                self.fail("Timed out waiting for Beszel integration fixture")

            with (root / "process.log").open("w+") as log:
                try:
                    subprocess.run([str(binary / "beszel-hub"), "migrate", "up"],
                                   cwd=root, env=env, stdout=log, stderr=log, check=True)
                    hub_command = [str(binary / "beszel-hub"), "serve", "--http=" + endpoint.removeprefix("http://")]
                    hub = launch(hub_command, env)
                    eventually(lambda: request("/api/health"))
                    login = {"identity": email, "password": password}
                    bootstrap = request("/api/collections/users/auth-with-password", login)
                    self.assertNotEqual(bootstrap["record"]["role"], "admin")
                    auth = bootstrap["token"]
                    admin = request("/api/collections/_superusers/auth-with-password", login)["token"]
                    records_path = "/api/collections/systems/records"
                    systems = request(records_path, auth=auth)["items"]
                    self.assertEqual([item["name"] for item in systems], ["fixture"])
                    system_id = systems[0]["id"]
                    public_key = request("/api/beszel/getkey", auth=auth)["key"]
                    self.assertEqual(public_key.strip(), Path(str(key) + ".pub").read_text().strip().rsplit(" ", 1)[0])

                    agent_env = {**os.environ, "HUB_URL": endpoint, "KEY_FILE": str(key) + ".pub",
                                 "TOKEN_FILE": str(credentials / "token-fixture"), "DISABLE_SSH": "true",
                                 "DATA_DIR": str(root / "agent"), "SKIP_SYSTEMD": "true"}
                    agent = launch([str(binary / "beszel-agent")], agent_env)
                    eventually(lambda: request(records_path + "/" + system_id, auth=auth)["status"] == "up")

                    viewer_password = secrets.token_urlsafe(32)
                    viewer = request("/api/collections/users/records", {
                        "email": "viewer@example.test", "password": viewer_password,
                        "passwordConfirm": viewer_password, "role": "readonly", "verified": True}, auth=admin)
                    request(records_path + "/" + system_id, {"users": [viewer["id"], systems[0]["users"][0]]},
                            auth=admin, method="PATCH")
                    viewer_auth = request("/api/collections/users/auth-with-password", {
                        "identity": "viewer@example.test", "password": viewer_password})["token"]
                    self.assertEqual(request(records_path, auth=viewer_auth)["totalItems"], 1)
                    with self.assertRaises(HTTPError) as denied:
                        request(records_path + "/" + system_id, auth=viewer_auth, method="DELETE")
                    self.assertIn(denied.exception.code, (403, 404))
                    denied.exception.close()

                    hub.terminate()
                    hub.wait(timeout=10)
                    manifest["systems"]["fixture"]["users"].append("viewer@example.test")
                    prepare.prepare(manifest, data, credentials, keygen)
                    hub = launch(hub_command, env)
                    eventually(lambda: request("/api/health"))
                    eventually(lambda: request(records_path + "/" + system_id, auth=auth)["status"] == "up", seconds=90)
                    self.assertEqual(request(records_path, auth=auth)["totalItems"], 1)
                    self.assertEqual(request(records_path, auth=viewer_auth)["totalItems"], 1)
                    self.assertIsNone(agent.poll())
                    prepare.prepare({"privateKey": False, "managed": False, "systems": {}}, data, credentials, keygen)
                    self.assertFalse((data / "config.yml").exists())
                    (data / "config.yml").write_text("manually owned inventory")
                    prepare.prepare({"privateKey": False, "managed": False, "systems": {}}, data, credentials, keygen)
                    self.assertEqual((data / "config.yml").read_text(), "manually owned inventory")
                except Exception:
                    # Logs contain only generated fixture credentials, never production inputs.
                    log.flush()
                    log.seek(0)
                    print(log.read())
                    raise
                finally:
                    for process in reversed(processes):
                        if process.poll() is None:
                            process.terminate()
                            process.wait(timeout=10)


if __name__ == "__main__":
    unittest.main()
