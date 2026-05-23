#!/bin/bash
set -euo pipefail

UBUNTU_ISO_URL="${UBUNTU_ISO_URL:-https://releases.ubuntu.com/24.04/ubuntu-24.04.4-live-server-amd64.iso}"
VERIFY_UBUNTU_ISO="${VERIFY_UBUNTU_ISO:-1}"
CUSTOM_ISO_NAME="${CUSTOM_ISO_NAME:-ubuntu-24.04-custom.iso}"
OUT_DIR="${OUT_DIR:-/out}"

WORK="${WORK:-/tmp/iso-work}"
LIVE_SQUASHFS_PATH="${LIVE_SQUASHFS_PATH:-/casper/ubuntu-server-minimal.squashfs}"

RUST_VERSION="${RUST_VERSION:-1.94.1}"
RUST_ARCH="${RUST_ARCH:-x86_64-unknown-linux-gnu}"
RUST_DIST_BASE="${RUST_DIST_BASE:-https://static.rust-lang.org/dist}"
RUST_KEY_URL="${RUST_KEY_URL:-https://keybase.io/rust/pgp_keys.asc}"
RUST_SIGNING_FPR="${RUST_SIGNING_FPR:-108F66205EAEB0AAA8DD5E1C85AB96E6FA1BE5FE}"

UBUNTU_ISO_FILE="${UBUNTU_ISO_URL##*/}"
BASE_ISO="${OUT_DIR}/${UBUNTU_ISO_FILE}"
ROOTFS="${WORK}/rootfs"
NEW_SQUASHFS="${WORK}/filesystem.squashfs"
FILESYSTEM_SIZE="${WORK}/filesystem.size"
FILESYSTEM_MANIFEST="${WORK}/filesystem.manifest"
KERNEL_OUT="${WORK}/vmlinuz"
INITRD_OUT="${WORK}/initrd"
TMP_ISO="${WORK}/${CUSTOM_ISO_NAME}.tmp"
FINAL_ISO="${OUT_DIR}/${CUSTOM_ISO_NAME}"

log() {
    printf '\n[%s] %s\n' "$(date +%H:%M:%S)" "$*"
}

require_file() {
    local path="$1"
    local description="$2"
    if [ ! -s "$path" ]; then
        echo "Missing ${description}: ${path}" >&2
        exit 1
    fi
}

rm -rf "${WORK}"
mkdir -p "${WORK}" "${OUT_DIR}" "${OUT_DIR}/casper"
umask 0000

if [ ! -f "${BASE_ISO}" ];then
 log "Downloading Ubuntu Server live ISO '${UBUNTU_ISO_URL}' to '${BASE_ISO}'"
 curl -fL --retry 5 --retry-delay 5 -o "${BASE_ISO}" "${UBUNTU_ISO_URL}"
fi

if [ "${VERIFY_UBUNTU_ISO}" = "1" ]; then
    ISO_DIR_URL="${UBUNTU_ISO_URL%/*}"
    ISO_FILE_NAME="${UBUNTU_ISO_FILE}"
    BASE_ISO_DIR="${BASE_ISO%/*}"
    log "Verifying Ubuntu ISO checksum  ISO_DIR_URL=${ISO_DIR_URL} BASE_ISO_DIR=${BASE_ISO_DIR} "
    if [ ! -f "${BASE_ISO_DIR}/SHA256SUMS.single" ];then
      log "Downloading Ubuntu ISO SHA256SUMS  ISO_DIR_URL=${ISO_DIR_URL} "
      curl -fL --retry 5 --retry-delay 5 -o "${WORK}/SHA256SUMS" "${ISO_DIR_URL}/SHA256SUMS"
      grep -E "[ *]${ISO_FILE_NAME}$" "${WORK}/SHA256SUMS" > "${BASE_ISO_DIR}/SHA256SUMS.single"
    fi
    (cd "${BASE_ISO_DIR}" && sha256sum -c SHA256SUMS.single)
fi

log "Detecting live filesystem layers"
SQUASHFS_LIST="${WORK}/squashfs.list"
xorriso -indev "${BASE_ISO}" -find /casper -name '*.squashfs' 2>/dev/null \
    | sed "s/'//g" \
    | grep -E "^/casper/.*\.squashfs$" > "${SQUASHFS_LIST}" || true

if ! grep -qxF "${LIVE_SQUASHFS_PATH}" "${SQUASHFS_LIST}"; then
    echo "Requested live squashfs was not found: ${LIVE_SQUASHFS_PATH}" >&2
    echo "Available squashfs files:" >&2
    cat "${SQUASHFS_LIST}" >&2
    exit 1
