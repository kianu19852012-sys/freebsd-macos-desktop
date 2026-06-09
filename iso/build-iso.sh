#!/bin/sh
# ============================================================
#  Build bootable ISO — FreeBSD macOS-like Desktop
#
#  Method: mfsBSD (minimal FreeBSD + our layer on top)
#  https://mfsbsd.vx.sk/
#
#  Requirements (run on a FreeBSD build host):
#    pkg install -y mfsBSD git curl
#
#  Output: freebsd-macos-desktop.iso (~800MB)
# ============================================================

set -e

FREEBSD_VERSION="14.0"
FREEBSD_ARCH="amd64"
FREEBSD_MIRROR="https://download.freebsd.org/releases/${FREEBSD_ARCH}/${FREEBSD_VERSION}-RELEASE"
BUILD_DIR="$(pwd)/build/iso"
MFSBSD_DIR="$BUILD_DIR/mfsbsd"
DIST_DIR="$BUILD_DIR/dists"

echo "============================================"
echo "  Building FreeBSD macOS Desktop ISO"
echo "  FreeBSD $FREEBSD_VERSION-RELEASE $FREEBSD_ARCH"
echo "============================================"

mkdir -p "$BUILD_DIR" "$DIST_DIR"

# ---- Download FreeBSD base distributions ----
echo "[1/5] Downloading FreeBSD $FREEBSD_VERSION base sets..."
for dist in base.txz kernel.txz; do
  if [ ! -f "$DIST_DIR/$dist" ]; then
    echo "  Fetching $dist..."
    fetch -o "$DIST_DIR/$dist" "$FREEBSD_MIRROR/$dist"
  fi
done

# ---- Clone mfsBSD ----
echo "[2/5] Setting up mfsBSD..."
if [ ! -d "$MFSBSD_DIR" ]; then
  git clone --depth=1 https://github.com/mmatuska/mfsBSD.git "$MFSBSD_DIR"
fi

# ---- Create customization overlay ----
echo "[3/5] Building customization layer..."
CUSTOM_DIR="$BUILD_DIR/custom"
mkdir -p "$CUSTOM_DIR"

# Our install script runs on first boot
mkdir -p "$CUSTOM_DIR/etc/rc.d"
cat > "$CUSTOM_DIR/etc/rc.d/macos_desktop_setup" << 'RCSCRIPT'
#!/bin/sh
# PROVIDE: macos_desktop_setup
# REQUIRE: NETWORKING pkg
# BEFORE: slim

. /etc/rc.subr

name="macos_desktop_setup"
rcvar="macos_desktop_setup_enable"
start_cmd="macos_desktop_setup_start"

macos_desktop_setup_start() {
  if [ ! -f /var/db/.desktop-installed ]; then
    echo "Installing macOS-like desktop (first boot)..."
    cd /usr/local/src/freebsd-macos
    sh install.sh 2>&1 | tee /var/log/desktop-install.log
    touch /var/db/.desktop-installed
    echo "Desktop installed. Rebooting..."
    sleep 3
    reboot
  fi
}

load_rc_config $name
: ${macos_desktop_setup_enable:=YES}
run_rc_command "$1"
RCSCRIPT
chmod +x "$CUSTOM_DIR/etc/rc.d/macos_desktop_setup"

# Embed our source into the ISO
mkdir -p "$CUSTOM_DIR/usr/local/src"
cp -r "$(pwd)/../." "$CUSTOM_DIR/usr/local/src/freebsd-macos/"

# ---- Build ISO with mfsBSD ----
echo "[4/5] Building ISO (this takes 5-10 minutes)..."
cd "$MFSBSD_DIR"
make \
  BASE="$DIST_DIR" \
  CUSTOM="$CUSTOM_DIR" \
  FREECONF="$BUILD_DIR" \
  ISOFILE="$BUILD_DIR/freebsd-macos-desktop.iso" \
  iso

echo "[5/5] Done!"
echo ""
echo "============================================"
echo "  ISO ready: $BUILD_DIR/freebsd-macos-desktop.iso"
echo ""
echo "  Write to USB:"
echo "    dd if=freebsd-macos-desktop.iso of=/dev/sdX bs=4M"
echo ""
echo "  Test in QEMU:"
echo "    sh ../vm/run-qemu.sh"
echo "============================================"
