#!/bin/sh
# ============================================================
#  Install GRUB2 + FreeBSD macOS theme onto a system disk
#
#  Run as root on an installed FreeBSD macOS Desktop system.
#  Or called automatically by iso/build-iso.sh during ISO build.
#
#  Usage:
#    sh install-grub.sh /dev/ada0   # for SATA drive
#    sh install-grub.sh /dev/da0    # for USB / NVMe
# ============================================================

set -e

DISK="${1:-/dev/ada0}"
GRUB_DIR="/boot/grub"
THEME_SRC="$(dirname "$0")/theme/freebsd-macos"
THEME_DEST="$GRUB_DIR/themes/freebsd-macos"
FONT_DIR="$GRUB_DIR/fonts"

echo "============================================"
echo "  Installing GRUB2 + macOS theme"
echo "  Target disk: $DISK"
echo "============================================"

# ---- Install grub2 package ----
echo "[1/5] Installing GRUB2..."
pkg install -y grub2-efi grub2 mkfont

# ---- Install theme files ----
echo "[2/5] Installing theme..."
mkdir -p "$THEME_DEST"
cp -r "$THEME_SRC/." "$THEME_DEST/"
echo "  Theme installed: $THEME_DEST"

# ---- Generate Inter fonts in GRUB .pf2 format ----
echo "[3/5] Converting Inter fonts to GRUB format..."
mkdir -p "$FONT_DIR"

FONT_TTF="/usr/local/share/fonts/Inter/Inter-Regular.ttf"
FONT_SEMI="/usr/local/share/fonts/Inter/Inter-SemiBold.ttf"

if [ -f "$FONT_TTF" ]; then
  grub-mkfont -o "$FONT_DIR/Inter-Regular-14.pf2"  -s 14 "$FONT_TTF"
  grub-mkfont -o "$FONT_DIR/Inter-Regular-12.pf2"  -s 12 "$FONT_TTF"
  echo "  Inter Regular fonts generated."
else
  echo "  WARNING: Inter-Regular.ttf not found, falling back to unifont"
  grub-mkfont -o "$FONT_DIR/Inter-Regular-14.pf2" \
    /usr/local/share/fonts/unifont/unifont.ttf 2>/dev/null || \
  cp /usr/share/grub/unicode.pf2 "$FONT_DIR/Inter-Regular-14.pf2" || true
fi

if [ -f "$FONT_SEMI" ]; then
  grub-mkfont -o "$FONT_DIR/Inter-SemiBold-14.pf2" -s 14 "$FONT_SEMI"
  echo "  Inter SemiBold font generated."
else
  cp "$FONT_DIR/Inter-Regular-14.pf2" "$FONT_DIR/Inter-SemiBold-14.pf2" 2>/dev/null || true
fi

# ---- Write grub.cfg ----
echo "[4/5] Writing GRUB config..."
cp "$(dirname "$0")/grub.cfg" "$GRUB_DIR/grub.cfg"

# ---- Install GRUB to disk (UEFI + BIOS fallback) ----
echo "[5/5] Installing GRUB to $DISK..."

# UEFI
if [ -d /sys/firmware/efi ] || ls /dev/efi* >/dev/null 2>&1; then
  echo "  Detected UEFI system — installing EFI bootloader..."
  mount -t msdosfs /dev/${DISK}p1 /mnt/efi 2>/dev/null || \
    mount -t msdosfs ${DISK}1 /mnt/efi 2>/dev/null || true
  grub-install \
    --target=x86_64-efi \
    --efi-directory=/mnt/efi \
    --bootloader-id="FreeBSD macOS Desktop" \
    --recheck \
    "$DISK"
  umount /mnt/efi 2>/dev/null || true
  echo "  UEFI bootloader installed."
fi

# BIOS fallback (MBR)
grub-install \
  --target=i386-pc \
  --recheck \
  "$DISK" 2>/dev/null || true
echo "  BIOS/MBR fallback installed."

echo ""
echo "============================================"
echo "  GRUB2 + macOS theme installed!"
echo ""
echo "  Theme: $THEME_DEST"
echo "  Config: $GRUB_DIR/grub.cfg"
echo ""
echo "  Boot menu:"
echo "    - FreeBSD macOS Desktop       (normal)"
echo "    - FreeBSD macOS Desktop       (safe mode)"
echo "    - FreeBSD macOS Desktop       (verbose)"
echo "    - UEFI Firmware Settings"
echo "============================================"
