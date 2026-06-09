#!/bin/bash
# ============================================================
#  FreeBSD macOS Desktop — QEMU Test Launcher
#  Auto-detects Mac vs Linux and runs the right QEMU command.
#  Run from: freebsd-macos/docker-builder/
# ============================================================

set -euo pipefail

ISO="$(dirname "$0")/output/freebsd-macos-desktop.iso"
MEM="4G"
SMP="4"
VGA="qxl"

# ---- Colors ----
G='\033[0;32m'; Y='\033[1;33m'; R='\033[0;31m'; B='\033[0;34m'; N='\033[0m'

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║   FreeBSD macOS Desktop — QEMU Test          ║"
echo "╚══════════════════════════════════════════════╝"
echo ""

# ---- Check ISO exists ----
if [ ! -f "$ISO" ]; then
    echo -e "${R}[ERROR]${N} ISO not found at: $ISO"
    echo ""
    echo "  Build it first with:"
    echo "    cd freebsd-macos/docker-builder"
    echo "    docker compose up --build"
    echo ""
    exit 1
fi

ISO_SIZE=$(du -sh "$ISO" | cut -f1)
echo -e "${G}[  OK ]${N} Found ISO: $ISO ($ISO_SIZE)"

# ---- Check QEMU ----
if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
    echo -e "${R}[ERROR]${N} qemu-system-x86_64 not found."
    echo ""
    OS="$(uname -s)"
    if [ "$OS" = "Darwin" ]; then
        echo "  Install with:  brew install qemu"
    else
        echo "  Install with:  sudo apt install qemu-system-x86  (Debian/Ubuntu)"
        echo "              or sudo dnf install qemu-system-x86  (Fedora)"
    fi
    echo ""
    exit 1
fi

QEMU_VER=$(qemu-system-x86_64 --version | head -1)
echo -e "${G}[  OK ]${N} $QEMU_VER"

# ---- Detect OS & pick accelerator ----
OS="$(uname -s)"
ACCEL=""
DISPLAY_BACKEND=""

if [ "$OS" = "Darwin" ]; then
    echo -e "${B}[INFO]${N} Platform: macOS"
    ACCEL="-accel hvf"
    DISPLAY_BACKEND="-display cocoa"
    # QXL not always available on Mac, fallback to virtio
    VGA="virtio"
elif [ "$OS" = "Linux" ]; then
    echo -e "${B}[INFO]${N} Platform: Linux"
    if [ -e /dev/kvm ]; then
        ACCEL="-enable-kvm"
        echo -e "${G}[  OK ]${N} KVM available — using hardware acceleration"
    else
        ACCEL="-accel tcg"
        echo -e "${Y}[ WARN]${N} KVM not available — using software emulation (slower)"
        echo "         Enable KVM: sudo modprobe kvm_intel  (Intel) or kvm_amd (AMD)"
    fi
    DISPLAY_BACKEND="-display sdl"
else
    echo -e "${Y}[ WARN]${N} Unknown OS ($OS) — trying generic settings"
    ACCEL="-accel tcg"
    DISPLAY_BACKEND="-display sdl"
fi

# ---- Optional: UEFI firmware ----
UEFI_ARGS=""
OVMF_PATHS=(
    "/usr/share/OVMF/OVMF_CODE.fd"
    "/usr/share/ovmf/OVMF.fd"
    "/usr/local/share/qemu/edk2-x86_64-code.fd"
    "/opt/homebrew/share/qemu/edk2-x86_64-code.fd"
)
for path in "${OVMF_PATHS[@]}"; do
    if [ -f "$path" ]; then
        UEFI_ARGS="-drive if=pflash,format=raw,readonly=on,file=$path"
        echo -e "${G}[  OK ]${N} UEFI firmware found: $path (booting UEFI)"
        break
    fi
done
if [ -z "$UEFI_ARGS" ]; then
    echo -e "${B}[INFO]${N} No UEFI firmware found — booting legacy BIOS"
fi

# ---- Parse flags ----
EXTRA=""
for arg in "$@"; do
    case "$arg" in
        --snapshot)  EXTRA="$EXTRA -snapshot";     echo -e "${B}[INFO]${N} Snapshot mode — disk changes discarded on exit" ;;
        --debug)     EXTRA="$EXTRA -s -S";          echo -e "${B}[INFO]${N} Debug mode — GDB server on :1234, waiting for attach" ;;
        --headless)  DISPLAY_BACKEND="-display none -nographic"; echo -e "${B}[INFO]${N} Headless mode — serial console" ;;
        --mem=*)     MEM="${arg#--mem=}";            echo -e "${B}[INFO]${N} Memory: $MEM" ;;
        --smp=*)     SMP="${arg#--smp=}";            echo -e "${B}[INFO]${N} CPUs: $SMP" ;;
        --help|-h)
            echo ""
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --snapshot    Discard disk changes on exit (safe for testing)"
            echo "  --debug       Start GDB server on :1234"
            echo "  --headless    No window, serial console only"
            echo "  --mem=SIZE    RAM size (default: 4G)"
            echo "  --smp=N       CPU count (default: 4)"
            echo ""
            exit 0
            ;;
    esac
done

# ---- Build final command ----
CMD="qemu-system-x86_64 \
  -m $MEM \
  -smp $SMP \
  -cdrom $ISO \
  -boot d \
  $ACCEL \
  -cpu host \
  -vga $VGA \
  $DISPLAY_BACKEND \
  -device virtio-net-pci,netdev=net0 \
  -netdev user,id=net0 \
  -device virtio-rng-pci \
  -rtc base=utc \
  $UEFI_ARGS \
  $EXTRA"

echo ""
echo -e "${B}[CMD ]${N} $CMD"
echo ""
echo "══════════════════════════════════════════════════"
echo "  Starting FreeBSD macOS Desktop in QEMU…"
echo "  Close the QEMU window or press Ctrl+C to stop."
echo "══════════════════════════════════════════════════"
echo ""

eval $CMD
