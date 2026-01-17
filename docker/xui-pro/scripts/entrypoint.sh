#!/bin/bash
set -e

# Install x-ui if not exists
if [ ! -f "/usr/local/x-ui/x-ui" ]; then
    echo "Installing x-ui..."
    /tmp/install-xui.sh
fi

# Install extras (sub2sing-box, web pages)
if [ ! -f "/usr/bin/sub2sing-box" ] || [ ! -f "/var/www/subpage/index.html" ]; then
    echo "Installing extras..."
    /usr/local/bin/install-extras.sh || true
fi

# Start sub2sing-box if not running
if ! pgrep -x "sub2sing-box" > /dev/null; then
    /usr/bin/sub2sing-box server --bind 127.0.0.1 --port 8080 > /dev/null 2>&1 &
fi

# Initialize x-ui database if needed
if [ ! -f "/etc/x-ui/x-ui.db" ]; then
    echo "Initializing x-ui database..."
    /usr/local/bin/init-xui.sh
fi

# Execute command
exec "$@"