fi
SQUASHFS_PATH="${LIVE_SQUASHFS_PATH}"
SQUASHFS_BASENAME="${SQUASHFS_PATH##*/}"
SQUASHFS_STEM="${SQUASHFS_BASENAME%.squashfs}"
SIZE_PATH="/casper/${SQUASHFS_STEM}.size"
MANIFEST_PATH="/casper/${SQUASHFS_STEM}.manifest"

log "Extracting ${SQUASHFS_PATH}"
xorriso -osirrox on -indev "${BASE_ISO}" -extract "${SQUASHFS_PATH}" "${WORK}/base-filesystem.squashfs" >/dev/null 2>&1
unsquashfs -q -d "${ROOTFS}" "${WORK}/base-filesystem.squashfs"

log "Configuring live rootfs with updates, drivers, cloud-init, NFS client, and Rust"
log "Configuring /etc/resolv.conf. ROOTFS=${ROOTFS}"
rm -f "${ROOTFS}/etc/resolv.conf"
echo 'nameserver 1.1.1.1' > "${ROOTFS}/etc/resolv.conf"
echo 'nameserver 8.8.8.8' >> "${ROOTFS}/etc/resolv.conf"


log "Configuring /usr/sbin/policy-rc.d"
cat > "${ROOTFS}/usr/sbin/policy-rc.d" <<'EOF'
#!/bin/sh
exit 101
EOF
chmod +x "${ROOTFS}/usr/sbin/policy-rc.d"
cat "${ROOTFS}/usr/sbin/policy-rc.d"

log "Configuring /tmp/configure-ipxe-rootfs.sh"
cat > "${ROOTFS}/tmp/configure-ipxe-rootfs.sh" <<'EOF'
#!/bin/bash
set -euo pipefail

echo "Executing in chroot '/tmp/configure-ipxe-rootfs.sh' file"
echo "--------------------------------------------------------"
echo .

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get -y dist-upgrade
apt-get install -y --no-install-recommends \
    bash-completion \
    build-essential \
    ca-certificates \
    casper \
    cloud-init \
    curl \
    ethtool \
    git \
    gnupg \
    iproute2 \
    iputils-ping \
    initramfs-tools \
    squashfs-tools \
    kmod \
    zstd \
    wget \
    jq \
    linux-firmware \
    linux-generic \
    nfs-common \
    openssh-server \
    pkg-config \
    tcpdump \
    xz-utils \
    isc-dhcp-client \
    apt-utils \
    ipmitool \
    tmux \
    htop \
    mc

apt-get purge -y cryptsetup cryptsetup-initramfs

# 2. Dynamically resolve the absolute latest active kernel version securely
if command -v linux-version >/dev/null 2>&1; then
    KERNEL_VER="$(linux-version list | sort -V | tail -n 1)"
else
    KERNEL_VER="$(ls -1 /lib/modules | sort -V | tail -n 1)"
fi

echo "Detected target kernel variant: ${KERNEL_VER}"

# 3. Install the extra storage/network filesystem drivers
apt-get install -y --no-install-recommends \
        linux-image-${KERNEL_VER} \
        linux-modules-${KERNEL_VER} \
        linux-modules-extra-${KERNEL_VER}

sed -i 's/^MODULES=.*/MODULES=most/' /etc/initramfs-tools/initramfs.conf
sed -i 's/^COMPRESS=.*/COMPRESS=zstd/' /etc/initramfs-tools/initramfs.conf

# 5. Force-feed high-performance network (Solarflare) and network filesystems (NFSv4)
echo "Injecting mandatory netboot modules..."
for module in virtio virtio_ring virtio_pci virtio_net net_failover sfc sunrpc nfs nfsv4 ipmi_watchdog; do
    grep -qxF "${module}" /etc/initramfs-tools/modules || printf '%s\n' "${module}" >> /etc/initramfs-tools/modules
done

# 6. Rebuild the initramfs image payload securely using your specific configs
echo "Compiling final runtime initramfs payload for KERNEL_VER=${KERNEL_VER}..."
cd /

# We force a fresh creation (-c) first to ensure our injected modules are entirely baked in,
# falling back to an update (-u) only if structural system variables require it.
update-initramfs -c -k "${KERNEL_VER}" || update-initramfs -u -k "${KERNEL_VER}"

# 7. Permanent Systemd Unit Sanitization
echo "Applying systemd target overrides and service masking..."

# Disable subiquity/installer services entirely
systemctl disable subiquity || true
systemctl mask subiquity || true
systemctl disable ubuntu-advantage || true

