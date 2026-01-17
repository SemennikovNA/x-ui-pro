#!/bin/bash
# Script to generate Docker Compose files for x-ui-pro

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

msg_ok() { echo -e "${GREEN}[OK]${NC} $1"; }
msg_inf() { echo -e "${YELLOW}[INFO]${NC} $1"; }
msg_err() { echo -e "${RED}[ERROR]${NC} $1"; }

# Default values
DOMAIN="${1:-}"
REALITY_DOMAIN="${2:-}"
TZ="${TZ:-Asia/Almaty}"
OUTPUT_DIR="${OUTPUT_DIR:-./docker-output}"

# Validate input
if [ -z "$DOMAIN" ]; then
    echo "Usage: $0 <domain> [reality_domain] [timezone]"
    echo "Example: $0 adm.duckondigitalwave.space reality.duckondigitalwave.space Asia/Almaty"
    exit 1
fi

if [ -z "$REALITY_DOMAIN" ]; then
    REALITY_DOMAIN="$DOMAIN"
fi

msg_inf "Generating Docker Compose configuration..."
msg_inf "Domain: $DOMAIN"
msg_inf "Reality Domain: $REALITY_DOMAIN"
msg_inf "Timezone: $TZ"

# Create output directory structure
mkdir -p "$OUTPUT_DIR"/{xui-pro,nginx/{conf.d,stream.d,snippets},scripts,data/{xui,letsencrypt,certbot-www,nginx-logs}}

# Generate random strings
gen_random_string() {
    head -c 4096 /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c "$1"
}

# Generate ports (will be exposed in nginx, not in docker-compose)
PANEL_PORT="2053"
sub_port=$(echo $(( ((RANDOM<<15)|RANDOM) % 49152 + 10000 )))
panel_path=$(gen_random_string 10)
web_path=$(gen_random_string 10)
sub2singbox_path=$(gen_random_string 10)
sub_path=$(gen_random_string 10)
json_path=$(gen_random_string 10)
ws_port=$(echo $(( ((RANDOM<<15)|RANDOM) % 49152 + 10000 )))
trojan_port=$(echo $(( ((RANDOM<<15)|RANDOM) % 49152 + 10000 )))
ws_path=$(gen_random_string 10)
trojan_path=$(gen_random_string 10)
xhttp_path=$(gen_random_string 10)
config_username=$(gen_random_string 10)
config_password=$(gen_random_string 10)

# Save variables to file for nginx generation
cat > "$OUTPUT_DIR/scripts/vars.env" <<EOF
DOMAIN=$DOMAIN
REALITY_DOMAIN=$REALITY_DOMAIN
PANEL_PORT=$PANEL_PORT
sub_port=$sub_port
panel_path=$panel_path
web_path=$web_path
sub2singbox_path=$sub2singbox_path
sub_path=$sub_path
json_path=$json_path
ws_port=$ws_port
trojan_port=$trojan_port
ws_path=$ws_path
trojan_path=$trojan_path
xhttp_path=$xhttp_path
EOF

# Generate Docker Compose file
cat > "$OUTPUT_DIR/docker-compose.yml" <<EOF
networks:
  vpnnet:
    driver: bridge

