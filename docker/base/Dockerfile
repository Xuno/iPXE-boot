ARG OS_VERSION=24.04

FROM ubuntu:${OS_VERSION}

ENV DEBIAN_FRONTEND=noninteractive
ENV LC_ALL=C.UTF-8

# 1. System packages that almost NEVER change
RUN apt-get update && apt-get install -y --no-install-recommends \
    linux-firmware \
    linux-image-generic \
    casper \
    initramfs-tools  squashfs-tools kmod  zstd \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && KERNEL_VER=$(ls /lib/modules | head -n 1) \
    && update-initramfs -c -k "$KERNEL_VER"

# 2. Daily tools/utilities that change rarely
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl vim htop iproute2 mc git \
    && rm -rf /var/lib/apt/lists/*

# 3. Cloud-init (might need more frequent config updates)
RUN apt-get update && apt-get install -y --no-install-recommends \
    cloud-init \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