# Completely disable the multipath service stack right inside the OS root
systemctl mask multipathd.service || true
systemctl mask multipathd.socket || true

# Prevent network wait loops from bottlenecking deployment targets
systemctl disable systemd-networkd-wait-online.service || true
systemctl mask systemd-networkd-wait-online.service || true




## APP LEVEL RUST
mkdir -p /opt/rust
if [ -n "${RUST_VERSION:-}" ]; then
    RUST_PKG="rust-${RUST_VERSION}-${RUST_ARCH}.tar.xz"
    TMP_RUST="/tmp/rust-install"
    rm -rf "${TMP_RUST}"
    mkdir -p "${TMP_RUST}"
    cd "${TMP_RUST}"

    curl -fsSLO "${RUST_DIST_BASE}/${RUST_PKG}"
    curl -fsSLO "${RUST_DIST_BASE}/${RUST_PKG}.asc"
    curl -fsSL -o rust-key.asc "${RUST_KEY_URL}"

    gpg --batch --import rust-key.asc

    if [ -n "${RUST_SIGNING_FPR:-}" ]; then
        # 1. Extract the actual fingerprint of the imported key
        # 2. Compare it directly against your expected RUST_SIGNING_FPR string
        IMPORTED_FPR=$(gpg --batch --with-colons --fingerprint --list-keys "rust-key@rust-lang.org" | awk -F: '/^fpr:/ {print $10; exit}')

        if [ "${IMPORTED_FPR}" != "${RUST_SIGNING_FPR}" ]; then
            echo "CRITICAL ERROR: Fingerprint mismatch!"
            echo "Expected: ${RUST_SIGNING_FPR}"
            echo "Got     : ${IMPORTED_FPR}"
            exit 1
        fi
        echo "Fingerprint verified successfully."
    fi

    # Verify the cryptographic signature of the archive
    gpg --batch --verify "${RUST_PKG}.asc" "${RUST_PKG}"

    tar -xJf "${RUST_PKG}"
    "./rust-${RUST_VERSION}-${RUST_ARCH}/install.sh" --prefix=/opt/rust --without=rust-docs
    ln -sfn /opt/rust/bin/rustc /usr/local/bin/rustc
    ln -sfn /opt/rust/bin/cargo /usr/local/bin/cargo
    rm -rf "${TMP_RUST}" /root/.gnupg
fi

apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/*
echo "In chroot scripts done"
EOF

chmod +x "${ROOTFS}/tmp/configure-ipxe-rootfs.sh"

log "Configuring chroot"

mount --bind /dev  "${ROOTFS}/dev"
mount --bind /dev/pts "${ROOTFS}/dev/pts"
mount -t proc /proc "${ROOTFS}/proc"
mount -t sysfs /sys "${ROOTFS}/sys"
mount -t tmpfs tmpfs "${ROOTFS}/run"

chroot "${ROOTFS}" /usr/bin/env \
    RUST_VERSION="${RUST_VERSION}" \
    RUST_ARCH="${RUST_ARCH}" \
    RUST_DIST_BASE="${RUST_DIST_BASE}" \
    RUST_KEY_URL="${RUST_KEY_URL}" \
    RUST_SIGNING_FPR="${RUST_SIGNING_FPR}" \
    /tmp/configure-ipxe-rootfs.sh

for fs in dev/pts dev proc sys run ; do
    umount -lf "${ROOTFS}/$fs"
done

# CLOUD-INIT

cat > ${ROOTFS}/etc/cloud/cloud.cfg.d/91-ipxe-nocloud.cfg <<'EOC'
datasource_list: [ "NoCloud", "None" ]
EOC

cat > ${ROOTFS}/etc/cloud/cloud.cfg.d/92-custom-networking.cfg <<'EOC'
network:
  version: 2
  ethernets:
    default:
      match:
        name: "en*"
      dhcp4: true
      dhcp6: true
      mtu: 9000
      accept-ra: true
      dhcp-identifier: mac
EOC

# IPMI Watchdog configure
cat > ${ROOTFS}/etc/modprobe.d/ipmi_watchdog.conf <<'EOC'
options ipmi_watchdog start_now=0
EOC

cat > ${ROOTFS}/etc/modules-load.d/ipmi_watchdog.conf <<'EOC'
ipmi_watchdog
EOC

sed -i '/^\[Manager\]/a RuntimeWatchdogSec=180' ${ROOTFS}/etc/systemd/system.conf

#cat > ${ROOTFS}/etc/netplan/00-global-dhcp-id.yaml <<'EOC'
#network:
#    version: 2
#    renderer: networkd
#    ethernets:
#      global-defaults:
#        dhcp-identifier: mac
#EOC
#chmod 600 /etc/netplan/00-global-dhcp-id.yaml


#rm -f "${ROOTFS}/etc/resolv.conf"
rm -f "${ROOTFS}/usr/sbin/policy-rc.d" "${ROOTFS}/tmp/configure-ipxe-rootfs.sh"

KERNEL_VER="$(chroot "${ROOTFS}" /bin/bash -lc "ls -1 /lib/modules | sort -V | tail -n 1")"
log "Configuring KERNEL_VER=${KERNEL_VER}. KERNEL_OUT=${KERNEL_OUT} INITRD_OUT=${INITRD_OUT}"

cp "${ROOTFS}/boot/vmlinuz-${KERNEL_VER}" "${KERNEL_OUT}"
cp "${ROOTFS}/boot/initrd.img-${KERNEL_VER}" "${INITRD_OUT}"
require_file "${KERNEL_OUT}" "custom kernel"
require_file "${INITRD_OUT}" "custom initrd"

#if ! lsinitramfs "${INITRD_OUT}" | grep -q 'kernel/drivers/net/ethernet/sfc/sfc.ko'; then
#    echo "Custom initrd does not contain sfc.ko" >&2
#    exit 1
#fi

#if ! lsinitramfs "${INITRD_OUT}" | grep -Eq 'virtio_net\.ko(\.(xz|zst))?$'; then
#    echo "Custom initrd does not contain virtio_net" >&2
#    exit 1
#fi

chroot "${ROOTFS}" dpkg-query -W --showformat='${Package} ${Version}\n' > "${FILESYSTEM_MANIFEST}"
du -sx --block-size=1 "${ROOTFS}" | cut -f1 > "${FILESYSTEM_SIZE}"

log "Extracting and patching grub.cfg"
GRUB_CFG="${WORK}/grub.cfg"
xorriso -osirrox on -indev "${BASE_ISO}" \
    -extract /boot/grub/grub.cfg "${GRUB_CFG}" >/dev/null 2>&1

# Remove 'maybe-ubiquity', 'autoinstall', and quiet/splash that mask cloud-init
# Add 'ds=nocloud' so cloud-init datasource is explicit
sed -i \
    -e 's/maybe-ubiquity//g' \
    -e 's/autoinstall//g' \
    -e 's/quiet splash//g' \
    -e 's|linux\s*/casper/vmlinuz.*|& ds=nocloud cloud-init=enabled|' \
    "${GRUB_CFG}"

log "Repacking live filesystem"
mksquashfs "${ROOTFS}" "${NEW_SQUASHFS}" -comp zstd -b 1M -noappend -no-recovery

log "Repacking ISO and preserving original boot metadata"
xorriso -indev "${BASE_ISO}" \
    -outdev "${TMP_ISO}" \
    -boot_image any replay \
    -overwrite on \
    -map "${NEW_SQUASHFS}" "${SQUASHFS_PATH}" \
    -map "${KERNEL_OUT}" /casper/vmlinuz \
    -map "${INITRD_OUT}" /casper/initrd \
    -map "${FILESYSTEM_SIZE}" "${SIZE_PATH}" \
    -map "${FILESYSTEM_MANIFEST}" "${MANIFEST_PATH}" \
    -map "${GRUB_CFG}" /boot/grub/grub.cfg \
    -rm /casper/ubuntu-server-minimal.ubuntu-server.installer.squashfs \
    -rm /casper/ubuntu-server-minimal.ubuntu-server.installer.generic.squashfs \
    -rm /casper/ubuntu-server-minimal.ubuntu-server.installer.generic-hwe.squashfs \
    -rm /casper/ubuntu-server-minimal.ubuntu-server.squashfs \
    -rm /casper/install-sources.yaml || echo $? || true

mv -f "${TMP_ISO}" "${FINAL_ISO}"
if [ ! -f ${FINAL_ISO} ]; then
 echo "ISO not found in ${FINAL_ISO} after moving from ${TMP_ISO}"
 exit 1
fi
cp -f "${KERNEL_OUT}" "${OUT_DIR}/casper/vmlinuz"
cp -f "${INITRD_OUT}" "${OUT_DIR}/casper/initrd"
(cd "${OUT_DIR}" && sha256sum "${CUSTOM_ISO_NAME}" casper/vmlinuz casper/initrd > SHA256SUMS)
chmod -R 644 ${OUT_DIR}/casper/*

log "ISO build complete to name '${FINAL_ISO}'"

ls -lh "${FINAL_ISO}" "${OUT_DIR}/casper/vmlinuz" "${OUT_DIR}/casper/initrd"
