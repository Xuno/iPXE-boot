Based on my analysis of your project and general knowledge about Ubuntu ISO customization, here's a comprehensive guide for creating a custom Ubuntu 24.04 ISO with casper boot protocol, PXE compatibility, and all the customizations you need.

---

## 1. ISO Creation Workflow Using xorriso

### Basic xorriso Command Structure

```bash
# Create a basic bootable ISO
xorriso -as mkisofs \
  -o output.iso \
  -b /boot/isolinux/isolinux.bin \
  -c /boot/isolinux/boot.cat \
  -no-emul-boot \
  -boot-load-size 4 \
  -boot-info-table \
  -eltorito-alt-boot \
  -e /boot/grub/efi.img \
  -no-emul-boot \
  -isohybrid-gpt-basdat \
  -isohybrid-apm-hfsplus \
  -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
  -volid "UBUNTU_24_04_casper-rw" \
  -J -r -A "Ubuntu 24.04 Custom" \
  -V "Ubuntu 24.04" \
  -quiet \
  -print-size \
  /path/to/casper/filesystem.squashfs
```

### Enhanced xorriso with Customizations

```bash
# Create enhanced ISO with customizations
xorriso -as mkisofs \
  -V "UBUNTU_24_04_CUSTOM" \
  -publisher "Teradex Systems" \
  -application_id "iPXE Boot ISO" \
  -J -r -l -D -N \
  -b isolinux/isolinux.bin \
  -c isolinux/boot.cat \
  -no-emul-boot \
  -boot-load-size 4 \
  -boot-info-table \
  -eltorito-alt-boot \
  -e EFI/BOOT/efiboot.img \
  -no-emul-boot \
  -isohybrid-gpt-basdat \
  -relaxed-filenames \
  -o custom-ubuntu-24.04.iso \
  /path/to/casper/filesystem.squashfs \
  /path/to/custom/scripts \
  /path/to/custom/grub.cfg
```

### Advanced xorriso for PXE Booting

```bash
# Create ISO optimized for PXE booting
xorriso -as mkisofs \
  -o ubuntu-24.04-pxe.iso \
  -b isolinux/isolinux.bin \
  -c isolinux/boot.cat \
  -no-emul-boot \
  -boot-load-size 4 \
  -isohybrid-gpt-basdat \
  -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
  -eltorito-alt-boot \
  -e EFI/BOOT/efiboot.img \
  -no-emul-boot \
  -J -r \
  /path/to/iso-structure
```

---

## 2. How to Inject Custom Kernel Modules

### Download and Extract Ubuntu 24.04

```bash
# Download official ISO
wget https://releases.ubuntu.com/24.04/ubuntu-24.04-live-server-amd64.iso

# Mount and extract
mkdir -p ubuntu-iso-extract
cd ubuntu-iso-extract

# For QEMU (no hardware required)
sudo modprobe loop
sudo mkdir -p /mnt/iso
sudo mount -o loop -t iso9660 ../ubuntu-24.04-live-server-amd64.iso /mnt/iso

# Extract squashfs
mkdir -p casper
sudo unsquashfs -f /mnt/iso/casper/filesystem.squashfs -d casper-root
```

### Add Custom Kernel Modules

```bash
# Go to root filesystem
cd casper-root

# Install additional kernel modules if needed
sudo apt-get update
sudo apt-get install -y linux-modules-extra-$(uname -r)

# For custom modules (example: NFS or SFC driver module)
# Download module files
mkdir -p /lib/modules/$(uname -r)/extra/sfc
# Copy custom module files
# sudo cp custom_module.ko /lib/modules/$(uname -r)/extra/sfc/

# Install from local source
# tar -xzf my-kernel-modules.tar.gz -C /
```

### Inject Modules into Squashfs

```bash
# Navigate back to extracted squashfs
cd ..

# Rebuild squashfs with added modules
sudo rm casper/filesystem.squashfs
sudo mksquashfs casper-root casper/filesystem.squashfs \
  -comp xz \
  -b 1M \
  -Xcompression-level 12 \
  -always-use-fragments

# Add module list for initramfs
sudo mksquashfs casper-root /lib/modules /usr/lib/modules \
  -p 'd /lib/modules 755 root root' \
  -p 'd /usr/lib/modules 755 root root' \
  -p 'f /lib/modules/*/modules.dep 644 root root' \
  -p 'f /lib/modules/*/modules.dep.bin 644 root root'
```

