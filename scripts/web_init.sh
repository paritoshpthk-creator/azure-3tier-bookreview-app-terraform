#!/bin/bash
sudo apt-get update -y
sudo apt-get install -y nginx curl

sudo systemctl enable nginx
sudo systemctl start nginx

sudo cat <<'HEALTH' > /var/www/html/health.html
OK
HEALTH

sudo cat <<'NGINX' > /etc/nginx/sites-available/default
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    root /var/www/html;
    index index.html index.htm index.nginx-debian.html;

    server_name _;

    location /health {
        default_type text/plain;
        return 200 'healthy\n';
    }

    location /api/ {
        proxy_pass http://10.0.2.10:5000/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    location / {
        try_files $uri $uri/ =404;
    }
}
NGINX

sudo systemctl restart nginx
