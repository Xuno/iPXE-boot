# Deployment Guide - Ubuntu 24.04 LTS Diskless Server

## Overview

This guide walks you through deploying Ubuntu 24.04 LTS diskless servers using PXE boot with iPXE, Nginx HTTP server, and layered SquashFS filesystems.

## Prerequisites

- Physical servers with 40G NICs (Sonic switch compatible)
- TFTP server (optional, iPXE can boot via HTTP)
- HTTP server (Nginx) configured
- Network infrastructure with DHCP and PXE support
- Sonic switch configuration

## Deployment Steps

### 1. Prepare HTTP Server

#### 1.1 Install Nginx

```bash
# On your HTTP server
apt update
apt install nginx
```

#### 1.2 Configure Nginx

Copy `docker/http/nginx.conf` to Nginx config:

```bash
cp docker/http/nginx.conf /etc/nginx/conf.d/ipxe.conf
```

#### 1.3 Create Directory Structure

```bash
# Create boots directory
mkdir -p /var/www/boots/ubuntu/current

# Create symlink for current version
ln -sfn /dev/null /var/www/boots/ubuntu/current

# Create root directory
mkdir -p /usr/share/nginx/html
```

#### 1.4 Configure Sonic Switch

```bash
# Enable jumbo frames on Sonic switch
sonic-config-db set -h <switch-ip> JUMBO_FRAMES_ENABLED true
sonic-config-db set -h <switch-ip> JUMBO_FRAME_SIZE 9000
sonic-config-db set -h <switch-ip> INTERFACE Ethernet0 mtu 9000

# Configure port channels
sonic-config-db set -h <switch-ip> PORTCHANNEL_CHANNEL_GROUP 1 mode LACP
sonic-config-db set -h <switch-ip> PORTCHANNEL_CHANNEL_GROUP 1 ipaddr 192.168.1.1/24
```

### 2. Build System Components

#### 2.1 Build Base OS

```bash
cd /path/to/ipxe-boot
docker compose up --build base-os
```

This builds:
- Kernel (vmlinuz)
- Initramfs (initrd.img)
- Base filesystem (filesystem.squashfs)

#### 2.2 Build Application Layer

```bash
docker compose up --build apps
```

This builds:
- Application layer (apps.filesystem.squashfs)

#### 2.3 Deploy to HTTP Server

```bash
# After builds complete, copy artifacts
cp -r docker/http/boots/ubuntu/current/* /var/www/boots/ubuntu/current/
```

### 3. Configure DHCP Server

#### 3.1 DHCP Configuration

```bash
# /etc/dhcp/dhcpd.conf
option domain-name "example.com";
option domain-name-servers 8.8.8.8, 8.8.4.4;

subnet 192.168.1.0 netmask 255.255.255.0 {
    range 192.168.1.100 192.168.1.200;
    option routers 192.168.1.1;
    option broadcast-address 192.168.1.255;
    option subnet-mask 255.255.255.0;

    # PXE boot configuration
    next-server 192.168.1.1;
    filename "pxelinux.0";
}

# Or for iPXE HTTP boot
subnet 192.168.1.0 netmask 255.255.255.0 {
    range 192.168.1.100 192.168.1.200;
    option routers 192.168.1.1;
    option broadcast-address 192.168.1.255;
    option subnet-mask 255.255.255.0;
    option tftp-server-address 192.168.1.1;
    option next-server 192.168.1.1;
    option filename "http://192.168.1.1:8080/ubuntu/boot.ipxe";
}
```

#### 3.2 Restart DHCP Server

```bash
systemctl restart isc-dhcp-server
```

### 4. Configure NFS for Deployment Layer

#### 4.1 Create NFS Export

```bash
# /etc/exports
/data/deployment    192.168.1.0/24(ro,async,no_root_squash)
```

#### 4.2 Configure Services