---

## 3. How to Customize initramfs for Casper Boot

### Understanding Casper Initramfs Structure

```
/casper/
├── filesystem.squashfs   # Root filesystem
├── vmlinuz               # Linux kernel
└── initrd.img            # Initramfs (contains squashfs mount helpers)
```

### Extract Existing Initramfs

```bash
# Extract initrd.img
mkdir initrd-extract
cd initrd-extract

# For initrd.gz (earlier Ubuntu versions)
gunzip -c ../ubuntu.iso/initrd.gz | cpio -idm

# For initrd.img (Ubuntu 24.04)
gunzip -c ../ubuntu-24.04-live-server-amd64.iso/initrd.img | cpio -idm
```

### Customize Initramfs

```bash
# Add custom modules to initramfs
# Add to initramfs build directory
sudo mkdir -p /etc/casper/modules/

# Create custom module
sudo tee /etc/casper/modules/custom.sh << 'EOF'
#!/bin/sh

# Add custom commands to initramfs
# Example: Enable NFS mount at boot

# Add extra modules
PRIVILEGED_MODULES="sfc mdadm"

# Append to modules list
if [ -f /usr/share/initramfs-tools/scripts/local-bottom/casper ]; then
    echo "$PRIVILEGED_MODULES" >> /usr/share/initramfs-tools/scripts/local-bottom/casper
fi

# Enable network modules
echo "wifi" >> /etc/initramfs-tools/modules
echo "dhcp" >> /etc/initramfs-tools/modules
EOF

# Make executable
sudo chmod +x /etc/casper/modules/custom.sh

# Add to module list
echo "custom" >> /etc/casper/modules/common.list
```

### Build Custom Initramfs

```bash
# Navigate to extracted ISO
cd ..

# Get kernel version
KERNEL_VERSION=$(ls initrd-extract/lib/modules/)
echo "Kernel version: $KERNEL_VERSION"

# Build new initramfs
sudo update-initramfs \
    -v -c -k "$KERNEL_VERSION" \
    -o custom-24-04-initrd.img

# The initramfs is built with squashfs support built-in
# casper uses squashfs helpers: /usr/share/casper/casper*
```

### Modify Casper Boot Parameters

```bash
# Edit or create casper.conf
sudo tee /etc/casper/casper.conf << 'EOF'
#!/bin/sh

# Kernel command line modifications
# For PXE boot specifically

# Default hostname
# export hostname="ubuntu-pxe"

# Default user setup
# export username="ubuntu"

# Default username setup
# export username="ubuntu"
# export pass="ubuntu"

# Custom boot options
export boot="casper"
export quiet="yes"
export text="yes"  # Force text mode

# Network configuration
export ip="dhcp"
export netboot="url"

# Layered filesystem support
export layerfs_path="filesystem.app.squashfs"
EOF

# Make executable
sudo chmod +x /etc/casper/casper.conf
```

---

## 4. How to Include Custom GRUB Configurations

### Extract and Modify GRUB

```bash
# Extract GRUB modules and configuration
cd ubuntu-iso-extract
sudo rm -rf grub-mods
sudo mkdir -p grub-mods

# Copy GRUB files
sudo rsync -a /mnt/iso/EFI/BOOT/ grub-mods/
sudo rsync -a /mnt/iso/boot/grub/ grub-mods/

# Extract grub.cfg from ISO
cd /mnt/iso
sudo dd if=/dev/zero of=grub.cfg bs=1024 count=1
sudo dd if=boot/grub/grub.cfg of=grub.cfg conv=yes sync
```

### Create Custom GRUB Configuration

