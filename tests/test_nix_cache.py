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
        if self.headers['Host'] == 'tarballs.nixos.org' and self.path.startswith('/sha256/') and 'missing' not in self.path:
            self.send_response(301)
            self.send_header('Location', '/sha512/' + 'f' * 128)
            self.send_header('Content-Length', '0')
            self.end_headers()
            return
        body = (self.headers['Host'] + self.path).encode()
        self.send_response(404 if 'missing' in self.path else 200)
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)
    def log_message(self, *args):
        pass

class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, new_url):
        return None

no_redirect_opener = urllib.request.build_opener(NoRedirect)

upstream = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Upstream)
threading.Thread(target=upstream.serve_forever, daemon=True).start()
with tempfile.TemporaryDirectory(prefix='cache-check-') as tmp:
    root = pathlib.Path(tmp)
    root.chmod(0o755)
    (root / 'logs').mkdir()
    with socket.socket() as sock:
        sock.bind(('127.0.0.1', 0))
        port = sock.getsockname()[1]
    assert ':80' not in source, 'onlySSL must not open port 80'
    assert 'ssl_reject_handshake on;' in source, 'default catch-all must reject unknown SNI'
    assert 'gzip on;' in source, 'recommendedGzipSettings must enable gzip'
    config = re.sub(
        r'    server \{\n(?:(?!    server \{).)*?server_name _;(?:(?!    server \{).)*?\n    \}\n',
        '',
        source,
        flags=re.S,
    )
    config = re.sub(r'        listen .*?443 ssl;', f'        listen 127.0.0.1:{port};', config, count=1)
    config = re.sub(r'        listen \[::0\]:443 ssl;\n', '', config)
    config = re.sub(r'^        (ssl_certificate|ssl_certificate_key|ssl_trusted_certificate) .*?;\n', '', config, flags=re.M)
    config = config.replace('/run/nginx/nginx.pid', str(root / 'nginx.pid'))
    config = config.replace('/var/cache/nginx/nixpkgs', str(root / 'cache'))
    config = config.replace('min_free=100g', 'min_free=0').replace('keys_zone=nixpkgs:128m', 'keys_zone=nixpkgs:1m')
    config = config.replace('/var/log/nginx/nix-cache-access.log', str(root / 'access.log'))
    config = config.replace('/var/log/nginx/access.log', str(root / 'global-access.log'))
    config = config.replace('/var/log/nginx/error.log', str(root / 'error.log'))
    temp_paths = ' '.join(
        f'{name}_temp_path {root / name};'
        for name in ['client_body', 'proxy', 'fastcgi', 'uwsgi', 'scgi']
    )
    config = config.replace('http {', f'http {{\n    access_log off;\n    {temp_paths}', 1)
    snapshot = b'{"checked_at":"2026-09-25T00:00:00+00:00","endpoints":[]}'
    (root / 'summary.json').write_bytes(snapshot)
    config = config.replace('/var/lib/nix-cache-summary/summary.json', str(root / 'summary.json'))
    (root / 'catalog.json').write_text('{"entries":[],"truncated":false}')
    config = config.replace('/var/lib/nix-cache-catalog/catalog.json', str(root / 'catalog.json'))
    config = config.replace('https://$nix_cache_upstream', f'http://127.0.0.1:{upstream.server_port}')
    (root / 'nginx.conf').write_text(config)
    proc = subprocess.Popen([nginx, '-e', str(root / 'error.log'), '-p', tmp, '-c', str(root / 'nginx.conf')], stderr=subprocess.PIPE)
    def get(path, method='GET', follow=True):
        request = urllib.request.Request(f'http://127.0.0.1:{port}' + path, method=method)
        opener = urllib.request.urlopen if follow else no_redirect_opener.open
        try:
            response = opener(request, timeout=3)
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
        assert b'https://mirror.slopageddon.app' in body
        assert headers['Content-Type'] == 'text/html'
        assert headers['X-Content-Type-Options'] == 'nosniff'
        assert headers['Referrer-Policy'] == 'no-referrer'
        assert headers['X-Frame-Options'] == 'DENY'
        assert "default-src 'none'" in headers['Content-Security-Policy']
        assert headers['Cache-Control'] == 'no-cache'
        assert b'@hostname@' not in body
        assert b'Endpoint links open' not in body
        assert b'href="/devenv/nix-cache-info"' not in body
        assert b'data-endpoint="devenv"' in body
        assert b'CACHE STATISTICS' in body
        assert b'id="disk-free"' in body
        assert b'id="cache-hit-rate"' in body
        assert b'href="/browse/"' in body
        assert b'href="/_favicon.svg"' in body
        assert get('/', 'HEAD')[0] == 200
        assert get('/', 'POST')[0] == 403
        favicon_redir = get('/favicon.ico', follow=False)
        assert favicon_redir[0] == 308 and favicon_redir[1]['Location'].endswith('/_favicon.svg')
        status, headers, body = get('/_favicon.svg')
        assert status == 200 and headers['Content-Type'] == 'image/svg+xml'
        assert headers['Cache-Control'] == 'no-cache'
        status, headers, body = get('/_landing.css')
        assert status == 200 and headers['Content-Type'] == 'text/css'
        assert headers['Cache-Control'] == 'no-cache'
        status, headers, body = get('/_common.js')
        assert status == 200 and headers['Content-Type'] == 'application/javascript'
        assert headers['Cache-Control'] == 'no-cache'
        status, headers, body = get('/_landing.js')
        assert status == 200 and headers['Content-Type'] == 'application/javascript'
        status, headers, body = get('/_dashboard/summary.json')
        assert status == 200 and body == snapshot
        assert headers['Content-Type'] == 'application/json'
        assert headers['Cache-Control'] == 'no-store'
        assert get('/_dashboard/summary.json', 'POST')[0] == 403
        status, headers, body = get('/browse/')
        assert status == 200 and b'CACHED DOWNLOADS' in body, (status, body)
        assert headers['X-Content-Type-Options'] == 'nosniff'
        assert headers['X-Frame-Options'] == 'DENY'
        assert "default-src 'none'" in headers['Content-Security-Policy']
        assert get('/browse/', 'HEAD')[0] == 200
        assert get('/browse/', 'POST')[0] == 403
        status, headers, _ = get('/_catalog.js')
        assert status == 200 and headers['X-Content-Type-Options'] == 'nosniff'
        status, headers, _ = get('/_browse.css')
        assert status == 200 and headers['X-Content-Type-Options'] == 'nosniff'
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
        # Hashed mirror route: 301 redirect rewrite + cache, 200 payload MISS/HIT, uncached 404s.
        sha256_path = '/tarballs/sha256/' + 'b' * 64
        sha512_path = '/tarballs/sha512/' + 'f' * 128
        first_redir = get(sha256_path, follow=False)
        second_redir = get(sha256_path, follow=False)
        assert first_redir[0] == second_redir[0] == 301, (first_redir, second_redir)
        assert first_redir[1]['X-Cache-Status'] == 'MISS', first_redir
        assert second_redir[1]['X-Cache-Status'] == 'HIT', second_redir
        assert first_redir[1]['Location'].endswith(sha512_path), first_redir[1]['Location']
        assert second_redir[1]['Location'].endswith(sha512_path), second_redir[1]['Location']
        first_tarball = get(sha256_path)
        second_tarball = get(sha512_path)
        assert first_tarball[0] == second_tarball[0] == 200
        assert first_tarball[1]['X-Cache-Status'] == 'MISS', first_tarball
        assert second_tarball[1]['X-Cache-Status'] == 'HIT', second_tarball
        assert first_tarball[2] == second_tarball[2] == ('tarballs.nixos.org/sha512/' + 'f' * 128).encode()
        assert get(sha512_path, 'HEAD')[0] == 200
        assert get(sha512_path, 'POST')[0] == 403
        for _ in range(2):
            missing_tarball = get('/tarballs/sha256/missing' + '0' * 57)
            assert missing_tarball[0] == 404 and missing_tarball[1]['X-Cache-Status'] == 'MISS'
        assert get('/tarballs/sha256/short')[0] == 404
        assert get('/tarballs/unknown/' + 'a' * 64)[0] == 404
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
        assert all('missing' not in url and 'private' not in url and not url.startswith('/tarballs/') for url in urls)
    finally:
        proc.terminate()
        _, errors = proc.communicate(timeout=10)
        if proc.returncode != 0:
            raise RuntimeError(errors.decode())
        upstream.shutdown()
    logs = [json.loads(line) for line in (root / 'access.log').read_text().splitlines()]
    assert logs and all('private' not in entry['uri'] for entry in logs)
    excluded_uris = {
        '/',
        '/favicon.ico',
        '/_favicon.svg',
        '/_landing.css',
        '/_common.js',
        '/_landing.js',
        '/_dashboard/summary.json',
        '/browse/',
        '/_catalog.js',
        '/_browse.css',
        '/_dashboard/catalog.json',
    }
    assert all(entry['uri'] not in excluded_uris for entry in logs)
    for entry in logs:
        datetime.datetime.fromisoformat(entry['time'])
    print(f'PASS: landing, catalog, CSS, methods, all {len(upstreams) * 3} cache routes + /tarballs MISS/HIT/HEAD/301, uncached 404s, real cache catalog, timestamped JSON logs')
