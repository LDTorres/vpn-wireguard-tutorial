#!/usr/bin/env bash
set -euo pipefail

########################################
# CONFIG
########################################

WIREGUARD_FOLDER="${WIREGUARD_FOLDER:-/opt/homebrew/etc/wireguard}"
PEERS_DIR="${PEERS_DIR:-./peers}"

########################################

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <wg-interface>"
  echo "Ex:   $0 wg0"
  exit 1
fi

WG_INTERFACE="$1"
WG_CONF_FILE="${WIREGUARD_FOLDER}/${WG_INTERFACE}.conf"

PF_ANCHOR_FILE="/etc/pf.anchors/${WG_INTERFACE}"
PF_CONF_FILE="/etc/pf.conf"

echo "🧨 Removing interface ${WG_INTERFACE}…"

########################################
# Bring down interface
########################################

echo "⏹️ Bringing down interface (wg-quick down ${WG_INTERFACE})…"
sudo wg-quick down "$WG_INTERFACE" || echo "ℹ️ Probably was not up."

########################################
# Clean up NAT for this interface
########################################
if [[ -f "$PF_ANCHOR_FILE" ]]; then
  echo "🧽 Cleaning NAT rules in ${PF_ANCHOR_FILE}…"
  sudo sh -c "> \"$PF_ANCHOR_FILE\""
  echo "🔄 Reloading pf…"
  sudo pfctl -f "$PF_CONF_FILE" || true
  sudo pfctl -e || true
else
  echo "ℹ️ Anchor ${PF_ANCHOR_FILE} does not exist, nothing to clean."
fi

if [[ -f "$WG_CONF_FILE" ]]; then
  echo "Deleting ${WG_CONF_FILE}"
  sudo rm "$WG_CONF_FILE"
else
  echo "ℹ️ ${WG_CONF_FILE} not found"
fi

echo "🧹 Removing peers from folder ${PEERS_DIR} with prefix ${WG_INTERFACE}-…"

if [[ -d "$PEERS_DIR" ]]; then
  shopt -s nullglob
  matches=("${PEERS_DIR}/${WG_INTERFACE}-"*)
  shopt -u nullglob

  if [[ ${#matches[@]} -gt 0 ]]; then
    echo "   Will be removed:"
    for m in "${matches[@]}"; do
      echo "     - $m"
    done
    rm -rf "${matches[@]}"
    echo "✅ Peers removed."
  else
    echo "ℹ️ No peers found with prefix ${WG_INTERFACE}-."
  fi
else
  echo "ℹ️ Folder ${PEERS_DIR} does not exist, nothing to delete."
fi

echo ""
echo "✅ Interface ${WG_INTERFACE} removed"
echo "Pending items: "
echo "1. rm ${PF_ANCHOR_FILE}"
echo "2. Clean ${PF_CONF_FILE} remove all ${WG_INTERFACE} related lines and save"

