#!/bin/bash
# Script to obtain SSL certificates using certbot

set -e

DOMAIN="${1:-}"
REALITY_DOMAIN="${2:-}"

if [ -z "$DOMAIN" ]; then
    echo "Usage: $0 <domain> [reality_domain]"
    exit 1
fi

if [ -z "$REALITY_DOMAIN" ]; then
    REALITY_DOMAIN="$DOMAIN"
fi

echo "Obtaining certificates for $DOMAIN and $REALITY_DOMAIN"

# Wait for nginx to be ready (for ACME challenge)
echo "Waiting for nginx to be ready..."
for i in {1..30}; do
    if docker-compose ps nginx | grep -q "Up"; then
        break
    fi
    sleep 2
done

# Obtain certificates
docker-compose run --rm certbot certonly --webroot \
    --webroot-path=/var/www/certbot \
    --email admin@${DOMAIN} \
    --agree-tos \
    --no-eff-email \
    -d ${DOMAIN} \
    -d ${REALITY_DOMAIN}

echo "Certificates obtained successfully!"
