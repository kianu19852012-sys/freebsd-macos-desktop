#!/bin/sh
# ============================================================
#  Intel GPU Driver — drm-kmod (i915kms) for FreeBSD 14
#  Supports: Intel HD/UHD Graphics (2nd gen through 12th gen)
#  Iris Xe supported via iris driver in Mesa
# ============================================================

set -e

echo "  Installing Intel GPU driver (drm-kmod)..."

# drm-kmod — DRM/KMS kernel module (i915 for Intel)
pkg install -y drm-kmod

# Mesa — OpenGL/Vulkan userland for Intel
pkg install -y \
  mesa-dri \
  mesa-libs \
  mesa-gallium \
  vulkan-loader \
  mesa-vulkan-intel \
  libdrm \
  libGL \
  libEGL \
  libgbm

# Xorg Intel driver
pkg install -y xf86-video-intel

# Add i915kms to loader
if ! grep -q "i915kms_load" /boot/loader.conf 2>/dev/null; then
  echo 'i915kms_load="YES"' >> /boot/loader.conf
fi

# Add user to video group (required for GPU access)
echo "  Adding user to 'video' group..."
# pw groupmod video -m $USER  # done per-user in install.sh

# Xorg config for Intel GPU
mkdir -p /usr/local/etc/X11/xorg.conf.d
cat > /usr/local/etc/X11/xorg.conf.d/20-intel.conf << 'XORGCONF'
Section "Device"
  Identifier  "Intel Graphics"
  Driver      "intel"
  Option      "TearFree"    "true"
  Option      "DRI"         "3"
  Option      "AccelMethod" "sna"
EndSection

Section "Screen"
  Identifier "Screen0"
  Device     "Intel Graphics"
  DefaultDepth 24
  SubSection "Display"
    Depth 24
    Modes "1920x1080" "2560x1440" "3840x2160"
  EndSubSection
EndSection
XORGCONF

echo "  Intel GPU driver installed."
echo "  Supported: Intel HD 2000 through Intel Iris Xe"
echo "  Reboot required for i915kms to load."
