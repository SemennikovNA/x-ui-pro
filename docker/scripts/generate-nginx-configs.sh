#!/bin/bash
# Generate nginx configuration files

set -e

OUTPUT_DIR="${1:-./docker-output}"

if [ ! -f "$OUTPUT_DIR/scripts/vars.env" ]; then
    echo "Error: vars.env not found. Run generate-docker-compose.sh first."
    exit 1
fi

# Source variables
source "$OUTPUT_DIR/scripts/vars.env"

# Generate main nginx.conf
cat > "$OUTPUT_DIR/nginx/nginx.conf" <<'NGINXEOF'
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 4096;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';
    access_log /var/log/nginx/access.log main;
    sendfile on;
    keepalive_timeout 65;
    include /etc/nginx/conf.d/*.conf;
}

stream {
    include /etc/nginx/stream.d/*.conf;
}
NGINXEOF

# Generate stream config
cat > "$OUTPUT_DIR/nginx/stream.d/stream.conf" <<EOF
map \$ssl_preread_server_name \$sni_name {
    hostnames;
    ${REALITY_DOMAIN}      xray;
    ${DOMAIN}              www;
    default                xray;
}

upstream xray {
    server xui-pro:8443;
}

upstream www {
    server xui-pro:7443;
}

server {
    proxy_protocol on;
    set_real_ip_from 172.16.0.0/12;
    set_real_ip_from 10.0.0.0/8;
    set_real_ip_from 192.168.0.0/16;
    listen          443;
    proxy_pass      \$sni_name;
    ssl_preread     on;
}
EOF

# Generate HTTP redirect config
cat > "$OUTPUT_DIR/nginx/conf.d/80.conf" <<EOF
server {
    listen 80;
    server_name ${DOMAIN} ${REALITY_DOMAIN};
    
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }
    
    location / {
        return 301 https://\$host\$request_uri;
    }
}
EOF

# Generate main domain config
cat > "$OUTPUT_DIR/nginx/conf.d/${DOMAIN}.conf" <<EOF
server {
    server_tokens off;
    server_name ${DOMAIN};
    listen 7443 ssl http2 proxy_protocol;
    listen [::]:7443 ssl http2 proxy_protocol;
    index index.html index.htm index.php index.nginx-debian.html;
    root /var/www/html/;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!eNULL:!MD5:!DES:!RC4:!ADH:!SSLv3:!EXP:!PSK:!DSS;
    ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;
    
    set_real_ip_from 172.16.0.0/12;
    set_real_ip_from 10.0.0.0/8;
    set_real_ip_from 192.168.0.0/16;
    real_ip_header proxy_protocol;
    
    if (\$host !~* ^(.+\.)?${DOMAIN}\$ ){return 444;}
    if (\$scheme ~* https) {set \$safe 1;}
    if (\$ssl_server_name !~* ^(.+\.)?${DOMAIN}\$ ) {set \$safe "\${safe}0"; }
    if (\$safe = 10){return 444;}
    if (\$request_uri ~ "(\"|'|\`|~|,|:|--|;|%|\\\$|&&|\?\?|0x00|0X00|\||\\|\{|\}|\[|\]|<|>|\.\.\.|\.\.\/|\/\/\/)"){set \$hack 1;}
    
    error_page 400 401 402 403 500 501 502 503 504 =404 /404;
    proxy_intercept_errors on;
    
    #X-UI Admin Panel
    location /${panel_path}/ {
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$proxy_protocol_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
        proxy_pass https://xui-pro:${PANEL_PORT};
        break;
    }
    location /${panel_path} {
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$proxy_protocol_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
        proxy_pass https://xui-pro:${PANEL_PORT};
        break;
    }
    
    include /etc/nginx/snippets/includes.conf;
}
EOF

# Generate includes.conf в snippets директории
cat > "$OUTPUT_DIR/nginx/snippets/includes.conf" <<EOF
#sub2sing-box
location /${sub2singbox_path}/ {
    proxy_redirect off;
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$proxy_protocol_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_pass http://xui-pro:8080/;
}

# Path to open clash.yaml and generate YAML
location ~ ^/${web_path}/clashmeta/(.+)\$ {
    default_type text/plain;
    ssi on;
    ssi_types text/plain;
    set \$subid \$1;
    root /var/www/subpage;
    try_files /clash.yaml =404;
}

# web
location ~ ^/${web_path} {
    root /var/www/subpage;
    index index.html;
    try_files \$uri \$uri/ /index.html =404;
}

#Subscription Path (simple/encode)
location /${sub_path} {
    if (\$hack = 1) {return 404;}
    proxy_redirect off;
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$proxy_protocol_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_pass https://xui-pro:${sub_port};
    break;
}
location /${sub_path}/ {
    if (\$hack = 1) {return 404;}
    proxy_redirect off;
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$proxy_protocol_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_pass https://xui-pro:${sub_port};
    break;
}
location /assets/ {
    if (\$hack = 1) {return 404;}
    proxy_redirect off;
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$proxy_protocol_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_pass https://xui-pro:${sub_port};
    break;
}
location /assets {
    if (\$hack = 1) {return 404;}
    proxy_redirect off;
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$proxy_protocol_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_pass https://xui-pro:${sub_port};
    break;
}

#Subscription Path (json/fragment)
location /${json_path} {
    if (\$hack = 1) {return 404;}
    proxy_redirect off;
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$proxy_protocol_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_pass https://xui-pro:${sub_port};
    break;
}
location /${json_path}/ {
    if (\$hack = 1) {return 404;}
    proxy_redirect off;
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$proxy_protocol_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_pass https://xui-pro:${sub_port};
    break;
}

#XHTTP
location /${xhttp_path} {
    grpc_pass grpc://unix:/dev/shm/uds2023.sock;
    grpc_buffer_size         16k;
    grpc_socket_keepalive    on;
    grpc_read_timeout        1h;
    grpc_send_timeout        1h;
    grpc_set_header Connection         "";
    grpc_set_header X-Forwarded-For    \$proxy_add_x_forwarded_for;
    grpc_set_header X-Forwarded-Proto  \$scheme;
    grpc_set_header X-Forwarded-Port   \$server_port;
    grpc_set_header Host               \$host;
    grpc_set_header X-Forwarded-Host   \$host;
}

#Xray Config Path
location ~ ^/(?<fwdport>\d+)/(?<fwdpath>.*)\$ {
    if (\$hack = 1) {return 404;}
    client_max_body_size 0;
    client_body_timeout 1d;
    grpc_read_timeout 1d;
    grpc_socket_keepalive on;
    proxy_read_timeout 1d;
    proxy_http_version 1.1;
    proxy_buffering off;
    proxy_request_buffering off;
    proxy_socket_keepalive on;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$proxy_protocol_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    if (\$content_type ~* "GRPC") {
        grpc_pass grpc://xui-pro:\$fwdport\$is_args\$args;
        break;
    }
    if (\$http_upgrade ~* "(WEBSOCKET|WS)") {
        proxy_pass http://xui-pro:\$fwdport\$is_args\$args;
        break;
    }
    if (\$request_method ~* ^(PUT|POST|GET)\$) {
        proxy_pass http://xui-pro:\$fwdport\$is_args\$args;
        break;
    }
}
location / { try_files \$uri \$uri/ =404; }
EOF

# Generate reality domain config
cat > "$OUTPUT_DIR/nginx/conf.d/${REALITY_DOMAIN}.conf" <<EOF
server {
    server_tokens off;
    server_name ${REALITY_DOMAIN};
    listen 9443 ssl http2;
    listen [::]:9443 ssl http2;
    index index.html index.htm index.php index.nginx-debian.html;
    root /var/www/html/;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!eNULL:!MD5:!DES:!RC4:!ADH:!SSLv3:!EXP:!PSK:!DSS;
    ssl_certificate /etc/letsencrypt/live/${REALITY_DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${REALITY_DOMAIN}/privkey.pem;
    
    if (\$host !~* ^(.+\.)?${REALITY_DOMAIN}\$ ){return 444;}
    if (\$scheme ~* https) {set \$safe 1;}
    if (\$ssl_server_name !~* ^(.+\.)?${REALITY_DOMAIN}\$ ) {set \$safe "\${safe}0"; }
    if (\$safe = 10){return 444;}
    if (\$request_uri ~ "(\"|'|\`|~|,|:|--|;|%|\\\$|&&|\?\?|0x00|0X00|\||\\|\{|\}|\[|\]|<|>|\.\.\.|\.\.\/|\/\/\/)"){set \$hack 1;}
    
    error_page 400 401 402 403 500 501 502 503 504 =404 /404;
    proxy_intercept_errors on;
    
    #X-UI Admin Panel
    location /${panel_path}/ {
        proxy_redirect off;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_pass http://xui-pro:${PANEL_PORT};
        break;
    }
    location /${panel_path} {
        proxy_redirect off;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_pass http://xui-pro:${PANEL_PORT};
        break;
    }
    
    include /etc/nginx/snippets/includes.conf;
}
EOF

echo "Nginx configurations generated successfully"
