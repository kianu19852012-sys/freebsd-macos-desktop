#!/bin/sh
# ============================================================
#  FreeBSD macOS Desktop — Master Build Script
#  Run on a FreeBSD 14 build host.
#  Produces: build/iso/freebsd-macos-desktop.iso
# ============================================================

set -e

echo "============================================"
echo "  FreeBSD macOS Desktop — Full Build"
echo "============================================"
echo ""

# Check we're on FreeBSD
if [ "$(uname)" != "FreeBSD" ]; then
  echo "ERROR: This build script must run on FreeBSD 14."
  echo "On other systems, use a FreeBSD 14 VM or jail."
  exit 1
fi

# Check FreeBSD version
FBSD_MAJ=$(uname -r | cut -d. -f1)
if [ "$FBSD_MAJ" -lt 14 ]; then
  echo "WARNING: FreeBSD 14+ recommended (you have $(uname -r))"
fi

# ---- Install build dependencies ----
echo "[1/3] Installing build tools..."
pkg install -y \
  git \
  curl \
  fetch \
  mfsbsd \
  qemu \
  grub2 \
  xorriso \
  sassc \
  gtk-engines \
  gtk-murrine-engine

# ---- Build ISO ----
echo "[2/3] Building ISO..."
sh iso/build-iso.sh

# ---- Done ----
echo "[3/3] Build complete!"
echo ""
echo "  ISO: build/iso/freebsd-macos-desktop.iso"
echo ""
echo "  Test in QEMU now:"
echo "    sh vm/run-qemu.sh"
echo ""
echo "  Write to USB for real hardware:"
echo "    dd if=build/iso/freebsd-macos-desktop.iso of=/dev/daX bs=1m"
echo "    (replace daX with your USB device)"
