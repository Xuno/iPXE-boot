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
        initramfs-tools squashfs-tools kmod zstd wget \
        ca-certificates \
    && KERNEL_VER=$(ls /lib/modules | head -n 1) \
    && apt-get install -y --no-install-recommends \
        linux-modules-extra-${KERNEL_VER} \
    && rm -rf /var/lib/apt/lists/*


# 2. Configure initramfs for network boot
RUN sed -i 's/MODULES=dep/MODULES=most/' /etc/initramfs-tools/initramfs.conf \
    && sed -i 's/COMPRESS=.*/COMPRESS=zstd/' /etc/initramfs-tools/initramfs.conf \
    && echo "BOOT=casper" >> /etc/initramfs-tools/initramfs.conf \
    && printf "virtio\nvirtio_ring\nvirtio_pci\nvirtio_net\nnet_failover\ne1000\ne1000e\nr8169\nsfc\n" >> /etc/initramfs-tools/modules

# 3. Add initramfs network boot hook
RUN mkdir -p /etc/initramfs-tools/scripts/init-premount \
    && cat > /etc/initramfs-tools/scripts/init-premount/network-dhcp <<'EOF'
#!/bin/sh
PREREQ=""
prereqs()
{
    echo "$PREREQ"
}
case $1 in
prereqs)
    prereqs
    exit 0
    ;;
esac

. /scripts/functions

configure_networking
EOF

# 4. Make hook executable and update initramfs
RUN chmod +x /etc/initramfs-tools/scripts/init-premount/network-dhcp \
    && KERNEL_VER=$(ls /lib/modules | head -n 1) \
    && update-initramfs -c -k ${KERNEL_VER} \
    && lsinitramfs /boot/initrd.img-${KERNEL_VER} > /tmp/initrd_contents.txt \
    && grep -E "sfc|dhclient|configure_networking" /tmp/initrd_contents.txt \
    && echo "Network boot components confirmed" \
    || { echo "Missing components:"; cat /tmp/initrd_contents.txt | grep -E "ethernet|dhcp|scripts"; }



# 2. Daily tools/utilities that change rarely
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl vim htop iproute2 iputils-ping isc-dhcp-client mc git \
    && rm -rf /var/lib/apt/lists/*

# 3. Cloud-init (might need more frequent config updates)
RUN apt-get update && apt-get install -y --no-install-recommends \
    cloud-init \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
