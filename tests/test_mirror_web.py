# cspell:ignore cafile
"""Exercise the generated mirror Caddyfile with disposable HTTPS content.

Set CADDY_CONFIG to the generated Caddyfile and CADDY_BIN to the Caddy binary.
"""

import json
import os
from pathlib import Path
import re
import socket
import ssl
import subprocess
import tempfile
import time
import urllib.error
import urllib.request


def main():
    source = Path(os.environ["CADDY_CONFIG"]).read_text()
    caddy = os.environ.get("CADDY_BIN", "caddy")
    with tempfile.TemporaryDirectory(prefix="mirror-check-") as temporary:
        root = Path(temporary)
        site = root / "site"
        release = site / "nutanix/lcm/release"
        release.mkdir(parents=True)
        payload = bytes(range(256)) * 4096
        (release / "master_manifest.tgz").write_bytes(payload)
        (release / "index.html").write_text("Vendor index must not replace listing")
        (release / '<unsafe&name>.txt').write_text("fixture")
        (site / "ubuntu").mkdir()
        (root / "summary.json").write_text(json.dumps({"storage": {"available_bytes": 123}}))
        cert = root / "cert.pem"
        key = root / "key.pem"
        subprocess.run([
            "openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-days", "1",
            "-subj", "/CN=localhost", "-addext", "subjectAltName=IP:127.0.0.1",
            "-keyout", str(key), "-out", str(cert),
        ], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        with socket.socket() as sock:
            sock.bind(("127.0.0.1", 0))
            port = sock.getsockname()[1]
        config = source.replace("auto_https disable_redirects", "auto_https disable_redirects\nadmin off")
        config = config.replace("https://mirror.slopageddon.app", f"https://127.0.0.1:{port}")
        config = re.sub(r"tls /var/lib/acme/[^\n]+", f"tls {cert} {key}", config)
        config = config.replace("/srv/mirror", str(site))
        config = config.replace("/var/lib/mirror-summary", str(root))
        path = root / "Caddyfile"
        path.write_text(config)
        proc = subprocess.Popen([caddy, "run", "--config", str(path), "--adapter", "caddyfile"], stderr=subprocess.PIPE)
        context = ssl.create_default_context(cafile=str(cert))

        def get(path, method="GET", headers=None):
            request = urllib.request.Request(f"https://127.0.0.1:{port}" + path, method=method, headers=headers or {})
            try:
                response = urllib.request.urlopen(request, context=context, timeout=5)
            except urllib.error.HTTPError as error:
                response = error
            with response:
                return response.status, response.headers, response.read()

        try:
            for _ in range(100):
                try:
                    status, headers, body = get("/")
                    break
                except urllib.error.URLError:
                    if proc.poll() is not None:
                        raise RuntimeError(proc.stderr.read().decode())
                    time.sleep(0.1)
            assert status == 200 and b"One mirror." in body and b'href="/browse/"' in body
            assert b"@hostname@" not in body and b"MIRROR STATISTICS" in body
            assert get("/", "HEAD")[0] == 200
            assert get("/", "POST")[0] == 405
            for asset in ["/_landing.css", "/_browse.css", "/_landing.js"]:
                assert get(asset)[0] == 200, asset
            assert get("/_dashboard/summary.json")[0] == 200
            assert get("/_dashboard/stats-state.json")[0] == 404
            status, _, body = get("/browse/")
            assert status == 200 and b'href="/nutanix/"' in body, (status, body)
            assert b'href="/browse/nutanix/"' not in body
            assert get("/browse/nutanix/")[0] == 404
            assert get("/nutanix")[0] == 200
            for directory in ["/nutanix/", "/nutanix/lcm/release/", "/ubuntu/"]:
                status, _, body = get(directory)
                assert status == 200 and b"FILE BROWSER" in body, (directory, body)
            assert b"This directory is empty." in body
            status, _, body = get("/nutanix/lcm/release/?sort=size&order=desc")
            assert status == 200 and b"master_manifest.tgz" in body
            assert b"&lt;unsafe&amp;name&gt;.txt" in body and b"<unsafe&name>" not in body
            url = "/nutanix/lcm/release/master_manifest.tgz"
            assert get(url)[2] == payload
            status, headers, body = get(url, headers={"Range": "bytes=100-199"})
            assert status == 206 and body == payload[100:200]
            assert headers["Content-Range"] == f"bytes 100-199/{len(payload)}"
            assert get(url, "HEAD")[1]["Content-Length"] == str(len(payload))
            assert get("/release/master_manifest.tgz")[0] == 404
            assert get("/nutanix/lcm/release/missing")[0] == 404
            assert get("/nutanix/lcm/release/", "PUT")[0] == 405
        except Exception:
            proc.terminate()
            _, errors = proc.communicate(timeout=10)
            print(errors.decode()[-5000:])
            raise
        finally:
            proc.terminate()
            _, errors = proc.communicate(timeout=10)
            if proc.returncode != 0:
                raise RuntimeError(errors.decode())
        config = re.sub(r"@outside not remote_ip [^\n]+", "@outside not remote_ip 192.0.2.0/24", config)
        path.write_text(config)
        proc = subprocess.Popen([caddy, "run", "--config", str(path), "--adapter", "caddyfile"], stderr=subprocess.PIPE)
        try:
            for _ in range(100):
                try:
                    assert get("/")[0] == 403
                    break
                except urllib.error.URLError:
                    time.sleep(0.1)
            else:
                raise AssertionError("Restricted server did not start")
            assert get("/browse/")[0] == 403
            assert get("/nutanix/lcm/release/master_manifest.tgz")[0] == 403
        finally:
            proc.terminate()
            _, errors = proc.communicate(timeout=10)
            if proc.returncode != 0:
                raise RuntimeError(errors.decode())
        print("PASS: HTTPS landing, assets, custom listings, canonical links, escaping, downloads, ranges, HEAD, methods, LAN restrictions and no legacy URL")


if __name__ == "__main__":
    main()
