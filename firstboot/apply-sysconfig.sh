#!/bin/sh
# ============================================================
#  Apply system configuration — called during first-boot
# ============================================================

set -e

SRC="/usr/local/src/freebsd-macos"

echo "  Applying system configuration..."

# rc.conf (avoid duplicates)
grep -qxF 'slim_enable="YES"' /etc/rc.conf 2>/dev/null || \
  cat "$SRC/base/rc.conf" >> /etc/rc.conf

# loader.conf
grep -qxF 'i915kms_load="YES"' /boot/loader.conf 2>/dev/null || \
  cat "$SRC/base/loader.conf" >> /boot/loader.conf

# sysctl.conf
grep -qxF 'vfs.usermount=1' /etc/sysctl.conf 2>/dev/null || \
  cat "$SRC/base/sysctl.conf" >> /etc/sysctl.conf

# sudoers — allow wheel group to sudo without password (macOS-style)
if ! grep -q "^%wheel" /usr/local/etc/sudoers 2>/dev/null; then
  echo "%wheel ALL=(ALL) NOPASSWD: ALL" >> /usr/local/etc/sudoers
fi

# Default shell to bash for new users
chsh -s /usr/local/bin/bash root 2>/dev/null || true

# Apply sysctl now (no reboot needed)
sysctl -f /etc/sysctl.conf 2>/dev/null || true

# Enable SLIM display manager
sysrc slim_enable="YES" 2>/dev/null || true

echo "  System configuration applied."
