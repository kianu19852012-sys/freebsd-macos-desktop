#!/bin/sh
# ============================================================
#  Auto-detect VM / GPU and write appropriate xorg.conf.d
#  Called by deploy-configs.sh during first boot.
# ============================================================

XCONF="/etc/X11/xorg.conf.d/10-video.conf"
mkdir -p /etc/X11/xorg.conf.d

# Detect VMware
if pciconf -lv 2>/dev/null | grep -qi "vmware\|15ad:"; then
    echo "  Detected VMware — configuring vmware driver"
    cat > "$XCONF" << 'XORGEOF'
Section "Device"
    Identifier  "VMware SVGA"
    Driver      "vmware"
    Option      "AccelMethod" "glamor"
EndSection

Section "InputDevice"
    Identifier  "VMware Mouse"
    Driver      "vmmouse"
    Option      "CorePointer" "true"
EndSection
XORGEOF

    # Enable open-vm-tools service
    sysrc vmware_guestd_enable="YES" 2>/dev/null || true
    service vmware-guestd start 2>/dev/null || true

# Detect VirtualBox
elif pciconf -lv 2>/dev/null | grep -qi "virtualbox\|innotek\|080ee:"; then
    echo "  Detected VirtualBox — configuring vboxvideo driver"
    cat > "$XCONF" << 'XORGEOF'
Section "Device"
    Identifier  "VirtualBox Video"
    Driver      "vboxvideo"
EndSection
XORGEOF
    sysrc vboxguest_enable="YES" 2>/dev/null || true
    service vboxguest start 2>/dev/null || true

# Detect QEMU/KVM (virtio / QXL)
elif pciconf -lv 2>/dev/null | grep -qi "qxl\|1b36:"; then
    echo "  Detected QEMU QXL — configuring qxl driver"
    cat > "$XCONF" << 'XORGEOF'
Section "Device"
    Identifier  "QXL"
    Driver      "qxl"
EndSection
XORGEOF

# Detect Intel (bare metal)
elif pciconf -lv 2>/dev/null | grep -qi "intel.*graphics\|8086:.*display"; then
    echo "  Detected Intel GPU — configuring modesetting driver"
    cat > "$XCONF" << 'XORGEOF'
Section "Device"
    Identifier  "Intel GPU"
    Driver      "modesetting"
    Option      "AccelMethod" "glamor"
    Option      "DRI"         "3"
EndSection
XORGEOF

# Fallback — let Xorg auto-detect
else
    echo "  No specific GPU detected — using Xorg auto-detection"
    cat > "$XCONF" << 'XORGEOF'
Section "Device"
    Identifier  "Auto"
    Driver      "modesetting"
EndSection
XORGEOF
fi

echo "  Xorg video config written to $XCONF"
