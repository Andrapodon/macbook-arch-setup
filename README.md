# Automated, Idempotent Arch Linux Setup for MacBook Pro (Mid-2015, 15")

This repository provides an automated, reproducible, and idempotent deployment for installing Arch Linux on an Apple MacBook Pro (Retina, 15-inch, Mid 2015 — `MacBookPro11,4`).

It is designed for a **maintainer/user setup**:
* **User experience:** Polished KDE Plasma Wayland desktop styled with macOS ergonomics (WhiteSur/PearOS look), Retina scaling, and automated SeaDrive sync.
* **Maintainer operations:** Secure remote SSH access, **automatic WireGuard VPN connection whenever on WAN (outside home Wi-Fi)**, and **scheduled Btrfs snapshot backups**.

---

## 1. Filesystem Comparison: Why Btrfs?

| Feature | **Btrfs (Recommended)** | **ext4** | **f2fs** |
| :--- | :--- | :--- | :--- |
| **Instant Full Snapshots** | **Yes** (sub-second atomic snapshots) | No (requires LVM) | No |
| **Incremental Remote Backups** | **Yes** via `btrfs send / receive` | No (requires slow rsync crawl) | No |
| **System Rollbacks** | **Instant** if a rolling update fails | Difficult | Difficult |
| **Transparent Compression** | **zstd** saves 20-30% SSD space | None | Compression available, but rigid |
| **NAND / SSD Wear** | Low (`discard=async` TRIM support) | Standard TRIM | Optimized for flash, but no snapshots |

> **Recommendation:** **Btrfs with subvolumes** (`@`, `@home`, `@snapshots`, `@var_log`) is the clear winner for your requirement of regular automatic full backups without disk thrashing.

---

## 2. Architecture Overview

The setup follows a clean **two-stage separation of concerns**:

```
 ┌─────────────────────────────────────────────────────────┐
 │ Stage 1: archinstall (Run ONCE from live ISO)          │
 │ - Partitions Apple PCIe SSD with Btrfs & subvolumes     │
 │ - Installs kernel, linux-firmware, systemd-boot, base   │
 │ - Creates user 'ramona' and sudo access                 │
 └────────────────────────────┬────────────────────────────┘
                              │ Reboots into Arch
 ┌────────────────────────────▼────────────────────────────┐
 │ Stage 2: Ansible Playbook (Idempotent, repeatable)     │
 │ - Hardware: mbpfan (SMC fan curves), Iris Pro 5200 tune │
 │ - Desktop: KDE Plasma Wayland, WhiteSur macOS theme     │
 │ - Remote SSH: Hardened sshd + maintainer public key     │
 │ - VPN: Auto-connects to home WireGuard when outside     │
 │ - Storage: SeaDrive client autostart + ~/SeaDrive mount │
 │ - Backup: btrbk automated snapshots & remote sync       │
 └─────────────────────────────────────────────────────────┘
```

---

## 3. Directory Layout

```
macbook-arch-setup/
├── README.md
├── archinstall-config/
│   ├── install-bootstrap.sh            # Live ISO helper script
│   ├── user_configuration.json        # Declarative archinstall profile
│   └── user_credentials.json.example  # Password template
└── ansible/
    ├── ansible.cfg                    # Ansible settings (become, paths)
    ├── playbook.yml                   # Master playbook
    ├── inventory/
    │   ├── hosts.ini                  # Local and remote inventory
    │   └── group_vars/
    │       └── all.yml                # All configurations (VPN, keys, display)
    └── roles/
        ├── aur_support/               # Installs yay for AUR packages
        ├── macbook_hardware/          # mbpfan, audio, power-profiles, touchpad
        ├── kde_desktop/               # KDE Wayland, HiDPI scaling, KWin blur
        ├── ssh_remote/                # OpenSSH hardening, maintainer keys
        ├── wireguard_vpn/             # WireGuard + NM WAN auto-connect dispatcher
        ├── seadrive/                  # SeaDrive FUSE mount & autostart
        └── btrfs_backups/             # btrbk scheduled snapshots & send/receive
```

