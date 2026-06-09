#!/bin/sh
# ============================================================
#  Test FreeBSD macOS Desktop in QEMU
#  Install: pkg install -y qemu (on FreeBSD)
#           apt install -y qemu-system-x86 (on Linux)
# ============================================================

ISO="$(dirname "$0")/../build/iso/freebsd-macos-desktop.iso"
DISK="$(dirname "$0")/../build/freebsd-macos.qcow2"
RAM="4096"
CPUS="4"

# Create virtual disk on first run
if [ ! -f "$DISK" ]; then
  echo "Creating 40GB virtual disk..."
  qemu-img create -f qcow2 "$DISK" 40G
fi

echo "============================================"
echo "  Booting FreeBSD macOS Desktop in QEMU"
echo "  RAM: ${RAM}MB  CPUs: $CPUS"
echo "  VNC: localhost:5900"
echo "============================================"

qemu-system-x86_64 \
  -name "FreeBSD macOS Desktop" \
  -machine q35,accel=kvm:tcg \
  -cpu host \
  -smp "$CPUS" \
  -m "$RAM" \
  -bios /usr/share/ovmf/OVMF.fd \
  -drive file="$DISK",if=virtio,cache=writeback,discard=unmap \
  -cdrom "$ISO" \
  -boot order=dc,menu=on \
  -device intel-hda \
  -device hda-duplex \
  -device virtio-net-pci,netdev=net0 \
  -netdev user,id=net0 \
  -device virtio-vga-gl \
  -display sdl,gl=on \
  -vnc :0 \
  -usb \
  -device usb-tablet \
  -device usb-kbd \
  -monitor stdio \
  -serial mon:stdio
