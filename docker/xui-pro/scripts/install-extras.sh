#!/bin/bash
# Install sub2sing-box and web subscription pages

set -e

# Install sub2sing-box
if [ ! -f "/usr/bin/sub2sing-box" ]; then
    echo "Installing sub2sing-box..."
    wget -P /tmp/ https://github.com/legiz-ru/sub2sing-box/releases/download/v0.0.9/sub2sing-box_0.0.9_linux_amd64.tar.gz
    tar -xvzf /tmp/sub2sing-box_0.0.9_linux_amd64.tar.gz -C /tmp/ --strip-components=1 sub2sing-box_0.0.9_linux_amd64/sub2sing-box
    mv /tmp/sub2sing-box /usr/bin/
    chmod +x /usr/bin/sub2sing-box
    rm /tmp/sub2sing-box_0.0.9_linux_amd64.tar.gz
fi

# Create web subscription page directory
mkdir -p /var/www/subpage

# Download web subscription page (default to first option)
if [ ! -f "/var/www/subpage/index.html" ] || [ "${UPDATE_WEB_PAGES:-false}" = "true" ]; then
    echo "Downloading/updating web subscription page..."
    curl -L "https://github.com/legiz-ru/x-ui-pro/raw/master/sub-3x-ui.html" -o /var/www/subpage/index.html
    
    # Replace variables if they exist
    if [ -n "${DOMAIN}" ]; then
        sed -i "s/\${DOMAIN}/${DOMAIN}/g" /var/www/subpage/index.html
    fi
    if [ -n "${SUB_JSON_PATH}" ]; then
        sed -i "s#\${SUB_JSON_PATH}#${SUB_JSON_PATH}#g" /var/www/subpage/index.html
    fi
    if [ -n "${SUB_PATH}" ]; then
        sed -i "s#\${SUB_PATH}#${SUB_PATH}#g" /var/www/subpage/index.html
    fi
    if [ -n "${SUB2SINGBOX_PATH}" ]; then
        sed -i "s|sub.legiz.ru|${DOMAIN}/${SUB2SINGBOX_PATH}|g" /var/www/subpage/index.html
    fi
fi

# Download clash.yaml (default to first option)
if [ ! -f "/var/www/subpage/clash.yaml" ] || [ "${UPDATE_WEB_PAGES:-false}" = "true" ]; then
    echo "Downloading/updating clash.yaml..."
    curl -L "https://github.com/legiz-ru/x-ui-pro/raw/master/clash/clash.yaml" -o /var/www/subpage/clash.yaml
    
    # Replace variables if they exist
    if [ -n "${DOMAIN}" ]; then
        sed -i "s/\${DOMAIN}/${DOMAIN}/g" /var/www/subpage/clash.yaml
    fi
    if [ -n "${SUB_PATH}" ]; then
        sed -i "s#\${SUB_PATH}#${SUB_PATH}#g" /var/www/subpage/clash.yaml
    fi
fi

# Start sub2sing-box in background
if ! pgrep -x "sub2sing-box" > /dev/null; then
    echo "Starting sub2sing-box..."
    /usr/bin/sub2sing-box server --bind 127.0.0.1 --port 8080 > /dev/null 2>&1 &
fi

echo "Extras installed successfully"
