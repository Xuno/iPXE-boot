#!/bin/bash
set -euo pipefail

VERSION=$(date +%Y-%m-%d_%H%M%S)
BUILD_DIR="/tmp/os_build/$VERSION"
DEST_ROOT="/docker"
DEST_DIR="$DEST_ROOT/$VERSION"

mkdir -p "$BUILD_DIR" "$DEST_DIR"

KERNEL_FILE=$(find /boot -name "vmlinuz-*" | head -n 1)
INITRD_FILE=$(find /boot -name "initrd.img-*" -type f | head -n 1)
[ -f "$KERNEL_FILE" ] && [ -f "$INITRD_FILE" ] || { echo "Missing kernel/initrd"; exit 1; }

cp "$KERNEL_FILE" "$BUILD_DIR/vmlinuz"
cp "$INITRD_FILE" "$BUILD_DIR/initrd.img"

mksquashfs / "$BUILD_DIR/filesystem.squashfs" \
  -comp zstd -b 1M -noappend -no-recovery -wildcards \
  -e "proc/*" "sys/*" "dev/*" "run/*" "tmp/*" \
     "docker/*" "app/*" "var/cache/apt/*" "var/lib/apt/lists/*"

( cd "$BUILD_DIR" && sha256sum vmlinuz initrd.img filesystem.squashfs > SHA256SUMS )

mv "$BUILD_DIR"/* "$DEST_DIR/"
rm -rf "$BUILD_DIR"

# Atomic "current" pointer for rollback
ln -sfn "$VERSION" "$DEST_ROOT/.current.new"
mv -Tf "$DEST_ROOT/.current.new" "$DEST_ROOT/current"

echo "---"
lsinitramfs /boot/initrd.img-* | grep -E "casper|scripts/casper" | head
echo "---"
lsinitramfs /boot/initrd.img-* | grep -iE "microcode|e1000|virtio_net|r8169|sfc" | head

echo "Deployed $VERSION → current"