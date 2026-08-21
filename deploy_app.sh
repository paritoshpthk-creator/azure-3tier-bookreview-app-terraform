Set-Content -Path .\deploy_app.sh -Value @'
#!/bin/bash
cat << 'EOF' > /opt/app.py
from flask import Flask
app = Flask(__name__)

@app.route('/')
def home():
    return 'Book Review App Tier is up and running on port 5000!'

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
EOF

cat << 'EOF' > /etc/systemd/system/flaskapp.service
[Unit]
Description=Flask Application
After=network.target

[Service]
User=root
WorkingDirectory=/opt
ExecStart=/usr/bin/python3 /opt/app.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now flaskapp
systemctl restart flaskapp
systemctl status flaskapp --no-pager
'@