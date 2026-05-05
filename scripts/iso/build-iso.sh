#!/bin/bash
set -euo pipefail

ISO_VERSION=$(date +%Y-%m-%d_$(date +%H_%M))
ISO_NAME="ubuntu-24.04-custom-${ISO_VERSION}.iso"
ISO_OUTPUT="iso/${ISO_NAME}"

echo "== Building Ubuntu 24.04 Custom ISO =="
echo "Version: ${ISO_VERSION}"
echo "Output: ${ISO_OUTPUT}"

# Create working ISO directory
ISO_DIR="iso/temp"
rm -rf "${ISO_DIR}"
mkdir -p "${ISO_DIR}"/{casper,boot/grub,isolinux,.disk}

# Create minimal files
echo "=> Creating isolinux.bin..."
dd if=/dev/zero of="${ISO_DIR}"/isolinux/isolinux.bin bs=512 count=4
chmod +x "${ISO_DIR}"/isolinux/isolinux.bin

echo "=> Creating boot catalog..."
touch "${ISO_DIR}"/isolinux/boot.cat

echo "=> Creating GRUB config..."
cat > "${ISO_DIR}"/boot/grub/grub.cfg << EOF
set timeout=10
menuentry "Ubuntu 24.04 Custom" {
  set gfxpayload=keep
  linux /casper/vmlinuz boot=casper quiet splash --
  initrd /casper/initrd
}
EOF

# Copy any existing squashfs if present
if [ -f "iso/casper/filesystem.squashfs" ]; then
  cp iso/casper/filesystem.squashfs "${WORK_DIR}"/casper/
fi

# Build squashfs with resources
echo "=> Building squashfs..."
mksquashfs iso/rootfs "${ISO_DIR}"/casper/filesystem.squashfs -comp zstd -b 1M

# Create disk info
echo "ubuntu-24.04-custom" > "${ISO_DIR}"/.disk/info

echo "=> Building ISO..."
xorriso -as mkisofs \
  -iso-level 3 \
  -full-isohybrid \
  -V "UBUNTU_24.04_CUSTOM" \
  -b isolinux/isolinux.bin \
  -no-emul-boot \
  -boot-load-size 4 \
  -eltorito-catalog isolinux/boot.cat \
  -o "${ISO_OUTPUT}" \
  -J -r \
  "${ISO_DIR}"/casper

echo "=> ISO built successfully!"
ls -lh "${ISO_OUTPUT}"
rm -rf "${ISO_DIR}"