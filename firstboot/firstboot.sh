#!/bin/sh
# ============================================================
#  First Boot Launcher
#  Called by /etc/rc.d/desktop_firstboot on first boot.
#  Starts X11 and launches the graphical progress UI.
#  Falls back to terminal output if X11 fails.
# ============================================================

set -e

LOG="/var/log/desktop-install.log"
LOCKFILE="/var/db/.desktop-installed"
UI_SCRIPT="/usr/local/src/freebsd-macos/firstboot/progress-ui.py"

# Already installed?
[ -f "$LOCKFILE" ] && exit 0

echo "=======================================" | tee -a "$LOG"
echo "  FreeBSD macOS Desktop First Boot" | tee -a "$LOG"
echo "  $(date)" | tee -a "$LOG"
echo "=======================================" | tee -a "$LOG"

# Install python3-tkinter if missing (needed for UI)
pkg info py311-tkinter >/dev/null 2>&1 || \
  pkg install -y py311-tkinter 2>>"$LOG" || true

# Try graphical UI first
if command -v python3 >/dev/null 2>&1 && command -v Xorg >/dev/null 2>&1; then
  echo "  Starting graphical setup UI..." | tee -a "$LOG"

  # Start a minimal X session just for the setup UI
  # Use :1 so we don't conflict with anything
  DISPLAY=:1
  export DISPLAY

  Xorg :1 -quiet -nolisten tcp &
  XPID=$!
  sleep 3  # Give X time to start

  if kill -0 $XPID 2>/dev/null; then
    echo "  X11 started (display :1)" | tee -a "$LOG"
    python3 "$UI_SCRIPT" 2>>"$LOG"
    kill $XPID 2>/dev/null || true
  else
    echo "  X11 failed — falling back to terminal install" | tee -a "$LOG"
    _run_terminal_install
  fi
else
  echo "  Graphical UI unavailable — running terminal install" | tee -a "$LOG"
  _run_terminal_install
fi

touch "$LOCKFILE"
echo "  Installation complete. Rebooting..." | tee -a "$LOG"
sleep 3
reboot

# ---- Terminal fallback ----
_run_terminal_install() {
  echo ""
  echo "================================================================"
  echo "  FreeBSD macOS Desktop — Installing (terminal mode)"
  echo "  Log: $LOG"
  echo "================================================================"
  echo ""

  STEPS=8
  STEP=0

  _step() {
    STEP=$((STEP + 1))
    PCT=$(( STEP * 100 / STEPS ))
    FILLED=$(( PCT * 40 / 100 ))
    BAR=$(printf '%0.s█' $(seq 1 $FILLED))
    EMPTY=$(printf '%0.s░' $(seq 1 $((40 - FILLED))))
    printf "\r  [%s%s] %3d%%  %s" "$BAR" "$EMPTY" "$PCT" "$1"
    echo ""
    eval "$2" 2>>"$LOG" || echo "  WARNING: step exited non-zero"
  }

  _step "Bootstrapping pkg"          "pkg bootstrap -y"
  _step "Updating package index"     "pkg update -f"
  _step "Installing GPU driver"      "sh /usr/local/src/freebsd-macos/drivers/intel-gpu.sh"
  _step "Installing WiFi driver"     "sh /usr/local/src/freebsd-macos/drivers/intel-wifi.sh"
  _step "Installing desktop packages" "pkg install -y \$(grep -v '^#' /usr/local/src/freebsd-macos/desktop/packages.txt | tr '\n' ' ')"
  _step "Installing WhiteSur theme"  "sh /usr/local/src/freebsd-macos/desktop/whitesur/install.sh"
  _step "Deploying desktop configs"  "sh /usr/local/src/freebsd-macos/firstboot/deploy-configs.sh"
  _step "Applying system settings"   "sh /usr/local/src/freebsd-macos/firstboot/apply-sysconfig.sh"

  echo ""
  echo "  ✓ Installation complete!"
  echo ""
}
