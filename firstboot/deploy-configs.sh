#!/bin/sh
# ============================================================
#  Deploy desktop config files to system skel
#  Called during first-boot installation
# ============================================================

set -e

SRC="/usr/local/src/freebsd-macos"
SKEL="/usr/share/skel"

echo "  Deploying desktop configs..."

# Openbox
mkdir -p "$SKEL/.config/openbox"
cp "$SRC/desktop/openbox/rc.xml"    "$SKEL/.config/openbox/"
cp "$SRC/desktop/openbox/autostart" "$SKEL/.config/openbox/"
cp "$SRC/desktop/openbox/menu.xml"  "$SKEL/.config/openbox/"

# Picom
mkdir -p "$SKEL/.config/picom"
cp "$SRC/desktop/picom/picom.conf"  "$SKEL/.config/picom/"

# Rofi
mkdir -p "$SKEL/.config/rofi"
cp "$SRC/desktop/rofi/macos.rasi"   "$SKEL/.config/rofi/"

# Tint2
mkdir -p "$SKEL/.config/tint2"
cp "$SRC/desktop/tint2/macos.tint2rc" "$SKEL/.config/tint2/"

# Plank
mkdir -p "$SKEL/.config/plank/dock1"
cp "$SRC/desktop/plank/settings"    "$SKEL/.config/plank/dock1/"

# Xinitrc
cp "$SRC/desktop/xinitrc" "$SKEL/.xinitrc"
chmod +x "$SKEL/.xinitrc"

# GTK
mkdir -p "$SKEL/.config/gtk-3.0"
cp "$SRC/desktop/gtk-settings.ini"  "$SKEL/.config/gtk-3.0/settings.ini"
mkdir -p "$SKEL/.config/gtk-2.0"
cat > "$SKEL/.config/gtk-2.0/gtkrc" << 'GTK2RC'
gtk-theme-name = "WhiteSur-Light"
gtk-icon-theme-name = "WhiteSur"
gtk-font-name = "Inter 11"
gtk-cursor-theme-name = "WhiteSur-cursors"
GTK2RC

# Xresources (DPI + font hints)
cat > "$SKEL/.Xresources" << 'XRES'
Xft.dpi:       96
Xft.antialias: true
Xft.hinting:   true
Xft.hintstyle: hintslight
Xft.rgba:      rgb
Xft.lcdfilter: lcddefault
XRES

# Wallpapers dir
mkdir -p "$SKEL/Pictures/Wallpapers"
if [ -f /usr/local/share/wallpapers/WhiteSur-light.jpg ]; then
  cp /usr/local/share/wallpapers/WhiteSur-light.jpg "$SKEL/Pictures/Wallpapers/"
  cp /usr/local/share/wallpapers/WhiteSur-dark.jpg  "$SKEL/Pictures/Wallpapers/" 2>/dev/null || true
fi

# Copy skel to existing users
for home in /home/*; do
  user=$(basename "$home")
  cp -rn "$SKEL/." "$home/" 2>/dev/null || true
  chown -R "$user:$user" "$home" 2>/dev/null || true
done

# Auto-detect GPU / VM and write xorg video config
sh /usr/local/src/freebsd-macos/firstboot/detect-xorg.sh

echo "  Desktop configs deployed."
