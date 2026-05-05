FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Install all required ISO building tools
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        xorriso \
        squashfs-tools \
        cloud-init \
        cloud-utils \
        linux-image-generic \
        initramfs-tools \
        isolinux \
        wget \
        curl \
        ca-certificates \
        genisoimage && \
    rm -rf /var/lib/apt/lists/*

# Create ISO structure
RUN mkdir -p /iso/casper /iso/boot/grub /iso/isolinux /iso/.disk

# Copy build script
COPY scripts/iso/build-iso.sh /iso/

# Make script executable
RUN chmod +x /iso/build-iso.sh

# Create minimal isolinux and GRUB files
RUN echo "=> Creating isolinux bin..." && \
    dd if=/dev/zero of=/iso/isolinux.bin bs=512 count=4 && \
    chmod +x /iso/isolinux.bin && \
    echo "=> Creating boot catalog..." && \
    touch /iso/isolinux/boot.cat && \
    echo "=> Creating GRUB config..." && \
    cat > /iso/boot/grub/grub.cfg << 'EOF'
set timeout=10
menuentry "Ubuntu 24.04 Custom" {
  set gfxpayload=keep
  linux /casper/vmlinuz boot=casper quiet splash --
  initrd /casper/initrd
}
EOF

 WORKDIR /iso