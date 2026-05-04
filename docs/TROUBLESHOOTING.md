# Troubleshooting Guide

This file captures common failures seen in this project and the practical fix.

## Table of Contents

- [Common Issues](#common-issues)
- [Network Boot Problems](#network-boot-problems)
- [Filesystem Issues](#filesystem-issues)
- [Performance Problems](#performance-problems)
- [SFC Driver Issues](#sfc-driver-issues)
- [Multi-Node Issues](#multi-node-issues)

## Common Issues

## 1) `no such service: base-os`

### Symptom
- Running `docker compose ... base-os` fails with:
- `no such service: base-os`

### Cause
- Command executed from wrong directory, so another compose project is used.

### Fix
- Run from `docker/`:
- `cd docker`
- `docker compose config --services`
- Expected: `base-os`, `apps`

## 2) Rust build fails with lockfile permission error

### Symptom
- `failed to write /src/Cargo.lock`
- `Permission denied (os error 13)`

### Cause
- `/src` created as root; build runs as `builder`.

### Fix
- Ensure Dockerfile has:
- `RUN chown -R builder:builder /src`
- before `USER builder`.

## 3) `COPY --from=builder ... hello-ipxe: not found`

### Symptom
- Runtime stage copy fails because file not present.

### Cause
- Binary built into a cache-mounted location or wrong expected path.

### Fix
- In builder stage, copy artifact to stable path after build:
- `cp -f /src/target/release/hello-ipxe /tmp/hello-ipxe`
- In runtime stage:
- `COPY --from=builder /tmp/hello-ipxe /runtime/hello-ipxe`

## 4) Concern: `curl | sh` for rustup is unsafe

### Symptom
- Security risk identified: remote script as root.

### Fix
- Use standalone Rust archive with GPG verification:
1. Download `rust-<version>-<arch>.tar.xz` and `.asc`
2. Import trusted Rust release key
3. `gpg --verify ...`
4. Install from verified archive

## 5) GPG warning: `key is not certified with a trusted signature`

### Symptom
- Build log shows warning after good signature.

### Cause
- Fresh container keyring has no web-of-trust path.

### Fix
- Pin fingerprint in env:
- `RUST_SIGNING_FPR=108F66205EAEB0AAA8DD5E1C85AB96E6FA1BE5FE`
- Good signature + fingerprint pinning is expected model in CI/container.

## 6) App layer not applied at runtime

### Symptom
- App files missing after boot.

### Cause
- `boot.ipxe` missing `layerfs-path` kernel arg or wrong layer filename.

### Fix
- In `docker/http/root/ubuntu/boot.ipxe`, ensure:
- `url=${base-boots-url}/filesystem.squashfs`
- `layerfs-path=apps.filesystem.squashfs`

## 7) Independent layer upgrades not working

### Symptom
- App changes require rebuilding base image.

### Cause
- App layer merged into base squashfs during base build.

### Fix
- Keep layers independent:
1. Build `base-os` to create/update `current`
2. Build `apps` to write `apps.filesystem.squashfs` into `current`
3. Boot with `layerfs-path=<leaf-layer>`

## 8) Casper multi-layer naming confusion

### Symptom
- Unsure how to chain multiple layers.

### Rule
- Casper computes parent layers by stripping dotted prefixes from `layerfs-path` leaf.

### Example
- Leaf: `feature.apps.filesystem.squashfs`
- Required files:
1. `filesystem.squashfs`
2. `apps.filesystem.squashfs`
3. `feature.apps.filesystem.squashfs`

All must exist in the same boot directory (`boots/ubuntu/current`).

## Network Boot Problems

## 9) Boot Doesn't Start

### Symptom
- Server doesn't boot or shows "Boot from network failed"

### Solutions:

1. **Check PXE Boot Enablement:**
   ```bash
   # In BIOS/UEFI, verify PXE is enabled in network boot settings
   # Should be under: Boot -> Network Boot / PXE
   ```

2. **Check Network Cable:**
   ```bash
   # Verify cable is connected to correct port
   # Use LEDs to confirm link activity
   ```

3. **Verify DHCP Server:**
   ```bash
   # Check DHCP server is running
   systemctl status isc-dhcp-server

   # Check DHCP leases
   cat /var/lib/dhcp/dhcpd.leases

   # Test DHCP from target server
   dhclient eth0
   ```

## 10) HTTP Server Not Responding

### Symptom
- iPXE can't reach HTTP server

### Solutions:

1. **Check HTTP Server Status:**
   ```bash
   systemctl status nginx
   curl http://localhost:8080/health
   ```

2. **Check Firewall:**
   ```bash
   # Allow HTTP traffic
   ufw allow 80/tcp
   ufw allow 8080/tcp

   # Or iptables
   iptables -A INPUT -p tcp --dport 8080 -j ACCEPT
   ```

3. **Check Network Connectivity:**
   ```bash
   # From iPXE boot environment (if available)
   ping -c 4 <HTTP-SERVER-IP>

   # Check if port is open
   nc -zv <HTTP-SERVER-IP> 8080
   ```

## 11) PXE Timeout Error

### Symptom
- "PXE-E53: No boot filename received"

### Solutions:

1. **Verify DHCP Configuration:**
   ```bash
   # Check filename in dhcpd.conf
   cat /etc/dhcp/dhcpd.conf | grep filename

   # Should point to boot.ipxe
   filename "http://192.168.1.1:8080/ubuntu/boot.ipxe";
   ```

2. **Check PXE Server:**
   ```bash
   # Verify TFTP is running (if using TFTP)
   systemctl status tftpd

   # Check TFTP directory
   ls -la /srv/tftp
   ```

3. **Reboot Server:**
   ```bash
   # Power cycle and retry
   # Check BIOS/UEFI for PXE priority order
   ```

## Filesystem Issues

## 12) SquashFS Not Found

### Symptom
- "SquashFS filesystem not found"

### Solutions:

1. **Check File Existence:**
   ```bash
   # Verify files exist on HTTP server
   curl -I http://<server>/ubuntu/current/vmlinuz
   curl -I http://<server>/ubuntu/current/initrd
   curl -I http://<server>/ubuntu/current/filesystem.squashfs
   ```

2. **Check Directory Structure:**
   ```bash
   # Verify directory structure
   ls -la /var/www/boots/ubuntu/current/

   # Should have: vmlinuz, initrd, filesystem.squashfs, apps.filesystem.squashfs
   ```

3. **Check Permissions:**
   ```bash
   # Verify permissions
   ls -la /var/www/boots/ubuntu/current/
   chmod 644 /var/www/boots/ubuntu/current/*.*
   ```

## 13) Mount Failed

### Symptom
- Filesystem mount fails

### Solutions:

1. **Check Mount Points:**
   ```bash
   # Check if mounted
   mount | grep overlay
   mount | grep nfs

   # Check mount points exist
   ls -la /overlayfs/
   ls -la /nfs/
   ```

2. **Check Mount Configuration:**
   ```bash
   # Check systemd services
   systemctl list-units | grep -E "overlay|nfs"

   # Check service status
   systemctl status overlay
   systemctl status nfs
   ```

3. **Manual Mount:**
   ```bash
   # Mount overlay
   mkdir -p /overlayfs/lower /overlayfs/work /overlayfs/upper
   mount -t overlay overlay -o lowerdir=/ro,upperdir=/overlayfs/upper,workdir=/overlayfs/work /merged

   # Mount NFS
   mount -t nfs -o vers=4,nolock <SERVER>:/data/deployment /mnt/nfs
   ```

## Performance Problems

## 14) Slow Boot Times

### Symptom
- Server takes too long to boot

### Solutions:

1. **Check Network Speed:**
   ```bash
   # Verify link speed
   ethtool eth0 | grep Speed

   # Should show: Speed: 40000Mb/s (40G)
   ```

2. **Optimize Network Stack:**
   ```bash
   # Apply TCP optimizations
   sysctl -p /etc/sysctl.d/40-network.conf
   ```

3. **Check DNS:**
   ```bash
   # Use IP instead of hostname in boot script
   # Change: http://hostname
   # To: http://192.168.1.1
   ```

## 15) High Latency

### Symptom
- Network latency issues

### Solutions:

1. **Check for Packet Drops:**
   ```bash
   # Check for dropped packets
   ethtool -S eth0 | grep -i drop
   ```

2. **Verify MTU Size:**
   ```bash
   # Ensure consistent MTU across network
   ip link show
   ping -M do -s 8972 <SERVER-IP>

   # Test jumbo frame transmission
   ping -M do -s 8972 -c 10 <SERVER-IP>
   ```

3. **Check Network Switch:**
   ```bash
   # Check switch statistics
   sonic-show-intf -i Ethernet0 -l

   # Check port errors
   sonic-show-interface --namespace default --port Ethernet0
   ```

## SFC Driver Issues

## 16) SFC Driver Not Loading

### Symptom
- SFC driver fails to load

### Solutions:

1. **Check Module Availability:**
   ```bash
   modinfo sfc

   # Should show module information
   ```


2. **Load Module Manually:**
   ```bash
   modprobe sfc

   # Check if loaded
   lsmod | grep sfc
   ```


3. **Check Kernel Logs:**
   ```bash
   dmesg | grep -i sfc

   # Look for: "sfc: probe failed", "sfc: driver failed"
   ```


## 17) High NIC Errors

### Symptom
- High packet errors on SFC NIC

### Solutions:

1. **Check for Firmware Issues:**
   ```bash
   # Check firmware
   ethtool -i eth0

   # Update firmware if needed
   ethtool -f eth0 firmware-update
   ```


2. **Disable Interrupt Coalescing:**
   ```bash
   ethtool -C eth0 adaptive-rx off adaptive-tx off rx-usecs 0 tx-usecs 0
   ```


3. **Disable TSO:**
   ```bash
   ethtool -K eth0 tso off gso off gro off
   ```


## Multi-Node Issues

## 18) Inconsistent Boot Behavior

### Symptom
- Some nodes boot, some don't

### Solutions:

1. **Check Node Hardware:**
   ```bash
   # Verify all nodes have same NIC
   lspci | grep -i ethernet

   # Check BIOS versions
   dmidecode | grep -i version
   ```


2. **Check DHCP Leases:**
   ```bash
   # Check which nodes have leases
   cat /var/lib/dhcp/dhcpd.leases

   # Should see all nodes with IP addresses
   ```


3. **Check PXE Boot Order:**
   ```bash
   # In BIOS, verify PXE priority
   # Should be: Network -> HDD -> USB
   ```


## 19) PXE Boot Overload

### Symptom
- Too many nodes booting simultaneously

### Solutions:

1. **Rate Limit PXE Boot:**
   ```bash
   # Limit DHCP concurrent connections
   # In dhcpd.conf
   max-clients 100;
   ```


2. **Stagger Boot Times:**
   ```bash
   # Add boot delay in BIOS for staggered boot
   # Or use PXE menu to delay
   ```


3. **Monitor PXE Boot Activity:**
   ```bash
   # Watch PXE boot logs
   tail -f /var/log/syslog | grep -i pxe

   # Track boot attempts
   tail -f /var/log/dhcp.log
   ```


## Debugging Tools

## Quick Recovery Commands

From `docker/`:
1. `docker compose down`
2. `docker compose --progress=plain up --build base-os`
3. `docker compose --progress=plain up --build apps`
4. Check `http/boots/ubuntu/current/` contents

## Enable Debug Logs

```bash
# Enable iPXE debug
set debug 1

# Enable kernel debug
dmesg -n 8
```

## Check Boot Parameters

```bash
# View current boot parameters
cat /proc/cmdline

# Should include: MTU=9000, boot=casper, etc.
```

## Monitor Boot Process

```bash
# Watch boot sequence
journalctl -f

# Watch systemd boot
systemctl list-jobs

# Watch network boot
systemctl status systemd-networkd
```

## Network Diagnostics

```bash
# Check routing table
ip route show

# Check ARP table
arp -an

# Check TCP connections
ss -tunlp
```

## Diskless Server Diagnostics

```bash
# Check mounted filesystems
mount | grep -E "overlay|nfs"

# Check diskless mount points
df -h /overlayfs/ /nfs/

# Check service status
systemctl status systemd-journald
systemctl status systemd-timesyncd
```