services:
  xui-pro:
    build: ./docker/xui-pro
    container_name: xui-pro
    restart: unless-stopped
    networks: [vpnnet]
    environment:
      TZ: "${TZ}"
      DOMAIN: "${DOMAIN}"
      REALITY_DOMAIN: "${REALITY_DOMAIN}"
      PANEL_PORT: "${PANEL_PORT}"
      PANEL_PATH: "${panel_path}"
      CONFIG_USERNAME: "${config_username}"
      CONFIG_PASSWORD: "${config_password}"
      SUB_PORT: "${sub_port}"
      WS_PORT: "${ws_port}"
      TROJAN_PORT: "${trojan_port}"
      WEB_PATH: "${web_path}"
      SUB2SINGBOX_PATH: "${sub2singbox_path}"
      SUB_PATH: "${sub_path}"
      JSON_PATH: "${json_path}"
      WS_PATH: "${ws_path}"
      TROJAN_PATH: "${trojan_path}"
      XHTTP_PATH: "${xhttp_path}"
    volumes:
      - ./data/xui:/etc/x-ui
      - ./data/letsencrypt:/etc/letsencrypt
    expose:
      - "${PANEL_PORT}"
      - "8443"
    cap_add:
      - NET_ADMIN
      - SYS_ADMIN
    command: ["x-ui"]

  nginx:
    image: nginx:1.25-alpine
    container_name: nginx
    restart: unless-stopped
    networks: [vpnnet]
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./nginx/conf.d:/etc/nginx/conf.d:ro
      - ./nginx/stream.d:/etc/nginx/stream.d:ro
      - ./nginx/snippets:/etc/nginx/snippets:ro
      - ./data/letsencrypt:/etc/letsencrypt:ro
      - ./data/certbot-www:/var/www/certbot:ro
      - ./data/nginx-logs:/var/log/nginx
    depends_on:
      - xui-pro
      - certbot
    command: >
      sh -c "nginx -t && nginx -g 'daemon off;'"

  certbot:
    image: certbot/certbot:latest
    container_name: certbot
    networks: [vpnnet]
    volumes:
      - ./data/letsencrypt:/etc/letsencrypt
      - ./data/certbot-www:/var/www/certbot
    entrypoint: ["sh","-c","sleep infinity"]
EOF

msg_ok "Docker Compose file generated: $OUTPUT_DIR/docker-compose.yml"

# Generate nginx configs
# Определяем путь к скрипту генерации nginx конфигов
NGINX_GEN_SCRIPT=""
if [ -f "./docker/scripts/generate-nginx-configs.sh" ]; then
    NGINX_GEN_SCRIPT="./docker/scripts/generate-nginx-configs.sh"
elif [ -f "$(dirname "$0")/scripts/generate-nginx-configs.sh" ]; then
    NGINX_GEN_SCRIPT="$(dirname "$0")/scripts/generate-nginx-configs.sh"
elif [ -f "docker/scripts/generate-nginx-configs.sh" ]; then
    NGINX_GEN_SCRIPT="docker/scripts/generate-nginx-configs.sh"
else
    msg_err "Не найден скрипт generate-nginx-configs.sh"
    exit 1
fi

bash "$NGINX_GEN_SCRIPT" "$OUTPUT_DIR"

msg_ok "Nginx configurations generated"

# Create README
cat > "$OUTPUT_DIR/README.md" <<EOF
# x-ui-pro Docker Compose Setup

## Configuration

- **Domain**: $DOMAIN
- **Reality Domain**: $REALITY_DOMAIN
- **Panel Port**: $PANEL_PORT
- **Panel Path**: /$panel_path/
- **Panel Username**: $config_username
- **Panel Password**: $config_password

## Usage

1. Ensure your domains point to this server's IP
2. Run: \`docker-compose up -d\`
3. Wait for certificates to be generated (certbot container)
4. Access panel at: https://$DOMAIN/$panel_path/

## Generated Files

- \`docker-compose.yml\` - Main compose file
- \`nginx/\` - Nginx configuration files
- \`scripts/vars.env\` - Environment variables used during generation
- \`data/\` - Data volumes (x-ui database, certificates, logs)

## Notes

- Certificates are stored in \`./data/letsencrypt\`
- x-ui data is stored in \`./data/xui\`
- First run may take a few minutes for certificate generation
EOF

msg_ok "Setup complete!"
msg_inf "Next steps:"
msg_inf "  1. cd $OUTPUT_DIR"
msg_inf "  2. docker-compose build"
msg_inf "  3. docker-compose up -d"
msg_inf ""
msg_inf "Panel will be available at: https://$DOMAIN/$panel_path/"
msg_inf "Username: $config_username"
msg_inf "Password: $config_password"