```bash
# Create custom grub.cfg
sudo tee > grub-mods/EFI/BOOT/custom.cfg << 'EOF'
# Custom GRUB configuration for Ubuntu 24.04 PXE Boot

set timeout=10
set default=0

menuentry "Ubuntu 24.04 Custom" {
    set gfxpayload=text
    linux /casper/vmlinuz boot=casper noprompt file=/cdrom/preseed/ubuntu.seed \
        ip=dhcp boot=casper \
        layerfs-path=filesystem.app.squashfs \
        quiet splash
    initrd /casper/initrd
}

menuentry "Ubuntu 24.04 OEM" {
    set gfxpayload=text
    linux /casper/vmlinuz boot=casper noprompt file=/cdrom/preseed/ubuntu.seed \
        ip=dhcp boot=casper oem-config/enable=true \
        oem-config/id=teradex \
        quiet splash
    initrd /casper/initrd
}

menuentry "Debug Mode" {
    set gfxpayload=text
    text
    linux /casper/vmlinuz debug
    initrd /casper/initrd
}
EOF

# Create UEFI boot entry
sudo tee > grub-mods/EFI/BOOT/grub.cfg << 'EOF'
#!/bin/sh
set -e

default=0

menuentry "Ubuntu 24.04 Custom" {
    search --set -f /casper/vmlinuz
    linux /casper/vmlinuz boot=casper noprompt file=/cdrom/preseed/ubuntu.seed \
        ip=dhcp boot=casper ip=dhcp \
        layerfs-path=filesystem.app.squashfs quiet splash
    initrd /casper/initrd
}
EOF
```

### Create UEFI Bootable Image

```bash
# Create EFI image
sudo grub-mkstandalone \
    --format=efi-signed \
    --output=grub-efi-signed.img \
    --modules="part_gpt part_msdos ext2 configfile normal linux echo search linuxefi"
```

---

## 5. ISO Structure for Casper Boot Protocol

### Complete ISO Structure

```
ubuntu-24.04-custom.iso
├── isolinux/
│   ├── isolinux.bin
│   ├── boot.cat
│   └── isolinux.cfg
├── EFI/
│   ├── BOOT/
│   │   ├── BOOTX64.EFI
│   │   └── BOOTIA32.EFI
│   └── GRUB/
│       ├── grub.cfg
│       └── grub.x64
├── boot/
│   ├── boot.cat
│   ├── grub.cfg
│   ├── initrd.img
│   └── vmlinuz
├── casper/
│   ├── filesystem.squashfs
│   ├── initrd.img
│   └── vmlinuz
├── preseed/
│   └── ubuntu.seed
├── disk/
│   ├── disk1.img
│   └── disk1.mbr
├── casper-rw
└── autorun.inf
```

### Create ISO Structure Directory

```bash
# Create directory structure
mkdir -p ubuntu-iso-custom/{isolinux,EFI/BOOT,EFI/GRUB,boot,casper,preseed,disk,custom}
cd ubuntu-iso-custom

# Copy bootfiles from official ISO
sudo cp /mnt/iso/isolinux/* isolinux/
sudo cp /mnt/iso/boot/* boot/
sudo cp /mnt/iso/casper/* casper/
sudo cp /mnt/iso/EFI/* EFI/BOOT/

# Add custom files
sudo cp custom-scripts/* custom/
sudo cp custom-grub.cfg EFI/GRUB/grub.cfg

# Extract disk
sudo dd if=/dev/zero of=disk/disk1.img bs=1M count=4000
sudo mkfs.ext4 -L ubuntu-root disk/disk1.img
sudo mkdir -p mnt
sudo mount -o loop disk/disk1.img mnt
sudo dd if=boot/initrd.img of=... # Copy if needed
```

### Prepare Ubuntu Seed File

```bash
# Create or modify ubuntu.seed
sudo tee casper/preseed/ubuntu.seed << 'EOF'
# Ubuntu 24.04 Server PXE Customization Seed

d-i netcfg/get_hostname string teradex-server
d-i netcfg/get_domain string teradex.local

d-i netcfg/disable_dhcp boolean false
d-i netcfg/dhcp_hostname string teradex-pxe

# Network configuration
d-i debian-installer/netcfg/choose_interface select auto

# Configure network automatically
d-i netcfg/use_autoconfig boolean true

# Localization
d-i console-setup/ask_detect boolean false
d-i keyboard-configuration/layoutcode list \
    us English:United States
d-i localechooser/default-language string en_US

# Timezone
d-i clock-setup/utc boolean true
d-iclock-setup/zone string UTC

# User setup
d-i passwd/root-login enabled
d-i passwd/root-default-passphrase disabled

# Package selection
d-i pkgsel/include string openssh-server nfs-common

# Software selection
d-i tasksel/firstboot/tasksel multiselect standard, openssh-server

# Install additional packages
d-i preseed/early_command string apt-get -y update && apt-get -y install \
    xfsprogs \
    e2fsprogs \
    lvm2 \
    smartmontools

# Network configuration for PXE
d-i preseed/late_command string \
    in-target -u cat << EOF >> /etc/interfaces.d/50-cloud-init \
\
# Network configuration for diskless PXE
auto lo
iface lo inet loopback

# Auto-eth0 based on DHCP
auto eth0
iface eth0 inet dhcp
EOF
```

