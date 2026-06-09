#!/bin/sh
# ============================================================
#  WhiteSur GTK Theme + Icons + Cursors — FreeBSD install
# ============================================================

set -e

SHARE="/usr/local/share"
WALLPAPER_DIR="$SHARE/wallpapers"

echo "  Installing WhiteSur theme suite..."

# Dependencies
pkg install -y gtk-engines gtk-murrine-engine sassc

# ---- GTK Theme ----
cd /tmp
if [ ! -d WhiteSur-gtk-theme ]; then
  git clone --depth=1 https://github.com/vinceliuice/WhiteSur-gtk-theme.git
fi
cd WhiteSur-gtk-theme
# Install system-wide (all users get it)
./install.sh \
  --dest "$SHARE/themes" \
  -t all \
  -s 220 \
  -l \
  --normal \
  --round \
  -HD
./install.sh \
  --dest "$SHARE/themes" \
  -t all \
  -s 220 \
  -l \
  --dark \
  --round \
  -HD
cd /tmp

# ---- Icon Theme ----
if [ ! -d WhiteSur-icon-theme ]; then
  git clone --depth=1 https://github.com/vinceliuice/WhiteSur-icon-theme.git
fi
cd WhiteSur-icon-theme
./install.sh --dest "$SHARE/icons" -t standard
./install.sh --dest "$SHARE/icons" -a
cd /tmp

# ---- Cursor Theme ----
if [ ! -d WhiteSur-cursors ]; then
  git clone --depth=1 https://github.com/vinceliuice/WhiteSur-cursors.git
fi
cd WhiteSur-cursors
./install.sh --dest "$SHARE/icons"
cd /tmp

# ---- Wallpapers ----
mkdir -p "$WALLPAPER_DIR"
fetch -q -o "$WALLPAPER_DIR/WhiteSur-light.jpg" \
  "https://raw.githubusercontent.com/vinceliuice/WhiteSur-wallpapers/main/4k/WhiteSur-light.jpg" || true
fetch -q -o "$WALLPAPER_DIR/WhiteSur-dark.jpg" \
  "https://raw.githubusercontent.com/vinceliuice/WhiteSur-wallpapers/main/4k/WhiteSur-dark.jpg" || true

# ---- Inter Font ----
echo "  Installing Inter font..."
mkdir -p "$SHARE/fonts/Inter"
fetch -q -o /tmp/Inter.zip \
  "https://github.com/rsms/inter/releases/download/v4.0/Inter-4.0.zip"
cd /tmp && unzip -q -o Inter.zip -d Inter/
find /tmp/Inter/ -name "*.ttf" -exec cp {} "$SHARE/fonts/Inter/" \;
fc-cache -fv

echo "  WhiteSur theme installed."
echo "  Themes:   $SHARE/themes/WhiteSur-Light / WhiteSur-Dark"
echo "  Icons:    $SHARE/icons/WhiteSur"
echo "  Cursors:  $SHARE/icons/WhiteSur-cursors"
echo "  Fonts:    $SHARE/fonts/Inter"
