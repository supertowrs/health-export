"""Test receiver: python3 receiver.py [port] [token]

Saves the text of each POST to ./received/ and answers 401 if the Bearer token doesn't match.
"""
import json
import sys
from datetime import datetime
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8787
TOKEN = sys.argv[2] if len(sys.argv) > 2 else None
OUT = Path(__file__).parent / "received"


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        if TOKEN and self.headers.get("Authorization") != f"Bearer {TOKEN}":
            self.send_response(401)
            self.end_headers()
            self.wfile.write(b"bad token")
            return
        body = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
        OUT.mkdir(exist_ok=True)
        name = f"{datetime.now():%H%M%S%f}.txt"
        (OUT / name).write_text(body.get("text", ""))
        print(f"--- {name}\n{body.get('text')}", flush=True)
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b"ok")


HTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
