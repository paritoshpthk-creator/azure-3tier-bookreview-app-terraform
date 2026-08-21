#!/bin/bash
sudo apt-get update -y
sudo apt-get install -y python3 python3-pip git postgresql-client curl

mkdir -p /opt/bookreview-backend
cat <<'PYAPP' > /opt/bookreview-backend/app.py
from http.server import HTTPServer, BaseHTTPRequestHandler
import json

class SimpleHTTPRequestHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/health':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({"status": "UP", "tier": "backend"}).encode())
        else:
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({"message": "Book Review App Backend API"}).encode())

httpd = HTTPServer(('0.0.0.0', 5000), SimpleHTTPRequestHandler)
httpd.serve_forever()
PYAPP

cat <<'SERVICE' > /etc/systemd/system/bookapp.service
[Unit]
Description=Book Review Application API
After=network.target

[Service]
User=ubuntu
WorkingDirectory=/opt/bookreview-backend
ExecStart=/usr/bin/python3 /opt/bookreview-backend/app.py
Restart=always

[Install]
WantedBy=multi-user.target
SERVICE

sudo systemctl daemon-reload
sudo systemctl enable bookapp
sudo systemctl start bookapp
