#!/bin/bash
set -e

XUIDB="/etc/x-ui/x-ui.db"
DOMAIN="${DOMAIN:-example.com}"
REALITY_DOMAIN="${REALITY_DOMAIN:-reality.example.com}"
PANEL_PORT="${PANEL_PORT:-2053}"

if [ ! -f "$XUIDB" ]; then
    echo "Error: x-ui.db not found at $XUIDB"
    exit 1
fi

# Generate random strings
gen_random_string() {
    local length="$1"
    head -c 4096 /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c "$length"
    echo
}

# Get free port
get_port() {
    echo $(( ((RANDOM<<15)|RANDOM) % 49152 + 10000 ))
}

# Use environment variables if provided, otherwise generate
sub_port=${SUB_PORT:-$(get_port)}
ws_port=${WS_PORT:-$(get_port)}
trojan_port=${TROJAN_PORT:-$(get_port)}
web_path=${WEB_PATH:-$(gen_random_string 10)}
sub2singbox_path=${SUB2SINGBOX_PATH:-$(gen_random_string 10)}
sub_path=${SUB_PATH:-$(gen_random_string 10)}
json_path=${JSON_PATH:-$(gen_random_string 10)}
panel_path=${PANEL_PATH:-$(gen_random_string 10)}
ws_path=${WS_PATH:-$(gen_random_string 10)}
trojan_path=${TROJAN_PATH:-$(gen_random_string 10)}
xhttp_path=${XHTTP_PATH:-$(gen_random_string 10)}
config_username=${CONFIG_USERNAME:-$(gen_random_string 10)}
config_password=${CONFIG_PASSWORD:-$(gen_random_string 10)}

# Generate URIs
sub_uri="https://${DOMAIN}/${sub_path}/"
json_uri="https://${DOMAIN}/${web_path}?name="

# Generate keys
output=$(/usr/local/x-ui/bin/xray-linux-amd64 x25519 2>/dev/null || /usr/local/x-ui/bin/xray-linux-$(arch) x25519)
private_key=$(echo "$output" | grep "^PrivateKey:" | awk '{print $2}')
public_key=$(echo "$output" | grep "^Password:" | awk '{print $2}')

client_id=$(/usr/local/x-ui/bin/xray-linux-amd64 uuid 2>/dev/null || /usr/local/x-ui/bin/xray-linux-$(arch) uuid)
client_id2=$(/usr/local/x-ui/bin/xray-linux-amd64 uuid 2>/dev/null || /usr/local/x-ui/bin/xray-linux-$(arch) uuid)
client_id3=$(/usr/local/x-ui/bin/xray-linux-amd64 uuid 2>/dev/null || /usr/local/x-ui/bin/xray-linux-$(arch) uuid)
trojan_pass=$(gen_random_string 10)

# Generate short IDs
shor=($(openssl rand -hex 8) $(openssl rand -hex 8) $(openssl rand -hex 8) $(openssl rand -hex 8) $(openssl rand -hex 8) $(openssl rand -hex 8) $(openssl rand -hex 8) $(openssl rand -hex 8))

# Get emoji flag
emoji_flag=$(LC_ALL=en_US.UTF-8 curl -s https://ipwho.is/ 2>/dev/null | jq -r '.flag.emoji' 2>/dev/null || echo "🌐")

arch() {
    case "$(uname -m)" in
        x86_64 | x64 | amd64) echo 'amd64' ;;
        i*86 | x86) echo '386' ;;
        armv8* | armv8 | arm64 | aarch64) echo 'arm64' ;;
        armv7* | armv7 | arm) echo 'armv7' ;;
        armv6* | armv6) echo 'armv6' ;;
        armv5* | armv5) echo 'armv5' ;;
        s390x) echo 's390x' ;;
        *) echo 'amd64' ;;
    esac
}

# Check if database already initialized
if sqlite3 "$XUIDB" "SELECT COUNT(*) FROM settings WHERE key='subPort';" 2>/dev/null | grep -q "1"; then
    echo "Database already initialized, skipping..."
    exit 0
fi

echo "Initializing x-ui database..."

# Stop x-ui if running
/usr/local/x-ui/x-ui stop 2>/dev/null || true

