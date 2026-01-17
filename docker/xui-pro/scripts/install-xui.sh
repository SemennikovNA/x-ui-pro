#!/bin/bash
set -e

arch() {
    case "$(uname -m)" in
        x86_64 | x64 | amd64) echo 'amd64' ;;
        i*86 | x86) echo '386' ;;
        armv8* | armv8 | arm64 | aarch64) echo 'arm64' ;;
        armv7* | armv7 | arm) echo 'armv7' ;;
        armv6* | armv6) echo 'armv6' ;;
        armv5* | armv5) echo 'armv5' ;;
        s390x) echo 's390x' ;;
        *) echo "Unsupported CPU architecture!" && exit 1 ;;
    esac
}

ARCH=$(arch)

# Get latest version
tag_version=$(curl -Ls "https://api.github.com/repos/MHSanaei/3x-ui/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
if [[ ! -n "$tag_version" ]]; then
    tag_version=$(curl -4 -Ls "https://api.github.com/repos/MHSanaei/3x-ui/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
fi

echo "Installing x-ui ${tag_version} for ${ARCH}..."

# Download x-ui
cd /tmp
wget -O x-ui-linux-${ARCH}.tar.gz https://github.com/MHSanaei/3x-ui/releases/download/${tag_version}/x-ui-linux-${ARCH}.tar.gz
tar zxvf x-ui-linux-${ARCH}.tar.gz
rm x-ui-linux-${ARCH}.tar.gz

cd x-ui
chmod +x x-ui x-ui.sh bin/xray-linux-${ARCH}

# Move files
mv -f * /usr/local/x-ui/
mv -f /usr/local/x-ui/x-ui.sh /usr/bin/x-ui
chmod +x /usr/bin/x-ui /usr/local/x-ui/bin/xray-linux-${ARCH}

# Create systemd service file (for compatibility)
mkdir -p /etc/systemd/system
cat > /etc/systemd/system/x-ui.service << EOF
[Unit]
Description=x-ui Service
After=network.target

[Service]
Type=simple
WorkingDirectory=/usr/local/x-ui
ExecStart=/usr/local/x-ui/x-ui
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

# Initial config
/usr/local/x-ui/x-ui setting -username "asdfasdf" -password "asdfasdf" -port "2096" -webBasePath "asdfasdf"
/usr/local/x-ui/x-ui migrate

echo "x-ui installed successfully"
