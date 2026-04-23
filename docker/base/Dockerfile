ARG OS_VERSION=24.04

FROM ubuntu:${OS_VERSION}

# 1. System packages that almost NEVER change
RUN apt-get update && apt-get install -y --no-install-recommends \
    linux-firmware \
    linux-image-generic \
    initramfs-tools \
    squashfs-tools \
    kmod \
    zstd \
    && rm -rf /var/lib/apt/lists/*

RUN KERNEL_VER=$(ls /lib/modules | head -n 1) \
    && dpkg --configure -a \
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