# Insert settings and inbounds
sqlite3 "$XUIDB" <<EOF
INSERT INTO "settings" ("key", "value") VALUES ("subPort",  '${sub_port}');
INSERT INTO "settings" ("key", "value") VALUES ("subPath",  '/${sub_path}/');
INSERT INTO "settings" ("key", "value") VALUES ("subURI",  '${sub_uri}');
INSERT INTO "settings" ("key", "value") VALUES ("subJsonPath",  '${json_path}');
INSERT INTO "settings" ("key", "value") VALUES ("subJsonURI",  '${json_uri}');
INSERT INTO "settings" ("key", "value") VALUES ("subEnable",  'true');
INSERT INTO "settings" ("key", "value") VALUES ("webListen",  '');
INSERT INTO "settings" ("key", "value") VALUES ("webDomain",  '');
INSERT INTO "settings" ("key", "value") VALUES ("webCertFile",  '');
INSERT INTO "settings" ("key", "value") VALUES ("webKeyFile",  '');
INSERT INTO "settings" ("key", "value") VALUES ("sessionMaxAge",  '60');
INSERT INTO "settings" ("key", "value") VALUES ("pageSize",  '50');
INSERT INTO "settings" ("key", "value") VALUES ("expireDiff",  '0');
INSERT INTO "settings" ("key", "value") VALUES ("trafficDiff",  '0');
INSERT INTO "settings" ("key", "value") VALUES ("remarkModel",  '-ieo');
INSERT INTO "settings" ("key", "value") VALUES ("tgBotEnable",  'false');
INSERT INTO "settings" ("key", "value") VALUES ("tgBotToken",  '');
INSERT INTO "settings" ("key", "value") VALUES ("tgBotProxy",  '');
INSERT INTO "settings" ("key", "value") VALUES ("tgBotAPIServer",  '');
INSERT INTO "settings" ("key", "value") VALUES ("tgBotChatId",  '');
INSERT INTO "settings" ("key", "value") VALUES ("tgRunTime",  '@daily');
INSERT INTO "settings" ("key", "value") VALUES ("tgBotBackup",  'false');
INSERT INTO "settings" ("key", "value") VALUES ("tgBotLoginNotify",  'true');
INSERT INTO "settings" ("key", "value") VALUES ("tgCpu",  '80');
INSERT INTO "settings" ("key", "value") VALUES ("tgLang",  'en-US');
INSERT INTO "settings" ("key", "value") VALUES ("timeLocation",  'Europe/Moscow');
INSERT INTO "settings" ("key", "value") VALUES ("secretEnable",  'false');
INSERT INTO "settings" ("key", "value") VALUES ("subDomain",  '');
INSERT INTO "settings" ("key", "value") VALUES ("subCertFile",  '');
INSERT INTO "settings" ("key", "value") VALUES ("subKeyFile",  '');
INSERT INTO "settings" ("key", "value") VALUES ("subUpdates",  '12');
INSERT INTO "settings" ("key", "value") VALUES ("subEncrypt",  'true');
INSERT INTO "settings" ("key", "value") VALUES ("subShowInfo",  'true');
INSERT INTO "settings" ("key", "value") VALUES ("subJsonFragment",  '');
INSERT INTO "settings" ("key", "value") VALUES ("subJsonNoises",  '');
INSERT INTO "settings" ("key", "value") VALUES ("subJsonMux",  '');
INSERT INTO "settings" ("key", "value") VALUES ("subJsonRules",  '');
INSERT INTO "settings" ("key", "value") VALUES ("datepicker",  'gregorian');
INSERT INTO "client_traffics" ("inbound_id","enable","email","up","down","expiry_time","total","reset") VALUES ('1','1','first','0','0','0','0','0');
INSERT INTO "client_traffics" ("inbound_id","enable","email","up","down","expiry_time","total","reset") VALUES ('2','1','first_1','0','0','0','0','0');
INSERT INTO "client_traffics" ("inbound_id","enable","email","up","down","expiry_time","total","reset") VALUES ('3','1','firstX','0','0','0','0','0');
INSERT INTO "client_traffics" ("inbound_id","enable","email","up","down","expiry_time","total","reset") VALUES ('4','1','firstT','0','0','0','0','0');
INSERT INTO "inbounds" ("user_id","up","down","total","remark","enable","expiry_time","listen","port","protocol","settings","stream_settings","tag","sniffing") VALUES ( 
'1','0','0','0','${emoji_flag} reality','1','0','','8443','vless',
'{"clients":[{"id":"${client_id}","flow":"xtls-rprx-vision","email":"first","limitIp":0,"totalGB":0,"expiryTime":0,"enable":true,"tgId":"","subId":"first","reset":0,"created_at":1756726925000,"updated_at":1756726925000}],"decryption":"none","fallbacks":[]}',
'{"network":"tcp","security":"reality","externalProxy":[{"forceTls":"same","dest":"${DOMAIN}","port":443,"remark":""}],"realitySettings":{"show":false,"xver":0,"target":"127.0.0.1:9443","serverNames":["${REALITY_DOMAIN}"],"privateKey":"${private_key}","minClient":"","maxClient":"","maxTimediff":0,"shortIds":["${shor[0]}","${shor[1]}","${shor[2]}","${shor[3]}","${shor[4]}","${shor[5]}","${shor[6]}","${shor[7]}"],"settings":{"publicKey":"${public_key}","fingerprint":"random","serverName":"","spiderX":"/"}},"tcpSettings":{"acceptProxyProtocol":true,"header":{"type":"none"}}}',
'inbound-8443','{"enabled":false,"destOverride":["http","tls","quic","fakedns"],"metadataOnly":false,"routeOnly":false}'
);
INSERT INTO "inbounds" ("user_id","up","down","total","remark","enable","expiry_time","listen","port","protocol","settings","stream_settings","tag","sniffing") VALUES ( 
'1','0','0','0','${emoji_flag} ws','1','0','','${ws_port}','vless',
'{"clients":[{"id":"${client_id2}","flow":"","email":"first_1","limitIp":0,"totalGB":0,"expiryTime":0,"enable":true,"tgId":"","subId":"first","reset":0,"created_at":1756726925000,"updated_at":1756726925000}],"decryption":"none","fallbacks":[]}',
'{"network":"ws","security":"none","externalProxy":[{"forceTls":"tls","dest":"${DOMAIN}","port":443,"remark":""}],"wsSettings":{"acceptProxyProtocol":false,"path":"/${ws_port}/${ws_path}","host":"${DOMAIN}","headers":{}}}',
'inbound-${ws_port}','{"enabled":false,"destOverride":["http","tls","quic","fakedns"],"metadataOnly":false,"routeOnly":false}'
);
INSERT INTO "inbounds" ("user_id","up","down","total","remark","enable","expiry_time","listen","port","protocol","settings","stream_settings","tag","sniffing") VALUES ( 
'1','0','0','0','${emoji_flag} xhttp','1','0','/dev/shm/uds2023.sock,0666','0','vless',
'{"clients":[{"id":"${client_id3}","flow":"","email":"firstX","limitIp":0,"totalGB":0,"expiryTime":0,"enable":true,"tgId":"","subId":"first","reset":0,"created_at":1756726925000,"updated_at":1756726925000}],"decryption":"none","fallbacks":[]}',
'{"network":"xhttp","security":"none","externalProxy":[{"forceTls":"tls","dest":"${DOMAIN}","port":443,"remark":""}],"xhttpSettings":{"path":"/${xhttp_path}","host":"","headers":{},"scMaxBufferedPosts":30,"scMaxEachPostBytes":"1000000","noSSEHeader":false,"xPaddingBytes":"100-1000","mode":"packet-up"},"sockopt":{"acceptProxyProtocol":false,"tcpFastOpen":true,"mark":0,"tproxy":"off","tcpMptcp":true,"tcpNoDelay":true,"domainStrategy":"UseIP","tcpMaxSeg":1440,"dialerProxy":"","tcpKeepAliveInterval":0,"tcpKeepAliveIdle":300,"tcpUserTimeout":10000,"tcpcongestion":"bbr","V6Only":false,"tcpWindowClamp":600,"interface":""}}',
'inbound-/dev/shm/uds2023.sock,0666:0|','{"enabled":true,"destOverride":["http","tls","quic","fakedns"],"metadataOnly":false,"routeOnly":false}'
);
INSERT INTO "inbounds" ("user_id","up","down","total","remark","enable","expiry_time","listen","port","protocol","settings","stream_settings","tag","sniffing") VALUES ( 
'1','0','0','0','${emoji_flag} trojan-grpc','1','0','','${trojan_port}','trojan',
'{"clients":[{"comment":"","created_at":1756726925000,"email":"firstT","enable":true,"expiryTime":0,"limitIp":0,"password":"${trojan_pass}","reset":0,"subId":"first","tgId":0,"totalGB":0,"updated_at":1756726925000}],"fallbacks":[]}',
'{"network":"grpc","security":"none","externalProxy":[{"forceTls":"tls","dest":"${DOMAIN}","port":443,"remark":""}],"grpcSettings":{"serviceName":"/${trojan_port}/${trojan_path}","authority":"${DOMAIN}","multiMode":false}}',
'inbound-${trojan_port}','{"enabled":false,"destOverride":["http","tls","quic","fakedns"],"metadataOnly":false,"routeOnly":false}'
);
EOF

# Configure x-ui
/usr/local/x-ui/x-ui setting -username "${config_username}" -password "${config_password}" -port "${PANEL_PORT}" -webBasePath "${panel_path}"

echo "x-ui database initialized successfully"
echo "Panel credentials:"
echo "  Username: ${config_username}"
echo "  Password: ${config_password}"
echo "  Port: ${PANEL_PORT}"
echo "  Path: ${panel_path}"
