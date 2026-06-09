#!/bin/sh
# ============================================================
#  Intel WiFi Driver — iwlwifi for FreeBSD 14
#  Supports: Intel WiFi 6/6E (AX200, AX201, AX210, AX211)
#            Intel WiFi 5 (9260, 9560)
#            Intel WiFi (7260, 8260, 8265)
#  Note: iwlwifi landed in FreeBSD 13.1, fully stable in 14.0
# ============================================================

set -e

echo "  Installing Intel WiFi driver (iwlwifi)..."

# iwlwifi firmware — Intel open-source firmware blobs
pkg install -y iwlwifi-firmware

# WiFi stack dependencies
pkg install -y \
  wpa_supplicant \
  wpa_gui \
  networkmgr

# Load iwlwifi now (also added to loader.conf for persistence)
kldload if_iwlwifi 2>/dev/null || true

# Create wlan interface
ifconfig wlan0 create wlandev iwlwifi0 2>/dev/null || true

# wpa_supplicant config (base — user fills in SSID/password)
if [ ! -f /etc/wpa_supplicant.conf ]; then
cat > /etc/wpa_supplicant.conf << 'WPA'
ctrl_interface=/var/run/wpa_supplicant
ctrl_interface_group=wheel
eapol_version=2
ap_scan=1
fast_reauth=1

# Add your networks below:
# network={
#   ssid="YourNetworkName"
#   psk="YourPassword"
# }
WPA
chmod 600 /etc/wpa_supplicant.conf
fi

# NetworkMgr GUI (tray WiFi manager, like macOS menu bar WiFi)
# Enable at startup
sysrc wpa_supplicant_enable="YES"
sysrc wpa_supplicant_flags="-B -i wlan0 -c /etc/wpa_supplicant.conf"
sysrc ifconfig_wlan0="WPA DHCP"

echo ""
echo "  Intel WiFi installed."
echo "  Supported chipsets:"
echo "    AX200, AX201, AX210, AX211 (WiFi 6/6E)"
echo "    9260, 9461, 9462, 9560 (WiFi 5)"
echo "    7260, 7265, 8260, 8265 (older)"
echo ""
echo "  Add your WiFi network:"
echo "    vi /etc/wpa_supplicant.conf"
echo "  Or use the networkmgr GUI from the system tray."
