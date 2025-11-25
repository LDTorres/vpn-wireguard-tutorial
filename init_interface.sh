#!/usr/bin/env bash
set -euo pipefail

########################################
# CONFIG (macOS)
########################################

WIREGUARD_FOLDER="${WIREGUARD_FOLDER:-/opt/homebrew/etc/wireguard}"
KEYS_DIR="${KEYS_DIR:-./keys}"
VPN_BASE="10.0"                           # wg0 -> 10.0.0.x, wg1 -> 10.0.1.x, etc.
NAT_INTERFACE="${NAT_INTERFACE:-en0}"     # Normal WiFi on most Macs

########################################

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <wg-interface> <wg-port>"
  echo "Ex:   $0 wg0 48000"
  exit 1
fi

WG_INTERFACE="$1"
LISTEN_PORT="$2"
WG_CONF_FILE="${WIREGUARD_FOLDER}/${WG_INTERFACE}.conf"

echo "Initializing interface ${WG_INTERFACE}…"

########################################
# Verify wg / wg-quick
########################################

if ! command -v wg >/dev/null 2>&1; then
  echo "ERROR: 'wg' is not installed. On macOS:"
  echo "  brew install tools"
  exit 1
fi

if ! command -v wg-quick >/dev/null 2>&1; then
  echo "ERROR: 'wg-quick' is not installed. On macOS:"
  echo "  brew install tools"
  exit 1
fi

########################################
# Folders
########################################

echo "Ensuring config folder: $WIREGUARD_FOLDER"
sudo mkdir -p "$WIREGUARD_FOLDER"
sudo chmod 700 "$WIREGUARD_FOLDER"

echo "Ensuring keys folder: $KEYS_DIR"
mkdir -p "$KEYS_DIR"
chmod 700 "$KEYS_DIR"

########################################
# Server keys (in ./keys)
########################################

SERVER_PRIV_KEY_FILE="${KEYS_DIR}/server_private.key"
SERVER_PUB_KEY_FILE="${KEYS_DIR}/server_public.key"

if [[ ! -f "$SERVER_PRIV_KEY_FILE" || ! -f "$SERVER_PUB_KEY_FILE" ]]; then
  echo "Generating server keys in $KEYS_DIR…"
  umask 077
  wg genkey | tee "$SERVER_PRIV_KEY_FILE" | wg pubkey > "$SERVER_PUB_KEY_FILE"
  chmod 600 "$SERVER_PRIV_KEY_FILE" "$SERVER_PUB_KEY_FILE"
else
  echo "Server keys already exist in $KEYS_DIR, not regenerating."
fi

SERVER_PRIV_KEY="$(cat "$SERVER_PRIV_KEY_FILE")"
SERVER_PUB_KEY="$(cat "$SERVER_PUB_KEY_FILE")"

########################################
# Calculate subnet based on wgX
########################################

INTERFACE_NUM="$(echo "$WG_INTERFACE" | grep -o '[0-9]\+' || echo 0)"
SERVER_VPN_IP="${VPN_BASE}.${INTERFACE_NUM}.1"
VPN_SUBNET="${VPN_BASE}.${INTERFACE_NUM}.0/24"

echo "Network config:"
echo "  VPN server IP: $SERVER_VPN_IP"
echo "  VPN subnet:    $VPN_SUBNET"
echo "  Port:          $LISTEN_PORT"

########################################
# Create wgX.conf if it doesn't exist
########################################

if [[ -f "$WG_CONF_FILE" ]]; then
  echo "WARNING: ${WG_CONF_FILE} already exists. Not overwriting."
else
  echo "Creating ${WG_CONF_FILE}…"
  sudo tee "$WG_CONF_FILE" >/dev/null <<EOF
[Interface]
PrivateKey = $SERVER_PRIV_KEY
Address = ${SERVER_VPN_IP}/24
ListenPort = $LISTEN_PORT

PostUp   = sysctl -w net.inet.ip.forwarding=1
PostDown = sysctl -w net.inet.ip.forwarding=0
EOF

  sudo chmod 600 "$WG_CONF_FILE"
fi

########################################
# NAT with pf (macOS)
########################################

PF_ANCHOR_FILE="/etc/pf.anchors/${WG_INTERFACE}"
PF_CONF_FILE="/etc/pf.conf"

echo "Configuring NAT in ${PF_ANCHOR_FILE}…"
sudo tee "$PF_ANCHOR_FILE" >/dev/null <<EOF
nat on $NAT_INTERFACE from $VPN_SUBNET to any -> ($NAT_INTERFACE)
EOF
sudo chmod 600 "$PF_ANCHOR_FILE"

if ! grep -q "${WG_INTERFACE}" "$PF_CONF_FILE"; then
  echo "Adding anchor to pf.conf…"
  sudo tee -a "$PF_CONF_FILE" >/dev/null <<EOF

# WireGuard ${WG_INTERFACE}
anchor "${WG_INTERFACE}"
load anchor "${WG_INTERFACE}" from "$PF_ANCHOR_FILE"
EOF
fi

echo "Reloading pf…"
sudo pfctl -f "$PF_CONF_FILE" || true
sudo pfctl -e || true

echo
echo "Interface ${WG_INTERFACE} initialized successfully."
echo "Bring up with: sudo wg-quick up ${WG_INTERFACE}"
echo "Server public key: $SERVER_PUB_KEY"
