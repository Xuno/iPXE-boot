ARG OS_VERSION=24.04

FROM ubuntu:${OS_VERSION}

ENV DEBIAN_FRONTEND=noninteractive
ENV LC_ALL=C.UTF-8

# 1. Install kernel + extras in one shot, suppress postinst initrd generation
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        linux-firmware \
        linux-image-generic \
        casper \
        initramfs-tools squashfs-tools kmod zstd \
        ca-certificates \
    && KERNEL_VER=$(ls /lib/modules | head -n 1) \
    && apt-get install -y --no-install-recommends \
        linux-modules-extra-${KERNEL_VER} \
    && rm -rf /var/lib/apt/lists/*

# 2. Configure initramfs
RUN sed -i 's/MODULES=dep/MODULES=most/' /etc/initramfs-tools/initramfs.conf \
    && sed -i 's/COMPRESS=gzip/COMPRESS=zstd/' /etc/initramfs-tools/initramfs.conf \
    && printf "sfc\nvirtio_net\ne1000e\nr8169\n" >> /etc/initramfs-tools/modules \
    && KERNEL_VER=$(ls /lib/modules | head -n 1) \
    && update-initramfs -c -k ${KERNEL_VER} \
    && lsinitramfs /boot/initrd.img-${KERNEL_VER} > /tmp/initrd_contents.txt \
    && grep sfc /tmp/initrd_contents.txt \
    && echo "sfc confirmed" \
    || { echo "sfc NOT found — contents:"; cat /tmp/initrd_contents.txt | grep ethernet; exit 1; }

# 2. Daily tools/utilities that change rarely
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl vim htop iproute2 mc git \
    && rm -rf /var/lib/apt/lists/*

# 3. Cloud-init (might need more frequent config updates)
RUN apt-get update && apt-get install -y --no-install-recommends \
    cloud-init \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
