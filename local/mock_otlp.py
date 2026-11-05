#!/usr/bin/env python3
"""Local stand-in for the X-Ray OTLP traces endpoint. It checks the bearer token and stores nothing.

The real endpoint also requires HTTPS, Transaction Search, and an IAM user with the right permissions.
This only lets you see the Authorization header arrive and how a client reacts to a 403.
"""
import gzip
import hmac
import os
from http.server import BaseHTTPRequestHandler, HTTPServer

API_KEY = os.environ["XRAY_API_KEY"]
PORT = int(os.environ.get("PORT", "4319"))


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        body = self.rfile.read(int(self.headers.get("Content-Length", 0)))
        if self.headers.get("Content-Encoding") == "gzip":
            body = gzip.decompress(body)

        content_type = self.headers.get("Content-Type", "")
        authorized = hmac.compare_digest(self.headers.get("Authorization", ""), f"Bearer {API_KEY}")
        status = 200 if self.path == "/v1/traces" and authorized else 403
        print(f"{status} {self.path} {content_type} {len(body)} bytes", flush=True)

        reply = b"{}" if content_type == "application/json" and status == 200 else b""
        self.send_response(status)
        self.send_header("Content-Type", content_type or "application/x-protobuf")
        self.send_header("Content-Length", str(len(reply)))
        self.end_headers()
        self.wfile.write(reply)

    def log_message(self, *args):
        pass


if __name__ == "__main__":
    print(f"Mock OTLP traces endpoint on port {PORT}", flush=True)
    HTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
