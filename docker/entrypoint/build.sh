#!/bin/bash

echo "Entrypoint script for build squash fs..."

set -e # Exit immediately if any command fails
#
#apt-get install -y --no-install-recommends \
#   squashfs-tools

VERSION=$(date +%Y-%m-%d)
# Paths inside the container
BUILD_DIR="/tmp/os_build/$VERSION"
# Paths pointing to the volume mounted from your host
DEST_DIR="/docker/$VERSION"

mkdir -p "$BUILD_DIR/rootfs"

echo "Scanning /boot directory..."
ls -lR /boot

# 1. Extract Kernel/Initrd (Directly via file paths)
echo "Locating and copying kernel artifacts..."
KERNEL_FILE=$(find /boot -name "vmlinuz-*" | head -n 1)
INITRD_FILE=$(find /boot -name "initrd.img-*" -type f | head -n 1)

echo "Found KERNEL_FILE:${KERNEL_FILE}, INITRD_FILE:${INITRD_FILE}"


if [ ! -f "$KERNEL_FILE" ]; then
    echo "ERROR: Could not find vmlinuz in /boot. Check if linux-image-generic is installed."
    exit 1
fi
# 2. If it's still not there, print the files to debug
if [ ! -f "$INITRD_FILE" ]; then
    echo "Files found in /boot:"
    ls -l /boot
    exit 1
fi


cp "$KERNEL_FILE" "$BUILD_DIR/vmlinuz"
cp "$INITRD_FILE" "$BUILD_DIR/initrd.img"

# 2. Export filesystem (The corrected tar command)
echo "Exporting filesystem..."
# -c: create, -v: verbose, -f: file (using - for stdout, piped to tar -x)
# We exclude /proc, /sys, /dev, /run, /tmp because they are dynamic kernel mounts
tar -cvp --exclude='./proc' --exclude='./sys' --exclude='./dev' --exclude='./run' \
 --exclude='./tmp' --exclude='./docker' --exclude='./app'  --exclude='./.*' \
 -C / . |  tar -x -C "$BUILD_DIR/rootfs"

# 3. Squash
echo "Squashing image..."
mksquashfs "$BUILD_DIR/rootfs" "$BUILD_DIR/filesystem.squashfs" \
  -comp zstd \
  -b 1M

  #-Xcompression-level 19

# 4. Deploy (Moving to the mounted volume)
echo "Deploying to $DEST_DIR..."
mkdir -p "$DEST_DIR"
mv "$BUILD_DIR/vmlinuz" "$BUILD_DIR/initrd.img" "$BUILD_DIR/filesystem.squashfs" "$DEST_DIR/"

# 5. Cleanup
rm -rf "$BUILD_DIR"
echo "Deployment complete."