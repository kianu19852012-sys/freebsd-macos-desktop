# FreeBSD macOS Desktop — Docker ISO Builder

Build a bootable FreeBSD 14 ISO with the macOS-style desktop
using Docker on any Linux or macOS machine. No FreeBSD install needed.

## Requirements

- Docker Desktop (Mac) or Docker Engine (Linux)
- ~5GB free disk space (FreeBSD base + ISO)
- ~10-20 minutes (mostly downloading FreeBSD)

## Build the ISO

### Option 1 — Docker Compose (easiest)

```bash
cd freebsd-macos/docker-builder
mkdir -p output
docker compose up --build
```

ISO appears in `docker-builder/output/freebsd-macos-desktop.iso`

---

### Option 2 — Docker directly

```bash
cd freebsd-macos

# Build the builder image
docker build -f docker-builder/Dockerfile -t fbsd-iso-builder .

# Run the build (ISO goes to ./output/)
mkdir -p output
docker run --rm --privileged \
  -v $(pwd)/output:/output \
  -v fbsd-dist-cache:/build/dists \
  fbsd-iso-builder
```

---

## Flash to USB

**Linux:**
```bash
# Find your USB drive first
lsblk

# Flash (replace sdX with your drive — e.g. sdb, NOT sdb1)
sudo dd if=output/freebsd-macos-desktop.iso of=/dev/sdX bs=4M status=progress
sudo sync
```

**macOS:**
```bash
# Find your USB drive
diskutil list

# Unmount it (replace diskX with your disk — e.g. disk2)
diskutil unmountDisk /dev/diskX

# Flash (rdiskX is faster than diskX on Mac)
sudo dd if=output/freebsd-macos-desktop.iso of=/dev/rdiskX bs=4m
```

---

## Test in QEMU (without real hardware)

**Linux:**
```bash
qemu-system-x86_64 \
  -m 4096 \
  -smp 4 \
  -cdrom output/freebsd-macos-desktop.iso \
  -boot d \
  -enable-kvm \
  -cpu host \
  -vga qxl \
  -display sdl
```

**macOS (no KVM, use HVF):**
```bash
qemu-system-x86_64 \
  -m 4096 \
  -smp 4 \
  -cdrom output/freebsd-macos-desktop.iso \
  -boot d \
  -accel hvf \
  -cpu host \
  -vga qxl \
  -display cocoa
```

---

## What happens on first boot

1. GRUB loads → shows macOS-style boot menu (5s timeout)
2. FreeBSD kernel boots
3. First-boot installer runs automatically:
   - Installs all packages (needs internet)
   - Installs Intel GPU + WiFi drivers
   - Installs WhiteSur theme
   - Installs GRUB theme to disk
4. System reboots
5. SLIM login screen → Openbox + WhiteSur desktop

**First boot needs internet** to download packages (~800MB).
Subsequent boots are fast — everything is on disk.

---

## Re-running the build

FreeBSD base files are cached in a Docker volume (`fbsd-dist-cache`).
Re-runs skip the download step and complete in ~3 minutes.

To clear the cache:
```bash
docker volume rm fbsd-dist-cache
```

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `privileged: true` error | Run Docker with `--privileged` flag |
| Slow download | FreeBSD mirror may be busy — try again or change mirror in `docker-build.sh` |
| QEMU black screen | Add `-display gtk` or `-display sdl` |
| Boot loops | Normal on first boot — it's installing packages |
| WiFi not detected | Run `dmesg | grep iwlwifi` — may need newer firmware |
