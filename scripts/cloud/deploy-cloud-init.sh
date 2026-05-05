#!/bin/bash
set -euo pipefail

CLOUD_CONFIG="${1:-resources/cloud-init/cloud-config.yaml}"
ISO_DIR="${2:-iso}"
PRESEED_FILE="${ISO_DIR}/preseed/ubuntu.seed"

# Ensure preseed directory exists
mkdir -p "${ISO_DIR}/preseed"

# Copy cloud-config to ISO resources
cp "${CLOUD_CONFIG}" "${ISO_DIR}/resources/cloud-init.cfg"

# Create bootable ISO with embedded cloud-init
if [ -f "${PRESEED_FILE}" ]; then
    echo "Using existing preseed file"
else
    echo "Creating default preseed file"
    cat > "${PRESEED_FILE}" << 'EOF'
d-i debian-installer/locale string en_US
d-i debian-installer/country string US
d-i debian-installer/iso3166code string US
d-i netcfg/choose_interface select auto
d-i netcfg/get_hostname string iPXE-Server
d-i netcfg/get_domain string local
d-i passwd/root-password password insecure
d-i passwd/user-fullname string Admin
d-i passwd/username string admin
d-i passwd/user-password password insecure
d-i passwd/user-password-again password insecure
d-i preseed/timeout string 0
d-i auto-install/enable boolean true
d-i clock-setup/ntp boolean true
d-i time/zone string UTC
EOF
fi

echo "=== Cloud-init configured ==="
echo "Cloud config: ${CLOUD_CONFIG}"
echo "Preseed: ${PRESEED_FILE}"