#!/usr/bin/env python3
"""Exercise real token functions against a local Gitea API stub."""
import json
import os
from pathlib import Path
import subprocess
from http.server import BaseHTTPRequestHandler, HTTPServer
from threading import Thread

ROOT = Path(__file__).resolve().parents[1]
script = (ROOT / 'automation/gitops/components/renovate/files/seed-bot.sh').read_text()
functions = script[script.index('delete_named_token() {'):script.index('\nwrite_secret() {')]
state = {}
class API(BaseHTTPRequestHandler):
    def log_message(self, *args): pass
    def reply(self, status, body=None):
        self.send_response(status); self.end_headers()
        if body is not None: self.wfile.write(json.dumps(body).encode())
    def do_GET(self):
        page = int(self.path.split('page=')[1])
        if state.get('list_error'): return self.reply(403)
        self.reply(200, state['tokens'][(page-1)*50:page*50])
    def do_DELETE(self):
        if state.get('delete_error'): return self.reply(403)
        ident = int(self.path.rsplit('/', 1)[1])
        state['tokens'] = [t for t in state['tokens'] if t['id'] != ident]
        state['deleted'].append(ident)
        self.reply(204)
    def do_POST(self):
        body = json.loads(self.rfile.read(int(self.headers['Content-Length'])))
        state['posts'].append(body)
        if state.get('create_error') or any(t['name'] == body['name'] for t in state['tokens']):
            return self.reply(400, {'message': 'rejected'})
        state['tokens'].append({'id': 999, 'name': body['name']})
        self.reply(201, {'sha1': 'fake-test-token'})
server = HTTPServer(('127.0.0.1', 0), API)
Thread(target=server.serve_forever, daemon=True).start()
def execute(tokens, **errors):
    state.clear(); state.update(tokens=tokens, deleted=[], posts=[], **errors)
    return subprocess.run(['bash', '-ec', 'set -euo pipefail\nbot_auth() { printf "Authorization: Basic test"; }\n' + functions + '\ndelete_named_token\nmint_token'], env=dict(os.environ, API=f'http://127.0.0.1:{server.server_port}', BOT_USER='bot', TOKEN_NAME='renovate'), capture_output=True, text=True)
try:
    assert execute([{'id': 7, 'name': 'renovate'}]).returncode == 0
    assert state['deleted'] == [7]  # Regression: single/final ID was previously skipped.
    assert execute(state['tokens'][:]).returncode == 0  # Rerun replaces the minted token.
    tokens = [{'id': n, 'name': f'other-{n}'} for n in range(50)] + [{'id': 51, 'name': 'renovate'}]
    assert execute(tokens).returncode == 0 and state['deleted'] == [51]
    assert len(state['tokens']) == 51  # Other token names survive pagination/deletion.
    for error in ('list_error', 'delete_error'):
        assert execute([{'id': 7, 'name': 'renovate'}], **{error: True}).returncode != 0
        assert not state['posts']
    assert execute([], create_error=True).returncode != 0
    assert len(state['posts']) == 1 and 'all' not in state['posts'][0]['scopes']
    print('PASS: final token deletion, repeated setup, pagination, unrelated tokens, API failures, scoped creation')
finally:
    server.shutdown()
    for name in ('gitea-bot-token.sha1', 'gitea-bot-token.json', 'gitea-bot-tokens.json', 'gitea-bot-token-ids'):
        Path('/tmp', name).unlink(missing_ok=True)
