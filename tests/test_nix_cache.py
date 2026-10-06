"""Exercise a built cache nginx config with local upstreams and temporary state.

Set NGINX_CONFIG to the generated nix-cache nginx.conf and NGINX_BIN to nginx.
Only listeners, TLS and runtime paths are substituted; cache routes stay intact.
"""

import datetime
import http.server
import importlib.util
import json
import os
import pathlib
import re
import socket
import subprocess
import tempfile
import threading
import time
import urllib.error
import urllib.request

source = pathlib.Path(os.environ['NGINX_CONFIG']).read_text()
nginx = os.environ.get('NGINX_BIN', 'nginx')
class Upstream(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        body = (self.headers['Host'] + self.path).encode()
        self.send_response(404 if 'missing' in self.path else 200)
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)
    def log_message(self, *args):
        pass

upstream = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Upstream)
threading.Thread(target=upstream.serve_forever, daemon=True).start()
with tempfile.TemporaryDirectory(prefix='cache-check-') as tmp:
    root = pathlib.Path(tmp)
    root.chmod(0o755)
    (root / 'logs').mkdir()
    with socket.socket() as sock:
        sock.bind(('127.0.0.1', 0))
        port = sock.getsockname()[1]
    config = re.sub(r'    server \{\n        listen 0.0.0.0:80;.*?\n    \}\n', '', source, flags=re.S)
    config = re.sub(r'        listen .*?443 ssl;', f'        listen 127.0.0.1:{port};', config, count=1)
    config = re.sub(r'        listen \[::0\]:443 ssl;\n', '', config)
    config = re.sub(r'^        (ssl_certificate|ssl_certificate_key|ssl_trusted_certificate) .*?;\n', '', config, flags=re.M)
    config = config.replace('/run/nginx/nginx.pid', str(root / 'nginx.pid'))
    config = config.replace('/var/cache/nginx/nixpkgs', str(root / 'cache'))
    config = config.replace('min_free=100g', 'min_free=0').replace('keys_zone=nixpkgs:128m', 'keys_zone=nixpkgs:1m')
    config = config.replace('/var/log/nginx/nix-cache-access.log', str(root / 'access.log'))
    snapshot = b'{"checked_at":"2026-09-25T00:00:00+00:00","endpoints":[]}'
    (root / 'summary.json').write_bytes(snapshot)
    config = config.replace('/var/lib/nix-cache-summary/summary.json', str(root / 'summary.json'))
    (root / 'catalog.json').write_text('{"entries":[],"truncated":false}')
    config = config.replace('/var/lib/nix-cache-catalog/catalog.json', str(root / 'catalog.json'))
    config = config.replace('https://$nix_cache_upstream', f'http://127.0.0.1:{upstream.server_port}')
    (root / 'nginx.conf').write_text(config)
    proc = subprocess.Popen([nginx, '-p', tmp, '-c', str(root / 'nginx.conf')], stderr=subprocess.PIPE)
    def get(path, method='GET'):
        try:
            response = urllib.request.urlopen(urllib.request.Request(f'http://127.0.0.1:{port}' + path, method=method), timeout=3)
        except urllib.error.HTTPError as error:
            response = error
        with response:
            return response.status, response.headers, response.read()
    try:
        for _ in range(50):
            try:
                status, headers, body = get('/')
                break
            except urllib.error.URLError:
                time.sleep(.1)
        assert status == 200 and b'https://hub.slopageddon.app' in body
        assert headers['Content-Type'] == 'text/html'
        assert b'@hostname@' not in body
        assert b'Endpoint links open' not in body
        assert b'href="/devenv/nix-cache-info"' not in body
        assert b'data-endpoint="devenv"' in body
        assert b'CACHE STATISTICS' in body
        assert b'id="disk-free"' in body
        assert b'id="cache-hit-rate"' in body
        assert b'href="/browse/"' in body
        assert get('/', 'HEAD')[0] == 200
        assert get('/', 'POST')[0] == 403
        status, headers, body = get('/_landing.css')
        assert status == 200 and headers['Content-Type'] == 'text/css'
        status, headers, body = get('/_landing.js')
        assert status == 200 and headers['Content-Type'] == 'application/javascript'
        status, headers, body = get('/_dashboard/summary.json')
        assert status == 200 and body == snapshot
        assert headers['Content-Type'] == 'application/json'
        assert headers['Cache-Control'] == 'no-store'
        assert get('/_dashboard/summary.json', 'POST')[0] == 403
        status, headers, body = get('/browse/')
        assert status == 200 and b'CACHED DOWNLOADS' in body, (status, body)
        assert get('/browse/', 'HEAD')[0] == 200
        assert get('/browse/', 'POST')[0] == 403
        assert get('/_catalog.js')[0] == 200
        assert get('/_browse.css')[0] == 200
        assert get('/_dashboard/catalog.json')[0] == 200
        assert get('/_dashboard/catalog.json', 'POST')[0] == 403
        assert get('/unknown')[0] == 404
        assert get('/_dashboard/stats-state.json')[0] == 404
        upstreams = {
            '': 'cache.nixos.org',
            '/bingamon-lab': 'bingamon-lab.cachix.org',
            '/bingamon-lab-tf-modules': 'bingamon-lab-tf-modules.cachix.org',
            '/devenv': 'devenv.cachix.org',
            '/tars-cloud': 'tars-cloud.cachix.org',
            '/mahdtech': 'mahdtech.cachix.org',
            '/salt-labs': 'salt-labs.cachix.org',
            '/herdr': 'herdr.cachix.org',
            '/cosmic': 'cosmic.cachix.org',
        }
        for prefix, host in upstreams.items():
            for suffix in ['/nix-cache-info', '/' + 'a' * 32 + '.narinfo', '/nar/fixture.nar.xz']:
                path = prefix + suffix
                first = get(path)
                second = get(path)
                assert first[0] == second[0] == 200, path
                assert first[1]['X-Cache-Status'] == 'MISS', (path, first)
                assert second[1]['X-Cache-Status'] == 'HIT', (path, second)
                assert first[2] == second[2] == (host + suffix).encode()
                assert get(path, 'HEAD')[0] == 200
            for _ in range(2):
                missing = get(prefix + '/nar/missing')
                assert missing[0] == 404 and missing[1]['X-Cache-Status'] == 'MISS'
        get('/nix-cache-info?private=not-for-log')
        spec = importlib.util.spec_from_file_location('catalog', pathlib.Path(__file__).resolve().parents[1] / 'nixos/hosts/nix-cache/collect-catalog.py')
        catalog = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(catalog)
        catalog_sources = json.loads((pathlib.Path(__file__).resolve().parents[1] / 'nixos/system/config/services/nix-cache/upstreams.json').read_text())
        entries = catalog.collect_catalog(root / 'cache', catalog_sources)['entries']
        urls = {entry['url'] for entry in entries}
        for prefix in upstreams:
            assert prefix + '/nar/fixture.nar.xz' in urls, (prefix, entries)
            assert prefix + '/' + 'a' * 32 + '.narinfo' in urls, (prefix, entries)
        assert all('missing' not in url and 'private' not in url for url in urls)
    finally:
        proc.terminate()
        _, errors = proc.communicate(timeout=10)
        if proc.returncode != 0:
            raise RuntimeError(errors.decode())
        upstream.shutdown()
    logs = [json.loads(line) for line in (root / 'access.log').read_text().splitlines()]
    assert logs and all('private' not in entry['uri'] for entry in logs)
    assert all(entry['uri'] not in ['/', '/_landing.css', '/_landing.js', '/_dashboard/summary.json', '/browse/', '/_catalog.js', '/_browse.css', '/_dashboard/catalog.json'] for entry in logs)
    for entry in logs:
        datetime.datetime.fromisoformat(entry['time'])
    print(f'PASS: landing, catalog, CSS, methods, all {len(upstreams) * 3} cache routes MISS/HIT/HEAD, uncached 404s, real cache catalog, timestamped JSON logs')
