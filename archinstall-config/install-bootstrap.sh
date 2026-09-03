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
echo "[*] Available disks:"
lsblk -d -o NAME,SIZE,TYPE,MODEL

read -p "Enter the target disk for installation (e.g., /dev/sda or /dev/nvme0n1): " TARGET_DISK

if [ ! -b "$TARGET_DISK" ]; then
    echo "[!] Block device $TARGET_DISK not found."
    exit 1
fi

echo "[*] Updating user_configuration.json with target disk: $TARGET_DISK"
sed -i "s|\"/dev/sda\"|\"$TARGET_DISK\"|g" "${CONFIG_FILE}"

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
