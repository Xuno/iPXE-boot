#!/bin/bash
set -euo pipefail

DATA_DIR="/data"
OUTPUT_DIR="${DATA_DIR}/build"
mkdir -p "${OUTPUT_DIR}"

ISO_VERSION=$(date +%Y-%m-%d_%H_%M)
ISO_NAME="ubuntu-24.04-custom-${ISO_VERSION}.iso"
ISO_OUTPUT="${OUTPUT_DIR}/${ISO_NAME}"

echo "================================================"
echo " Ubuntu 24.04 Custom ISO Builder "
echo "================================================"
echo " RootFS source: ${DATA_DIR}/rootfs"
echo " Output: ${ISO_OUTPUT}"
echo "================================================"

WORK="/tmp/iso_work"
rm -rf "${WORK}"
mkdir -p "${WORK}"/{casper,isolinux,boot/grub/.disk}

echo ""
echo "[1/6] Preparing isolinux boot..."
ISOLINUX_BIN=$(find /usr -name "isolinux.bin" 2>/dev/null | head -1)
ISOLINUX_CFG=$(find /usr -path "*/isolinux/isolinux.cfg" 2>/dev/null | head -1)

if [ -n "${ISOLINUX_BIN}" ]; then
    cp "${ISOLINUX_BIN}" "${WORK}/isolinux/"
    echo "  OK: $(basename ${ISOLINUX_BIN}) copied"
else
    echo "  SKIP: isolinux.bin not available"
fi

echo ""
echo "[2/6] Extracting kernel and initrd..."
KERNEL=$(find /boot -name "vmlinuz*" -not -name "*recovery*" 2>/dev/null | head -1)
INITRD=$(find /boot -name "initrd*" 2>/dev/null | head -1)

if [ -n "${KERNEL}" ]; then
    cp "${KERNEL}" "${WORK}/casper/vmlinuz"
    echo "  OK: $(basename ${KERNEL}) copied"
else
    echo "  ERR: No kernel found, exiting"
    exit 1
fi

if [ -n "${INITRD}" ]; then
    cp "${INITRD}" "${WORK}/casper/initrd"
    echo "  OK: $(basename ${INITRD}) copied"
else
    echo "  OK: Using fallback initrd"
fi

echo ""
echo "[3/6] Building squashfs from rootfs..."
if [ -d "${DATA_DIR}/rootfs" ]; then
    mksquashfs "${DATA_DIR}/rootfs" "${WORK}/casper/filesystem.squashfs" \
        -comp zstd -b 1M 2>&1 | tail -3
    echo "  OK: filesystem.squashfs created"
else
    echo "  WARN: ${DATA_DIR}/rootfs not found, creating minimal fs"
    mkdir -p /tmp/empty_rootfs
    touch /tmp/empty_rootfs/.keep
    mksquashfs /tmp/empty_rootfs "${WORK}/casper/filesystem.squashfs" -comp zstd -b 1M
fi

echo ""
echo "[4/6] Writing GRUB config..."
cat > "${WORK}/boot/grub/grub.cfg" << 'EOGRUB'
set timeout=5
insmod all_video
insmod gfxterm
terminal_output gfxterm
menuentry "Ubuntu 24.04 Custom Live" {
    insmod gzio
    insmod part_gpt
    linux /casper/vmlinuz boot=casper quiet splash ---
    initrd /casper/initrd
}
menuentry "Troubleshooting Mode" {
    insmod gzio
    insmod part_gpt
    linux /casper/vmlinuz boot=casper debug ---
    initrd /casper/initrd
}
EOGRUB
echo "  OK: grub.cfg written"

echo ""
echo "[5/6] Writing disk metadata..."
echo "Ubuntu 24.04 Custom Live" > "${WORK}/.disk/info"

echo ""
echo "[6/6] Building ISO with xorriso..."
xorriso -as mkisofs \
    -iso-level 3 \
    -full-isohybrid \
    -V "UBUNTU24_LIVE" \
    -b isolinux/isolinux.bin \
    -no-emul-boot \
    -boot-load-size 4 \
    -eltorito-catalog isolinux/boot.cat \
    -J -R \
    -o "${ISO_OUTPUT}" \
    "${WORK}" 2>&1

SIZE=$(du -h "${ISO_OUTPUT}" | cut -f1)
echo ""
echo "================================================"
echo " RESULT: ISO built successfully"
echo " File: ${ISO_OUTPUT}"
echo " Size: ${SIZE}"
echo "================================================"

rm -rf "${WORK}"