---

## 6. How to Modify Squashfs Filesystem for Custom ISO

### Understand SquashFS Configuration

```bash
# SquashFS parameters
# -comp xz : Compress with XZ
# -b 1M : Block size 1MB
# X -compression-level 12 : XZ compression level
```

### Create Custom Squashfs

```bash
# Build filesystem with customizations
sudo mksquashfs custom-root-files /path/to/output/filesystem.squashfs \
  -comp xz \
  -b 1M \
  -Xcompression-level 12 \
  -always-use-fragments \
  -noappend \
  -filters 'compressors.map' \
  -filter-files 'root_files.list'

# Example filter map file
sudo tee compressors.map << 'EOF'
** -filter tar -action copy
*.so -compressor xz -b 1M
*.conf -compressor xz
** -compressor xz
EOF

# Add files to squashfs individually
sudo mksquashfs /path/to/copy/files system-root/filesystem.squashfs \
  -root-binds \
  -noappend \
  -wildcards

# For large filesystem modifications
# Extract current squashfs, modify, then rebuild
cd ubuntu-iso-extract
unsquashfs casper/filesystem.squashfs squashfs-root
cd squashfs-root
# Make modifications...
cd ..
mksquashfs squashfs-root casper/filesystem.squashfs -comp xz
```

### Add Custom Applications to Squashfs

```bash
# Install applications to chroot
sudo chroot squashfs-root bash -c apt-get update && apt-get install -y \
    my-custom-app \
    my-driver \
    utilities

# Copy application binaries
sudo mkdir -p squashfs-root/usr/local/bin
sudo cp my-app binaries/some-app squashfs-root/usr/local/bin/

# Update desktop entry
sudo tee squashfs-root/usr/share/applications/my-app.desktop << 'EOF'
[Desktop Entry]
Version=1.0
Name=My Custom App
Type=Application
Exec=/usr/local/bin/my-app
Icon=my-app-icon
Terminal=false
Categories=Utility;
EOF
```

### Optimize Squashfs Size

```bash
# Pre-compress files before adding
cd squashfs-root
sudo find . -type f -exec gzip -9 {} \;

# Rebuild with pre-compressed files
cd ..
sudo mksquashfs squashfs-root casper/filesystem.squashfs \
  -comp gzip \
  -b 1M \
  -root-binds \
  -always-use-fragments \
  -noappend
```

---

## 7. Best Practices for Customizing Ubuntu ISOs

### Build Process Best Practices

