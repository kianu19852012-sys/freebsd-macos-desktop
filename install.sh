#!/bin/sh
# ============================================================
#  FreeBSD 14 macOS-like Desktop — Install Script
#  Run this ON an existing FreeBSD 14 installation as root.
#  For a fresh ISO build, use iso/build-iso.sh instead.
# ============================================================

set -e

echo "============================================"
echo "  FreeBSD macOS-like Desktop Installer"
echo "  Base: FreeBSD 14.0-RELEASE"
echo "============================================"

# Must be root
if [ "$(id -u)" -ne 0 ]; then
  echo "Run as root: sudo sh install.sh"
  exit 1
fi

# ============================================================
# STEP 1: Bootstrap pkg
# ============================================================
echo ""
echo "[1/8] Bootstrapping pkg..."
env ASSUME_ALWAYS_YES=YES pkg bootstrap
pkg update -f

# ============================================================
# STEP 2: Intel GPU (drm-kmod)
# ============================================================
echo "[2/8] Installing Intel GPU driver..."
sh drivers/intel-gpu.sh

# ============================================================
# STEP 3: Intel WiFi (iwlwifi)
# ============================================================
echo "[3/8] Installing Intel WiFi driver..."
sh drivers/intel-wifi.sh

# ============================================================
# STEP 4: Install all desktop packages
# ============================================================
echo "[4/8] Installing desktop packages..."
pkg install -y $(grep -v '^#' desktop/packages.txt | tr '\n' ' ')

# ============================================================
# STEP 5: Install WhiteSur theme
# ============================================================
echo "[5/8] Installing WhiteSur theme..."
sh desktop/whitesur/install.sh

# ============================================================
# STEP 6: Deploy all desktop configs
# ============================================================
echo "[6/8] Deploying desktop configs..."

# Openbox
mkdir -p /usr/share/skel/.config/openbox
cp desktop/openbox/rc.xml        /usr/share/skel/.config/openbox/
cp desktop/openbox/autostart     /usr/share/skel/.config/openbox/
cp desktop/openbox/menu.xml      /usr/share/skel/.config/openbox/

# Picom
mkdir -p /usr/share/skel/.config/picom
cp desktop/picom/picom.conf      /usr/share/skel/.config/picom/

# Rofi
mkdir -p /usr/share/skel/.config/rofi
cp desktop/rofi/macos.rasi       /usr/share/skel/.config/rofi/

# Tint2
mkdir -p /usr/share/skel/.config/tint2
cp desktop/tint2/macos.tint2rc   /usr/share/skel/.config/tint2/

# Plank
mkdir -p /usr/share/skel/.config/plank/dock1
cp desktop/plank/settings        /usr/share/skel/.config/plank/dock1/

# xinitrc
cp desktop/xinitrc               /usr/share/skel/.xinitrc
chmod +x /usr/share/skel/.xinitrc

# GTK
mkdir -p /usr/share/skel/.config/gtk-3.0
cp desktop/gtk-settings.ini      /usr/share/skel/.config/gtk-3.0/settings.ini

# ============================================================
# STEP 7: System config
# ============================================================
echo "[7/8] Applying system config..."

# rc.conf — services
cat base/rc.conf >> /etc/rc.conf

# loader.conf — kernel modules at boot
cat base/loader.conf >> /boot/loader.conf

# sysctl.conf — kernel tweaks
cat base/sysctl.conf >> /etc/sysctl.conf

# Display manager: SLIM (lightest, macOS login vibe)
pkg install -y slim slim-themes
cp desktop/slim.conf /usr/local/etc/slim.conf
sysrc slim_enable="YES"

# Fonts: Inter
pkg install -y fonts-inter 2>/dev/null || \
  fetch -o /tmp/Inter.zip \
    https://github.com/rsms/inter/releases/download/v4.0/Inter-4.0.zip && \
  unzip -o /tmp/Inter.zip -d /tmp/Inter/ && \
  find /tmp/Inter/ -name "*.ttf" -exec cp {} /usr/local/share/fonts/Inter/ \; || true
fc-cache -fv

# ============================================================
# STEP 8: Install GRUB2 + macOS boot theme
# ============================================================
echo "[8/8] Installing GRUB2 boot loader + macOS theme..."

# Detect boot disk automatically
DISK=$(df / | tail -1 | awk '{print $1}' | sed 's/[0-9]*$//' | sed 's/p[0-9]*$//')
echo "  Detected boot disk: $DISK"

sh grub/install-grub.sh "$DISK"

echo ""
echo "============================================"
echo "  Installation complete!"
echo ""
echo "  Reboot to start your FreeBSD macOS Desktop."
echo "  You'll see the macOS-style GRUB boot menu"
echo "  before the desktop loads."
echo ""
echo "  Login → SLIM display manager"
echo "  Desktop → Openbox + WhiteSur + Plank"
echo "============================================"
