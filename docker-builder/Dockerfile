# ============================================================
#  FreeBSD macOS Desktop — ISO Builder (Docker)
#  Base: Debian Bookworm (slim) + cross-build tools
#  Produces: freebsd-macos-desktop.iso (~900MB)
#
#  Usage:
#    docker build -t fbsd-iso-builder .
#    docker run --rm -v $(pwd)/output:/output fbsd-iso-builder
# ============================================================

FROM debian:bookworm-slim

LABEL description="FreeBSD macOS Desktop ISO Builder"
LABEL version="1.0"

# ---- Build tools ----
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Download tools
    curl wget ca-certificates \
    # Archive tools
    xz-utils bzip2 unzip zip \
    # ISO creation
    xorriso grub-pc-bin grub-efi-amd64-bin mtools \
    # Font tools
    fontforge python3-fontforge \
    # Image tools
    python3 python3-pip python3-pil \
    # Git (for theme cloning)
    git \
    # Misc
    cpio gawk sed grep findutils \
    && rm -rf /var/lib/apt/lists/*

# ---- Python deps ----
RUN pip3 install Pillow --break-system-packages

# ---- Set up build directory ----
WORKDIR /build

# ---- Copy our project files into the image ----
COPY . /build/freebsd-macos/

# ---- Copy the build script ----
COPY docker-build.sh /build/docker-build.sh
RUN chmod +x /build/docker-build.sh

# ---- Output volume mount point ----
VOLUME ["/output"]

ENTRYPOINT ["/build/docker-build.sh"]