```bash
#!/bin/bash
# build-custom-iso.sh - Comprehensive ISO build script

set -euo pipefail

ISO_NAME="ubuntu-24.04-custom"
BASE_ISO="ubuntu-24.04-live-server-amd64.iso"
WORK_DIR="$HOME/ubuntu-iso-build"
OUTPUT_DIR="$HOME/custom-iso-output"

# Create workspace
mkdir -p "$WORK_DIR" "$OUTPUT_DIR"
cd "$WORK_DIR"

# 1. Extract base ISO
echo "[1/6] Extracting base ISO..."
sudo mount -o loop -t iso9660 "$BASE_ISO" cdrom
sudo rsync -a --exclude=mnt --exclude=$Base_ISO cdrom/ ./extracted/

# 2. Modify squashfs
echo "[2/6] Modifying squashfs..."
cd extracted
sudo unsquashfs -f casper/filesystem.squashfs squashfs-root
cd squashfs-root

# Apply customizations
sudo mkdir -p /etc/casper/modules
sudo tee /etc/casper/modules/custom.sh << 'EOF'
#!/bin/sh
# Custom initramfs module
# Add your custom commands here
EOF

sudo chmod +x /etc/casper/modules/custom.sh

# 3. Build initramfs
echo "[3/6] Building initramfs..."
cd ..
sudo update-initramfs -c -k $(ls lib/modules/ | head -1)

# 4. Rebuild squashfs
echo "[4/6] Rebuilding squashfs..."
sudo mksquashfs squashfs-root casper/filesystem.squashfs -comp xz -b 1M

# 5. Inject custom GRUB
echo "[5/6] Injecting custom GRUB..."
sudo cp ../GRUB/custom.cfg boot/grub/custom.cfg

# 6. Create ISO
echo "[6/6] Creating ISO..."
sudo umount cdrom

xorriso -as mkisofs \
  -V "$ISO_NAME" \
  -publisher "Teradex Systems" \
  -b isolinux/isolinux.bin \
  -c isolinux/boot.cat \
  -no-emul-boot \
  -boot-load-size 4 \
  -boot-info-table \
  -eltorito-alt-boot \
  -e EFI/BOOT/efiboot.img \
  -no-emul-boot \
  -isohybrid-gpt-basdat \
  -o "$OUTPUT_DIR/$ISO_NAME.iso" \
  extracted/
```

### PXE Boot Best Practices

**In iPXE Boot Script:**
```
#!ipxe
set base-url http://your-server:8080
set boot-url ${base-url}/boot

# Enable PXE boot with specific kernels
kernel ${base-url}/linux boot=casper \
    ip=dhcp \
    layerfs-path=apps.filesystem.squashfs \
    noprompt
initrd ${base-url}/initrd
boot
```

### Verification Commands

```bash
# Verify ISO structure
isoinfo -d -i custom-iso.iso
isoinfo -l -i custom-iso.iso

# Mount and test
mkdir iso-test
sudo mount -o loop custom-iso.iso iso-test
ls -la iso-test/
ls -la iso-test/casper/

# Check squashfs
unsquashfs -list iso-test/casper/filesystem.squashfs | head

# Check initramfs
gunzip -c iso-test/casper/initrd.img | cpio -t | less

# Verify bootable with QEMU
qemu-system-x86_64 -cdrom custom-iso.iso -nographic
```

### Integration with Your Current Project

```bash
# Create hybrid ISO with your current setup
xorriso -as mkisofs \
  -o docker/http/iso/ubuntu-24.04-custom.iso \
  -V "UBUNTU_24_04_CUSTOM" \
  -publisher "Teradex Systems" \
  -b isolinux/isolinux.bin \
  -c isolinux/boot.cat \
  -no-emul-boot \
  -boot-load-size 4 \
  -boot-info-table \
  -isohybrid-gpt-basdat \
  -J -r \
  Docker/http/boots/ubuntu/current \
  Docker/http/iso/custom-files
```

---

## Complete PXE-Ready ISO Creation Command

```bash
# Final complete command for creating PXE-ready ISO
xorriso -as mkisofs \
  -o /output/ubuntu-24.04-pxe.iso \
  -V "UBUNTU_24_04_PXE" \
  -publisher "Teradex Systems" \
  -application_id "iPXE Boot System" \
  -J -r -l -D -N \
  -b isolinux/isolinux.bin \
  -c isolinux/boot.cat \
  -no-emul-boot \
  -boot-load-size 4 \
  -boot-info-table \
  -eltorito-alt-boot \
  -e EFI/BOOT/grub.ia32.efi \
  -no-emul-boot \
  -eltorito-alt-boot \
  -e EFI/BOOT/grub.x64.efi \
  -no-emul-boot \
  -isohybrid-gpt-basdat \
  -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
  -isohybrid-apm-hfsplus \
  -relaxed-filenames \
  -quiet \
  /path/to/casper/filesystem.squashfs \
  /path/to/custom/grub.cfg \
  /path/to/preseed/ubuntu.seed
```

This creates a dual-bootable (BIOS/UEFI) ISO optimized for PXE booting with your casper layering system already configured in the boot parameters.