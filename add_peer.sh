#!/usr/bin/env bash
set -euo pipefail

########################################
# CONFIG
########################################

WIREGUARD_FOLDER="${WIREGUARD_FOLDER:-/opt/homebrew/etc/wireguard}"
KEYS_DIR="${KEYS_DIR:-./keys}"
PEERS_DIR="${PEERS_DIR:-./peers}"
VPN_BASE="10.0"

# Server endpoint (EDIT THIS or export SERVER_ENDPOINT)

########################################

if [[ $# -lt 3 ]]; then
  echo "Usage: $0 <wg-interface> <peer-name> <public-ip:port>"
  echo "Ex:   $0 wg0 iphone-luis 192.168.0.1:48000"
  exit 1
fi

WG_INTERFACE="$1"
PEER_NAME="$2"
SERVER_ENDPOINT="$3"

WG_CONF_FILE="${WIREGUARD_FOLDER}/${WG_INTERFACE}.conf"
if [[ ! -f "$WG_CONF_FILE" ]]; then
  echo "❌ ${WG_CONF_FILE} does not exist."
  echo "   Run first: init_wireguard_interface.sh ${WG_INTERFACE}"
  exit 1
fi

SERVER_PUB_KEY_FILE="${KEYS_DIR}/server_public.key"
if [[ ! -f "$SERVER_PUB_KEY_FILE" ]]; then
  echo "❌ ${SERVER_PUB_KEY_FILE} not found."
  echo "   Run first: init_wireguard_interface.sh wg0"
  exit 1
fi

SERVER_PUB_KEY="$(cat "$SERVER_PUB_KEY_FILE")"

########################################
# Calculate peer IP based on interface
########################################

INTERFACE_NUM="$(echo "$WG_INTERFACE" | grep -o '[0-9]\+' || echo 0)"
PEER_IP="10.0.${INTERFACE_NUM}.$(( RANDOM % 200 + 10 ))"

########################################
# Create peer folder
########################################

PEER_DIR="${PEERS_DIR}/${WG_INTERFACE}-${PEER_NAME}"
mkdir -p "$PEER_DIR"
chmod 700 "$PEER_DIR"

echo "📁 Creating peer '${WG_INTERFACE}-${PEER_NAME}' in ${PEER_DIR}…"

########################################
# Generate peer keys
########################################

wg genkey | tee "${PEER_DIR}/private.key" | wg pubkey > "${PEER_DIR}/public.key"
chmod 600 "${PEER_DIR}/private.key" "${PEER_DIR}/public.key"

PEER_PRIV_KEY="$(cat "${PEER_DIR}/private.key")"
PEER_PUB_KEY="$(cat "${PEER_DIR}/public.key")"

########################################
# Create peer config file
########################################

CONF_PATH="${PEER_DIR}/${WG_INTERFACE}-${PEER_NAME}.conf"

cat > "$CONF_PATH" <<EOF
[Interface]
PrivateKey = $PEER_PRIV_KEY
Address = ${PEER_IP}/32
DNS = 8.8.8.8

[Peer]
PublicKey = $SERVER_PUB_KEY
Endpoint = $SERVER_ENDPOINT
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
EOF

echo "📝 Peer config created at: $CONF_PATH"

########################################
# Add peer to server's wgX.conf
########################################

echo "🔧 Adding peer to ${WG_CONF_FILE}…"
sudo tee -a "$WG_CONF_FILE" >/dev/null <<EOF

[Peer]
# ${PEER_NAME}
PublicKey = $PEER_PUB_KEY
AllowedIPs = ${PEER_IP}/32
EOF

########################################
# Restart interface
########################################

echo "🔄 Restarting ${WG_INTERFACE}…"
sudo wg-quick down "$WG_INTERFACE" || true
sudo wg-quick up "$WG_INTERFACE"

########################################
# Show QR
########################################

echo "📱 QR code to scan from client:"
qrencode -t ansiutf8 < "$CONF_PATH"

echo ""
echo "✅ Peer '${PEER_NAME}' added to ${WG_INTERFACE}."
echo "   Peer IP: ${PEER_IP}"
echo "   File: ${CONF_PATH}"
