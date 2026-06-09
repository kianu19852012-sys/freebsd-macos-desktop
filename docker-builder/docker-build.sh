#!/bin/bash
# ============================================================
#  FreeBSD macOS Desktop — Docker ISO Build Script
#  Runs inside the container. Do not run directly.
# ============================================================

set -euo pipefail

FREEBSD_VERSION="14.0"
FREEBSD_ARCH="amd64"
FREEBSD_MIRROR="https://download.freebsd.org/releases/${FREEBSD_ARCH}/${FREEBSD_VERSION}-RELEASE"
BUILD="/build"
WORK="$BUILD/work"
DIST="$BUILD/dists"
ROOTFS="$WORK/rootfs"
ISO_ROOT="$WORK/iso"
OUTPUT="/output"
ISO_NAME="freebsd-macos-desktop.iso"

# Colors
R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'; B='\033[0;34m'; N='\033[0m'

log()  { echo -e "${B}[BUILD]${N} $*"; }
ok()   { echo -e "${G}[  OK ]${N} $*"; }
warn() { echo -e "${Y}[ WARN]${N} $*"; }
die()  { echo -e "${R}[FAIL ]${N} $*"; exit 1; }

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║   FreeBSD macOS Desktop — ISO Builder        ║"
echo "║   FreeBSD ${FREEBSD_VERSION}-RELEASE ${FREEBSD_ARCH}              ║"
echo "╚══════════════════════════════════════════════╝"
echo ""

mkdir -p "$WORK" "$DIST" "$ROOTFS" "$ISO_ROOT" "$OUTPUT"

# ============================================================
# STEP 1: Download FreeBSD base + kernel
# ============================================================
log "Step 1/7 — Downloading FreeBSD ${FREEBSD_VERSION} base sets..."

for dist in base.txz kernel.txz lib32.txz; do
    if [ ! -f "$DIST/$dist" ]; then
        log "  Fetching $dist (~$([ $dist = base.txz ] && echo '170MB' || echo '$([ $dist = kernel.txz ] && echo 40MB || echo 25MB)'))..."
        curl -# -o "$DIST/$dist" "$FREEBSD_MIRROR/$dist" || \
            wget -q --show-progress -O "$DIST/$dist" "$FREEBSD_MIRROR/$dist"
        ok "  $dist downloaded"
    else
        ok "  $dist already cached"
    fi
done

# ============================================================
# STEP 2: Extract FreeBSD into rootfs
# ============================================================
log "Step 2/7 — Extracting FreeBSD base into rootfs..."
for dist in base.txz lib32.txz kernel.txz; do
    log "  Extracting $dist..."
    # Validate file size — re-download if empty/corrupt
    FSIZE=$(stat -c%s "$DIST/$dist" 2>/dev/null || echo 0)
    if [ "$FSIZE" -lt 1048576 ]; then
        warn "  $dist seems corrupt (${FSIZE} bytes) — re-downloading..."
        rm -f "$DIST/$dist"
        curl -# -o "$DIST/$dist" "$FREEBSD_MIRROR/$dist" || \
            wget -q --show-progress -O "$DIST/$dist" "$FREEBSD_MIRROR/$dist" || \
            die "Failed to download $dist"
    fi
    tar -xJf "$DIST/$dist" -C "$ROOTFS" --no-same-owner || die "Failed to extract $dist"
done
# Verify rootfs has essential dirs
[ -d "$ROOTFS/boot" ] || die "rootfs/boot missing after extraction — FreeBSD tarballs may be corrupt"
[ -d "$ROOTFS/etc"  ] || die "rootfs/etc missing after extraction"
ok "FreeBSD rootfs extracted ($(du -sh $ROOTFS | cut -f1))"

# ============================================================
# STEP 3: Copy our project into rootfs
# ============================================================
log "Step 3/7 — Injecting FreeBSD macOS Desktop files..."

# Project source
mkdir -p "$ROOTFS/usr/local/src/freebsd-macos"
cp -r "$BUILD/freebsd-macos/." "$ROOTFS/usr/local/src/freebsd-macos/"

# rc.d first-boot installer
mkdir -p "$ROOTFS/etc/rc.d"
cat > "$ROOTFS/etc/rc.d/desktop_firstboot" << 'RCEOF'
#!/bin/sh
# PROVIDE: desktop_firstboot
# REQUIRE: NETWORKING
# BEFORE: slim

. /etc/rc.subr
name="desktop_firstboot"
rcvar="desktop_firstboot_enable"
start_cmd="desktop_firstboot_run"

desktop_firstboot_run() {
    if [ ! -f /var/db/.desktop-installed ]; then
        echo "================================================================"
        echo "  First boot: Installing FreeBSD macOS Desktop..."
        echo "  This takes 5-10 minutes. The system will reboot when done."
        echo "================================================================"
        cd /usr/local/src/freebsd-macos
        sh /usr/local/src/freebsd-macos/firstboot/firstboot.sh
    fi
}

load_rc_config $name
: ${desktop_firstboot_enable:=YES}
run_rc_command "$1"
RCEOF
chmod +x "$ROOTFS/etc/rc.d/desktop_firstboot"

# Base rc.conf (minimal for boot + network)
mkdir -p "$ROOTFS/etc"
cat >> "$ROOTFS/etc/rc.conf" << 'RCCONF'
hostname="freebsd-macos"
ifconfig_em0="DHCP"
ifconfig_vtnet0="DHCP"
sshd_enable="YES"
dumpdev="AUTO"
desktop_firstboot_enable="YES"
RCCONF

# loader.conf (kernel modules for live session)
mkdir -p "$ROOTFS/boot"
cat >> "$ROOTFS/boot/loader.conf" << 'LOADERCONF'
autoboot_delay="3"
loader_logo="none"
beastie_disable="YES"
console="vidconsole"
kern.vty=vt
i915kms_load="YES"
if_iwlwifi_load="YES"
linuxkpi_load="YES"
LOADERCONF

# GRUB theme
mkdir -p "$ROOTFS/boot/grub/themes"
cp -r "$BUILD/freebsd-macos/grub/theme/." "$ROOTFS/boot/grub/themes/"
cp "$BUILD/freebsd-macos/grub/grub.cfg" "$ROOTFS/boot/grub/grub.cfg"

ok "Project files injected into rootfs"

# ============================================================
# STEP 4: Generate GRUB fonts
# ============================================================
log "Step 4/7 — Generating GRUB fonts..."

python3 << 'PYEOF'
# We don't have Inter TTF at build time in Docker,
# so we create a minimal pf2 stub — the real font gets
# generated on first boot by install-grub.sh (which runs grub-mkfont).
# For the ISO boot menu, we use GRUB's bundled unicode.pf2 as fallback.
import shutil, os

grub_font_dir = "/build/work/rootfs/boot/grub/fonts"
os.makedirs(grub_font_dir, exist_ok=True)

# Try to use grub's unicode font as fallback
candidates = [
    "/usr/share/grub/unicode.pf2",
    "/usr/lib/grub/unicode.pf2",
]
for c in candidates:
    if os.path.exists(c):
        shutil.copy(c, f"{grub_font_dir}/Inter-Regular-14.pf2")
        shutil.copy(c, f"{grub_font_dir}/Inter-SemiBold-14.pf2")
        print(f"  Copied {c} as font fallback")
        break
else:
    print("  WARNING: No grub unicode font found — menus will use default font")
PYEOF
ok "GRUB fonts ready"

# ============================================================
# STEP 5: Build ISO directory structure
# ============================================================
log "Step 5/7 — Assembling ISO filesystem..."

mkdir -p "$ISO_ROOT/boot/grub"
mkdir -p "$ISO_ROOT/boot/grub/fonts"
mkdir -p "$ISO_ROOT/boot/grub/themes"
mkdir -p "$ISO_ROOT/boot/kernel"

# Copy kernel
cp -r "$ROOTFS/boot/kernel" "$ISO_ROOT/boot/"
cp "$ROOTFS/boot/loader.conf" "$ISO_ROOT/boot/" 2>/dev/null || true
cp "$ROOTFS/boot/device.hints" "$ISO_ROOT/boot/" 2>/dev/null || true

# Copy GRUB config and theme
cp "$ROOTFS/boot/grub/grub.cfg" "$ISO_ROOT/boot/grub/"
cp -r "$ROOTFS/boot/grub/fonts/." "$ISO_ROOT/boot/grub/fonts/"
cp -r "$ROOTFS/boot/grub/themes/." "$ISO_ROOT/boot/grub/themes/"

# Pack rootfs as a compressed image that the ISO mounts
log "  Compressing rootfs (this takes a few minutes)..."
tar -cJf "$ISO_ROOT/rootfs.txz" -C "$ROOTFS" . 2>/dev/null
ok "  rootfs.txz: $(du -sh $ISO_ROOT/rootfs.txz | cut -f1)"

# Write a minimal GRUB config for the ISO (overrides the installed one)
cat > "$ISO_ROOT/boot/grub/grub.cfg" << 'GRUBISO'
set timeout=5
set default=0

insmod all_video
insmod gfxterm
insmod gfxmenu
insmod png
insmod font

set gfxmode=1920x1080,1280x800,auto
set gfxpayload=keep

terminal_output gfxterm

if [ -f /boot/grub/fonts/Inter-Regular-14.pf2 ]; then
  loadfont /boot/grub/fonts/Inter-Regular-14.pf2
fi

set theme=/boot/grub/themes/freebsd-macos/theme.txt
export theme

menuentry "FreeBSD macOS Desktop — Install" {
  insmod xzio
  echo "Loading FreeBSD kernel..."
  kfreebsd /boot/kernel/kernel
  kfreebsd_loadenv /boot/device.hints
  set kFreeBSD.vfs.root.mountfrom="cd9660:/dev/iso9660/FBSDMACOS"
  set kFreeBSD.kern.geom.label.cd9660.enable=1
  set kFreeBSD.i915kms_load=YES
  set kFreeBSD.if_iwlwifi_load=YES
  set kFreeBSD.desktop_firstboot_enable=YES
}

menuentry "FreeBSD macOS Desktop — Verbose Boot" {
  insmod xzio
  kfreebsd /boot/kernel/kernel
  kfreebsd_loadenv /boot/device.hints
  set kFreeBSD.vfs.root.mountfrom="cd9660:/dev/iso9660/FBSDMACOS"
  set kFreeBSD.boot_verbose=YES
}

menuentry "UEFI Firmware Settings" {
  fwsetup
}
GRUBISO

ok "ISO filesystem assembled"

# ============================================================
# STEP 6: Build the ISO with xorriso + GRUB EFI + BIOS
# ============================================================
log "Step 6/7 — Building bootable ISO..."

# Generate EFI image
mkdir -p "$WORK/efi/EFI/BOOT"
grub-mkimage \
    --format=x86_64-efi \
    --output="$WORK/efi/EFI/BOOT/BOOTX64.EFI" \
    --prefix=/boot/grub \
    all_video boot btrfs cat chain configfile echo \
    efifwsetup efinet ext2 fat font gfxmenu gfxterm \
    gzio halt hfsplus iso9660 jpeg linux loadenv \
    loopback ls lsefi lsefimmap lsefisystab lssal \
    memdisk minicmd normal part_apple part_gpt part_msdos \
    password_pbkdf2 png reboot search search_fs_file \
    search_fs_uuid search_label sleep test true zfs \
    xzio kfreebsd

# Create EFI FAT image
dd if=/dev/zero of="$WORK/efi.img" bs=1M count=4 2>/dev/null
mkfs.fat -F 12 -n "GRUB_EFI" "$WORK/efi.img"
mmd -i "$WORK/efi.img" ::/EFI ::/EFI/BOOT
mcopy -i "$WORK/efi.img" "$WORK/efi/EFI/BOOT/BOOTX64.EFI" ::/EFI/BOOT/

# Generate BIOS core image
grub-mkimage \
    --format=i386-pc \
    --output="$WORK/core.img" \
    --prefix=/boot/grub \
    biosdisk iso9660 normal search xzio kfreebsd \
    all_video gfxterm gfxmenu png jpeg font

cat /usr/lib/grub/i386-pc/cdboot.img "$WORK/core.img" > "$WORK/boot.img"

# Build the final ISO
xorriso -as mkisofs \
    -iso-level 3 \
    -full-iso9660-filenames \
    -volid "FBSDMACOS" \
    -appid "FreeBSD macOS Desktop" \
    -publisher "FreeBSD macOS Desktop Project" \
    -preparer "Docker ISO Builder" \
    -b boot.img \
    -no-emul-boot \
    -boot-load-size 4 \
    -boot-info-table \
    --grub2-boot-info \
    --grub2-mbr /usr/lib/grub/i386-pc/boot_hybrid.img \
    -eltorito-alt-boot \
    -e efi.img \
    -no-emul-boot \
    --efi-boot-part \
    --efi-boot-image \
    --protective-msdos-label \
    -o "$OUTPUT/$ISO_NAME" \
    "$ISO_ROOT" \
    "$WORK/boot.img" \
    "$WORK/efi.img" \
    2>&1 | tail -5

ok "ISO built: $OUTPUT/$ISO_NAME"

# ============================================================
# STEP 7: Verify + summary
# ============================================================
log "Step 7/7 — Verifying ISO..."

ISO_SIZE=$(du -sh "$OUTPUT/$ISO_NAME" | cut -f1)
ISO_SHA=$(sha256sum "$OUTPUT/$ISO_NAME" | cut -d' ' -f1)

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║   BUILD COMPLETE                                             ║"
echo "╠══════════════════════════════════════════════════════════════╣"
printf "║   ISO:  %-53s║\n" "$ISO_NAME"
printf "║   Size: %-53s║\n" "$ISO_SIZE"
printf "║   SHA256: %-51s║\n" "${ISO_SHA:0:51}"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║   Flash to USB (Linux/Mac):                                  ║"
echo "║     dd if=freebsd-macos-desktop.iso of=/dev/sdX bs=4M        ║"
echo "║     (Mac: /dev/rdiskX)                                       ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║   Test in QEMU:                                              ║"
echo "║     qemu-system-x86_64 -m 4G -cdrom freebsd-macos-...iso    ║"
echo "║     -boot d -enable-kvm -cpu host -smp 4                    ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