---

## 4. Step-by-Step Installation Guide

### Step 1: Prepare the USB Installer
1. Download the latest official [Arch Linux ISO](https://archlinux.org/download/).
2. Flash it to a USB drive:
   ```bash
   sudo dd bs=4M if=archlinux-x86_64.iso of=/dev/rdiskX status=progress oflag=sync
   ```
3. Copy this `macbook-arch-setup` directory onto a secondary USB stick (or clone your git repo once booted).

### Step 2: Boot the MacBook
1. Insert the USB drive and power on the MacBook while holding down the **Option (Alt)** key.
2. Select the **EFI Boot** icon.

### Step 3: Connect to Wi-Fi on Live ISO
```bash
iwctl
station wlan0 get-networks
station wlan0 connect "Your-WiFi-SSID"
exit
```

### Step 4: Run the Bootstrap Installer
1. Copy or plug in your `macbook-arch-setup` folder into the live environment.
2. Prepare your credentials file:
   ```bash
   cd macbook-arch-setup/archinstall-config
   cp user_credentials.json.example user_credentials.json
   nano user_credentials.json   # set passwords for root and ramona
   ```
3. Run the installer:
   ```bash
   ./install-bootstrap.sh
   ```
4. Once completed, type `reboot` and remove the USB drive.

---

## 5. Applying the Idempotent Ansible Configuration

Once rebooted into the installed system:

### Local First Run (on the laptop)
```bash
cd ~/macbook-arch-setup/ansible

# 1. Edit the configuration file with your specific settings:
nano inventory/group_vars/all.yml
# - Add your maintainer SSH public key
# - Add your home Wi-Fi SSID(s)
# - Add your WireGuard client key & endpoint

# 2. Run the playbook locally:
ansible-playbook -i inventory/hosts.ini playbook.yml --connection=local
```

### Remote Management (from your own machine)
Once the playbook has run, you can manage the MacBook remotely over SSH or WireGuard:
```bash
# In inventory/hosts.ini on your admin machine, uncomment:
# macbook-remote ansible_host=10.10.0.2 ansible_user=ramona

ansible-playbook -i inventory/hosts.ini playbook.yml
```

---

## 6. How the Key Features Work

### Automatic Home VPN on WAN (`wireguard_vpn`)
* A NetworkManager dispatcher script (`/etc/NetworkManager/dispatcher.d/99-wireguard-wan.sh`) runs whenever a network state changes.
* **At Home:** If the connection matches `home_wifi_ssids`, it automatically tears down `wg0` to avoid unnecessary encryption/routing loops.
* **On WAN:** If connected to a café, university, or mobile hotspot, it automatically brings up `wg0` within seconds.
* **Maintainer Access:** As long as the laptop is connected to any internet connection in the world, you can reach it via its static WireGuard IP (`10.10.0.2`).

### SeaDrive Integration (`seadrive`)
* Installs `seadrive-gui` from the AUR and creates `/home/ramona/SeaDrive`.
* Configures an autostart desktop entry so SeaDrive launches silently on login and mounts her cloud storage seamlessly into the Dolphin file manager.

### Thermal & GPU Performance (`macbook_hardware` & `kde_desktop`)
* **`mbpfan`**: Apple MacBooks have passive fan profiles by default that cause thermal throttling on Linux. The `mbpfan` daemon continuously balances the twin cooling fans based on the Core i7 core temperatures.
* **Compositor Optimization**: In `kwinrc`, blur radius is set to Medium (`BlurStrength=2`) so that the Intel Iris Pro 5200 renders the 2880 × 1800 Retina display at a locked 60 FPS without stutter.
* **Scaling**: Integer 200% (`ScaleFactor=2.0`) is configured for sharp, native macOS-like element proportions.

### Btrfs Automated Backups (`btrfs_backups`)
* `btrbk` takes daily local snapshots of `@` and `@home` and stores them in `/.snapshots/`.
* When connected to your home network or WireGuard VPN, `btrbk` can incrementally send (`btrfs send | btrfs receive`) the daily differences to your home server or NAS over SSH.