```bash
# Enable NFS server
systemctl enable rpcbind
systemctl enable nfs-server
systemctl start rpcbind
systemctl start nfs-server

# Enable firewall
ufw allow from 192.168.1.0/24 to any port nfs
```

### 5. Boot Diskless Servers

#### 5.1 PXE Boot

1. Power on target server
2. Boot from network (PXE)
3. Server will download iPXE from HTTP server
4. iPXE loads kernel and initrd
5. System boots into Ubuntu 24.04 LTS

#### 5.2 Verify Boot

```bash
# Check boot logs
dmesg | grep -i pxe

# Check mounted filesystems
mount | grep -E "overlay|nfs"

# Check network MTU
ip link show
```

### 6. Configure Deployment Layer

#### 6.1 Mount NFS

```bash
# Create mount point
mkdir -p /mnt/nfs

# Mount NFS
mount -t nfs -o vers=4,nolock 192.168.1.100:/data/deployment /mnt/nfs
```

#### 6.2 Deploy Applications

```bash
# Copy application to NFS
cp -r /path/to/app /mnt/nfs/

# Configure services
cp /mnt/nfs/config/services.conf /etc/systemd/system/
systemctl daemon-reload
systemctl enable myapp
```

## Multi-Node Deployment

### Automated Boot Configuration

```bash
# Create boot configuration script
cat > /var/www/boots/ubuntu/boot.ipxe << 'EOF'
#!ipxe

set base-url http://192.168.1.1:8080/ubuntu/current
set timeout 10

echo ========================
echo PXE Boot for Diskless Server
echo ==========================

# Set MTU for jumbo frames
set net0/mtu 9000

# DHCP boot
dhcp

# Boot from HTTP
chain http://${base-url}/vmlinuz \
    boot=casper \
    ip=dhcp \
    file=/cdrom/preseed/ubuntu.seed \
    boot=casper \
    noprompt \
    initrd=http://${base-url}/initrd \
    BOOT_IMAGE=/casper/vmlinuz
EOF
```

### Node Registration

```bash
# Track booted nodes
for ip in $(arp -n | awk '{print $1}'); do
    echo "Node ${ip} booted at $(date)" >> /var/log/pxe-boots.log
done
```

## Verification

### Check Server Status

```bash
# Verify HTTP server
curl http://localhost:8080/health

# Check PXE boot script
curl http://localhost:8080/ubuntu/boot.ipxe

# Verify filesystem layers
ls -la /var/www/boots/ubuntu/current/
```

### Test Boot on Physical Hardware

```bash
# Power cycle target server and observe PXE boot
# Check dmesg for PXE messages
```

## Performance Tuning

### Network Optimization

```bash
# Increase TCP buffers for 40G network
echo "net.core.rmem_max = 67108864" >> /etc/sysctl.conf
echo "net.core.wmem_max = 67108864" >> /etc/sysctl.conf
echo "net.ipv4.tcp_rmem = 4096 87380 67108864" >> /etc/sysctl.conf
echo "net.ipv4.tcp_wmem = 4096 65536 67108864" >> /etc/sysctl.conf
sysctl -p
```

### NFS Performance

```bash
# Tune NFS for 40G network
echo "nfsd.trace=0" >> /etc/default/nfs-common
echo "nfsd.trace=0" >> /etc/default/nfs-kernel-server
```

## Rollback Procedure

If a boot fails:

```bash
# Check version history
ls -la /var/www/boots/ubuntu/

# Rollback to previous version
ln -sfn /var/www/boots/ubuntu/2024-05-01_120000 /var/www/boots/ubuntu/current
```

## Maintenance

### Update System Components

```bash
# Rebuild base OS
docker compose up --build base-os

# Rebuild apps
docker compose up --build apps

# Deploy new version
cp -r docker/http/boots/ubuntu/current/* /var/www/boots/ubuntu/current/
```

### Monitor Boot Logs

```bash
# View PXE boot logs
tail -f /var/log/syslog | grep -i pxe

# View network boot logs
tail -f /var/log/syslog | grep -i network
```