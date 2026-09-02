#!/usr/bin/env bash
# ==============================================================================
# MacBook Pro 11,4 - Arch Linux Automated Bootstrap Script
# Run this from the official Arch Linux Live ISO environment
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/user_configuration.json"
CREDS_FILE="${SCRIPT_DIR}/user_credentials.json"

echo "=== Arch Linux Installer for MacBook Pro (Retina, 15-inch, Mid 2015) ==="

# Check internet connectivity
if ! ping -c 1 archlinux.org &>/dev/null; then
    echo "[!] No internet connection detected."
    echo "    Connect to Wi-Fi with: iwctl station wlan0 connect <SSID>"
    exit 1
fi

# Detect Apple SSD
DISKS=$(lsblk -d -o NAME,SIZE,MODEL | grep -iE 'APPLE|SSD|sda' || true)
echo "[*] Available disks:"
lsblk -d -o NAME,SIZE,TYPE,MODEL

if [ ! -f "${CREDS_FILE}" ]; then
    echo "[!] ${CREDS_FILE} not found!"
    echo "    Please copy user_credentials.json.example to user_credentials.json and set your passwords."
    exit 1
fi

echo "[*] Launching archinstall with declarative configuration..."
archinstall --config "${CONFIG_FILE}" --creds "${CREDS_FILE}"

echo "=========================================================================="
echo "Installation complete!"
echo "Next step: Reboot into the installed system and run the Ansible playbook:"
echo "  cd /home/ramona/macbook-arch-setup/ansible"
echo "  ansible-playbook -i inventory/hosts.ini playbook.yml --connection=local"
echo "=========================================================================="
