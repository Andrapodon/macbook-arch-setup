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

echo "[*] Calculating exact byte size and preparing configuration..."
python -c "
import json, subprocess, sys
try:
    with open('user_configuration.json', 'r') as f:
        config = json.load(f)

    target_disk = '${TARGET_DISK}'
    total_bytes = int(subprocess.check_output(['lsblk', '-n', '-b', '-o', 'SIZE', '-d', target_disk]).strip())
    sector_size = int(subprocess.check_output(['lsblk', '-n', '-o', 'LOG-SEC', '-d', target_disk]).strip())
    
    start_bytes = 1025 * 1024 * 1024
    rem_bytes = total_bytes - start_bytes - (2 * 1024 * 1024)
    # Align down to nearest 1 MiB
    rem_bytes = (rem_bytes // (1024 * 1024)) * (1024 * 1024)

    # Inject exact byte size for root partition
    parts = config['disk_config']['device_modifications'][0]['partitions']
    parts[1]['size'] = {
        'sector_size': {'unit': 'B', 'value': sector_size},
        'unit': 'B',
        'value': rem_bytes
    }

    with open('/tmp/archinstall_config.json', 'w') as f:
        json.dump(config, f, indent=4)
except Exception as e:
    sys.exit(f'Fatal Python error generating config: {e}')
"

CREDS_FILE="user_credentials.json"
if [ ! -f "${CREDS_FILE}" ]; then
    echo "[!] ${CREDS_FILE} not found! Please create it."
    exit 1
fi

echo "[*] Ensuring archinstall is up to date..."
pacman -Sy --noconfirm archinstall

echo "[*] Launching archinstall with declarative configuration..."
if ! archinstall --silent --config "/tmp/archinstall_config.json" --creds "${CREDS_FILE}"; then
    echo "[!] archinstall failed! Please check the logs."
    exit 1
fi

echo "=========================================================================="
echo "Next step: Reboot into the installed system, connect to Wi-Fi, and run:"
echo "  git clone https://github.com/Andrapodon/macbook-arch-setup.git ~/macbook-arch-setup"
echo "  cd ~/macbook-arch-setup/ansible"
echo "  ansible-playbook -i inventory/hosts.ini playbook.yml --connection=local --ask-vault-pass"
echo "=========================================================================="
