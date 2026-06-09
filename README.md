<p align="center">
  <img src="https://raw.githubusercontent.com/kianu19852012-sys/freebsd-macos-desktop/main/docs/preview.png" width="720" alt="FreeBSD macOS Desktop">
</p>

<h1 align="center">FreeBSD macOS Desktop</h1>

<p align="center">
  A <strong>FreeBSD 14</strong> desktop environment styled to replicate <strong>macOS Sonoma</strong>.<br>
  Openbox · WhiteSur · Plank · Tint2 · Rofi · Picom · Docker ISO Builder · 4-screen Setup Assistant
</p>

<p align="center">
  <img src="https://img.shields.io/badge/FreeBSD-14.0-red?logo=freebsd" />
  <img src="https://img.shields.io/badge/Theme-WhiteSur-blue" />
  <img src="https://img.shields.io/badge/WM-Openbox-green" />
  <img src="https://img.shields.io/badge/Build-Docker-2496ED?logo=docker" />
  <img src="https://img.shields.io/badge/License-MIT-yellow" />
</p>

---

## Features

- **macOS Sonoma aesthetic** — WhiteSur GTK/icon theme, custom GRUB boot splash, SLIM login screen
- **Full desktop stack** — Openbox WM, Plank dock, Tint2 top bar, Rofi launcher, Picom compositor
- **4-screen graphical Setup Assistant** — Account creation, Timezone/Locale, Disk partitioning, Live install progress
- **Smart disk partitioning** — ZFS (recommended), UFS, Install Alongside, or Manual via `gpart`
- **VM-ready** — Auto-detects VMware, VirtualBox, QEMU/KVM and configures the correct Xorg driver
- **Hardware drivers** — Intel GPU (i915kms), Intel WiFi (iwlwifi), VMware SVGA2, VirtIO
- **Docker ISO builder** — reproducible, one-command ISO build on any Linux/macOS host

---

## Quick Start

### 1. Build the ISO

```bash
git clone https://github.com/kianu19852012-sys/freebsd-macos-desktop.git
cd freebsd-macos-desktop/docker-builder
docker compose up --build
# ISO → docker-builder/output/freebsd-macos-desktop.iso
```

### 2. Test in QEMU

```bash
chmod +x test-in-qemu.sh
./test-in-qemu.sh
# Optional flags:
#   --snapshot   discard changes on exit
#   --mem=8G     more RAM
#   --headless   serial console only
```

### 3. Boot in VMware

| Setting | Value |
|---|---|
| Guest OS | FreeBSD 14 64-bit |
| Firmware | **UEFI** |
| Disk | 40 GB+ |
| RAM | 4 GB+ |
| 3D Acceleration | ✓ Enabled |

---

## Project Structure

```
freebsd-macos-desktop/
├── base/               # rc.conf, loader.conf, sysctl.conf
├── desktop/
│   ├── openbox/        # rc.xml, menu.xml, autostart
│   ├── plank/          # dock settings
│   ├── tint2/          # top bar config
│   ├── rofi/           # macOS-style launcher theme
│   ├── picom/          # compositor config
│   ├── whitesur/       # WhiteSur theme install script
│   └── packages.txt    # full package list
├── drivers/
│   ├── intel-gpu.sh    # i915kms + DRM setup
│   └── intel-wifi.sh   # iwlwifi setup
├── firstboot/
│   ├── progress-ui.py  # 4-screen Tkinter Setup Assistant
│   ├── firstboot.sh    # entry point (called by rc.d)
│   ├── deploy-configs.sh
│   ├── apply-sysconfig.sh
│   └── detect-xorg.sh  # auto GPU/VM detection
├── grub/
│   ├── grub.cfg
│   ├── install-grub.sh
│   └── theme/          # macOS-style GRUB theme
├── docker-builder/
│   ├── Dockerfile
│   ├── docker-compose.yml
│   ├── docker-build.sh # full ISO build pipeline
│   └── test-in-qemu.sh # QEMU launcher (Mac + Linux)
└── install.sh
```

---

## Setup Assistant Screens

| # | Screen | What it does |
|---|--------|-------------|
| 1 | **Create Account** | Full name, username (auto-suggested), password with strength meter |
| 2 | **Timezone & Language** | Region → city picker, 18 locales, live clock preview |
| 3 | **Installation Disk** | Live disk scan, 4 partition schemes, visual partition bar |
| 4 | **Installing** | Live progress bar, step checklist, log strip |
| 5 | **Done** | Summary + 10-second reboot countdown |

---

## Requirements

- **Docker** 20+ (for ISO build)
- **QEMU** 7+ (for VM testing)
- 8 GB free disk space for build cache

---

## License

MIT — do whatever you want with it.
