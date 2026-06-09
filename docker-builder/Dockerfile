# ============================================================
#  FreeBSD macOS Desktop — ISO Builder (Docker)
#  Base: Debian Bookworm (slim) + cross-build tools
#  Produces: freebsd-macos-desktop.iso (~900MB)
#
#  MUST be built from the PROJECT ROOT (freebsd-macos/):
#    cd freebsd-macos
#    docker build -f docker-builder/Dockerfile -t fbsd-iso-builder .
#    docker run --rm -v $(pwd)/docker-builder/output:/output fbsd-iso-builder
#
#  Or just use docker-compose from docker-builder/:
#    cd docker-builder && docker compose up --build
# ============================================================

FROM debian:bookworm-slim

LABEL description="FreeBSD macOS Desktop ISO Builder"
LABEL version="1.2"

ARG FREEBSD_VERSION=14.3
ENV FREEBSD_VERSION=${FREEBSD_VERSION}

# ---- Build tools ----
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl wget ca-certificates \
    xz-utils bzip2 unzip zip \
    xorriso grub-pc-bin grub-efi-amd64-bin \
    mtools dosfstools \
    fontforge python3-fontforge \
    python3 python3-pip python3-pil \
    git \
    cpio gawk sed grep findutils \
    coreutils util-linux \
    && rm -rf /var/lib/apt/lists/*

# ---- Python deps ----
RUN pip3 install Pillow --break-system-packages

WORKDIR /build

# ---- Copy entire project into /build/freebsd-macos ----
# Build context = freebsd-macos/ (project root)
COPY . /build/freebsd-macos/

# ---- Hoist the build script to /build ----
RUN cp /build/freebsd-macos/docker-builder/docker-build.sh /build/docker-build.sh && \
    chmod +x /build/docker-build.sh

# ---- Output volume ----
VOLUME ["/output"]

ENTRYPOINT ["/build/docker-build.sh"]
