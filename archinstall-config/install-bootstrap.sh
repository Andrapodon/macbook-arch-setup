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

DISK_LAYOUT_FILE="${SCRIPT_DIR}/disk_layout.json"
TMP_DISK_LAYOUT="/tmp/archinstall_disk_layout.json"
cp "${DISK_LAYOUT_FILE}" "${TMP_DISK_LAYOUT}"
sed -i "s|\"/dev/sda\"|\"$TARGET_DISK\"|g" "${TMP_DISK_LAYOUT}"

echo "[*] Updating user_configuration.json with target disk: $TARGET_DISK"
TMP_CONFIG="/tmp/archinstall_config.json"
python -c "import json, sys, subprocess
with open(sys.argv[1]) as f1, open(sys.argv[2]) as f2:
    config = json.load(f1)
    disk_config = json.load(f2)

target_disk = sys.argv[4]
try:
    total_bytes = int(subprocess.check_output(['lsblk', '-n', '-b', '-o', 'SIZE', '-d', target_disk]).strip())
    sector_size = int(subprocess.check_output(['lsblk', '-n', '-o', 'LOG-SEC', '-d', target_disk]).strip())
except Exception as e:
    sys.exit(f'Failed to get disk size: {e}')

for mod in disk_config.get('device_modifications', []):
    for part in mod.get('partitions', []):
        if part.get('size', {}).get('unit') == '%':
            if part['size']['value'] == 100:
                start_val = part['start']['value']
                start_unit = part.get('start', {}).get('unit', 'MiB')
                
                if start_unit == 'MiB':
                    start_bytes = start_val * 1024 * 1024
                elif start_unit == 'B':
                    start_bytes = start_val
                elif start_unit == 'sectors':
                    start_bytes = start_val * sector_size
                else:
                    start_bytes = start_val * 1024 * 1024
                    
                rem_bytes = total_bytes - start_bytes - (2 * 1024 * 1024)
                part['size'] = {
                    'sector_size': {'unit': 'B', 'value': sector_size},
                    'unit': 'B',
                    'value': rem_bytes
                }

config['disk_config'] = disk_config
with open(sys.argv[3], 'w') as f3:
    json.dump(config, f3, indent=4)
" "${CONFIG_FILE}" "${TMP_DISK_LAYOUT}" "${TMP_CONFIG}" "$TARGET_DISK"

if [ ! -f "${CREDS_FILE}" ]; then
    echo "[!] ${CREDS_FILE} not found!"
    echo "    Please copy user_credentials.json.example to user_credentials.json and set your passwords."
    exit 1
fi

echo "[*] Ensuring archinstall is up to date..."
pacman -Sy --noconfirm archinstall

echo "[*] Launching archinstall with declarative configuration..."
if ! archinstall --silent --config "${TMP_CONFIG}" --creds "${CREDS_FILE}"; then
    echo "[!] archinstall failed! Please check the logs."
    exit 1
fi

echo "=========================================================================="
echo "Installation complete!"
echo "Next step: Reboot into the installed system and run the Ansible playbook:"
echo "  cd /home/ramona/macbook-arch-setup/ansible"
echo "  ansible-playbook -i inventory/hosts.ini playbook.yml --connection=local"
echo "=========================================================================="
