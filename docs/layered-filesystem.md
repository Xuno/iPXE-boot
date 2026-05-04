# Layered Filesystem Configuration

## Overview

This project uses a layered filesystem approach to create a diskless Ubuntu 24.04 LTS server:

1. **Base Layer** - Read-only SquashFS with the Ubuntu system
2. **Overlay Layer** - Writable layer for runtime changes
3. **NFS Deployment Layer** - Network-mounted layer for deployment tasks

## Layer Structure

```
ubuntu/current/
├── filesystem.squashfs           # Base OS (read-only)
├── apps.filesystem.squashfs     # Application layer (read-only)
├── overlay/                      # Writable layer (automatically created)
├── nfs/                          # NFS deployment layer (network)
└── vmlinuz, initrd               # Boot files
```

## Boot Configuration

The kernel boot parameters enable the layered filesystem:

```bash
boot=casper \
ip=dhcp \
file=/cdrom/preseed/ubuntu.seed \
boot=casper \
noprompt \
boot=casper \
initrd=http://<server>/initrd \
BOOT_IMAGE=/casper/vmlinuz
```

## Creating Deployment Layer

### Option 1: NFS Mount

Create an NFS export on your deployment server:

```bash
# /etc/exports
/data/deployment    192.168.1.0/24(ro,async,no_root_squash)
```

Then create the mount configuration:

```bash
# /etc/systemd/system/mount-nfs.service
[Unit]
Description=Mount NFS deployment layer
After=network.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/mount -t nfs -o vers=4,nolock 192.168.1.100:/data/deployment /mounts/nfs
ExecStop=/usr/bin/umount /mounts/nfs

[Install]
WantedBy=multi-user.target
```

### Option 2: Local Overlay Directory

Create an overlay directory structure:

```bash
mkdir -p /mounts/overlay
mkdir -p /mounts/nfs
```

### Option 3: Use Overlayfs Directly

At boot, the init script creates an overlay filesystem:

```bash
# /etc/systemd/system/overlay.service
[Unit]
Description=Create overlay filesystem
After=local-fs.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/bash -c 'mkdir -p /overlayfs/lower /overlayfs/work /overlayfs/upper && mount -t overlay overlay -o lowerdir=/ro,upperdir=/overlayfs/upper,workdir=/overlayfs/work /merged'
ExecStop=/bin/umount /merged

[Install]
WantedBy=multi-user.target
```

## Deployment Tasks Layer

The NFS layer contains deployment scripts and configuration:

```
nfs/
├── scripts/
│   ├── deploy.sh
│   ├── configure-network.sh
│   └── start-services.sh
├── config/
│   └── services.conf
└── data/
    └── app-data/
```

## Using the Layers

1. **Base Layer** - Ubuntu system files
2. **Apps Layer** - Custom applications
3. **Overlay Layer** - Runtime changes (cache, temporary files)
4. **NFS Layer** - Deployment tasks and persistent data

## Example Boot Sequence

1. PXE boots and fetches iPXE script
2. iPXE fetches kernel and initrd
3. Kernel boots with MTU 9000
4. Initramfs mounts SquashFS layers
5. Overlayfs creates writable layer
6. NFS layer mounts for deployment tasks
7. System boots into Ubuntu

## Troubleshooting

### Check layer mount status:

```bash
mount | grep overlay
mount | grep nfs
```

### List mounted layers:

```bash
findmnt -t overlay
findmnt -t nfs
```

### Check layer permissions:

```bash
ls -la /overlayfs/
ls -la /nfs/
```