#!/usr/bin/env bash
# ==============================================================================
# MacBook Pro 11,4 - Arch Linux Automated Bootstrap Script
# Run this from the official Arch Linux Live ISO environment
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

echo "=== Arch Linux Installer for MacBook Pro (Retina, 15-inch, Mid 2015) ==="

# Check internet connectivity
if ! ping -c 1 archlinux.org &>/dev/null; then
    echo "[!] No internet connection detected."
    echo "    Connect to Wi-Fi with: iwctl station wlan0 connect <SSID>"
    exit 1
fi

TARGET_DISK="/dev/sda"
echo "[*] Target disk hardcoded to: $TARGET_DISK"



CREDS_FILE="user_credentials.json"
if [ ! -f "${CREDS_FILE}" ]; then
    echo "[!] ${CREDS_FILE} not found! Please create it."
    exit 1
fi

echo "[*] Ensuring archinstall is up to date..."
pacman -Sy --noconfirm archinstall

echo "[*] Launching archinstall with declarative configuration..."
if ! archinstall --silent --config "user_configuration.json" --creds "${CREDS_FILE}"; then
    echo "[!] archinstall failed! Please check the logs."
    exit 1
fi

echo "=========================================================================="
echo "Next step: Reboot into the installed system, connect to Wi-Fi, and run:"
echo "  git clone https://github.com/Andrapodon/macbook-arch-setup.git ~/macbook-arch-setup"
echo "  cd ~/macbook-arch-setup/ansible"
echo "  ansible-playbook -i inventory/hosts.ini playbook.yml --connection=local --ask-vault-pass"
echo "=========================================================================="
