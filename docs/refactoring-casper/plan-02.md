Excellent! That clarifies the architecture completely. 

**First Boot** = Special initialization phase (only happens once)
**Subsequent Reboots** = Purely stateless, fast boot from clean Ubuntu

## 📋 Final Architecture: Custom Ubuntu 24.04 ISO with Stateless Deployments

### **Architecture Overview**

```
iPXE Boot → Custom Ubuntu ISO → Cloud-Init First Boot (runs ONCE) → App Deployment ←→ NFS Persistent Data
                                                    ↓
                        Subsequent Reboots → Clean OS boots instantly (no reconfiguration)
```

### **Key Concepts**

**First Boot (Initialization)**
- Runs `runcmd` in `user-data.yaml` only the first time
- Installs Rust toolchain
- Deploys your app
- Sets up NFS mount
- Creates users

**Stateless Reboots**
- Cloud-init detects `cloud-init-run-dir` exists (created on first boot)
- Skips all configuration
- Instant boot from clean Ubuntu
- Deployments persist only in NFS

**Custom ISO Benefits**
- Inject latest kernel (support newer hardware)
- Pre-install cloud-init preseeds
- Embed kernel modules you need
- Smaller than full ISO customization
- Boot from PXE or USB

### **Implementation Plan**

#### 1. **Custom Ubuntu 24.04 ISO Build System**

**Dockerfile**:
```dockerfile
FROM ubuntu:24.04

# Base ISO installation
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        xorriso \
        cdbs \
        squashfs-tools \
        cloud-init \
        linux-image-generic \
        initramfs-tools \
        grub-pc-bin \
        isolinux \
        syslinux-common \
    && rm -rf /var/lib/apt/lists/*

# Prepare ISO directory structure
RUN mkdir -p \
    /iso/casper \
    /iso/casper/dist \
    /iso/casper/files \
    /iso/casper/uuid \
    /iso/.disk \
    /iso/image \
    /iso/dists \
    /iso/pool \
    /iso/parts \
    /iso/preseed \
    /boot/grub

WORKDIR /iso

# Prepare casper filesystem
RUN mksquashfs /iso/casper /iso/casper/filesystem.squashfs -comp zstd -b 1M

# Generate manifest
RUN echo "filesystem.squashfs  $(du -b /iso/casper/filesystem.squashfs | awk '{print $1}')" > /iso/casper/filesystem.manifest
RUN cd /iso && awk -F/ 'FNR>1{gsub(/^[^-]+-[0-9]+\.[0-9]+/, "."); gsub(/\/$/, ""); gsub(/-.*/, ""); print $NF}' /iso/casper/filesystem.manifest > /iso/casper/filesystem.manifest-remove && \
    xargs -a /iso/casper/filesystem.manifest-remove rm -rf

# Create ISO structure
RUN touch /iso/.disk/info && \
    echo "Ubuntu 24.04 Server 24.04.1 LTS" > /iso/.disk/info && \
    mkdir -p /iso/.disk && \
    echo -n > /iso/.disk/ubuntu_dist

WORKDIR /root
```

#### 2. **iPXE Boot Script (Custom ISO)**

```ipxe
#!ipxe
set server-ip 192.168.1.100
set server-port 8080
set iso-path http://${server-ip}:${server-port}/ubuntu/custom-24.04.iso

echo ==============================
echo Ubuntu 24.04 Custom ISO PXE
echo ==============================

# Configure network
dhcp net0 || exit 1
set net0/mtu 1500
echo Using interface: ${net0}

# Boot custom ISO with casper-firstboot
kernel ${iso-path} boot=casper \
    ip=dhcp \
    ds=nocloud;s=http://${server-ip}:${server-port}/seed/ \
    file=/cdrom/preseed/ubuntu.seed \
    quiet \
    splash \
    ---
    BOOT_IMAGE=/casper/vmlinuz

initrd /ubuntu/initrd
boot
```

#### 3. **Cloud-Init Configuration (First Boot Only)**

**user-data**:
```yaml
#cloud-config
hostname: ubuntu-server
manage_pty: true

package_update: true
package_upgrade: true

packages:
  - cloud-init
  - git
  - bash-completion
  - jq

users:
  - name: ubuntu
    lock_passwd: true
    shell: /bin/bash
  
  - name: admin
    lock_passwd: false
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    shell: /bin/bash
    ssh_authorized_keys:
      - "YOUR_SSH_RSA_KEY"

# FIRST BOOT ONLY - Run after system is booted
runcmd:
  - echo "=== Phase 1: Installing Rust Toolchain ==="
  - curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  - export PATH="$HOME/.cargo/bin:$PATH"
  
  - echo "=== Phase 2: Installing Application Dependencies ==="  
  - apt-get update
  - apt-get install -y --no-install-recommends \
      curl git build-essential pkg-config \
      nfs-common
  - rm -rf /var/lib/apt/lists/*
  
  - echo "=== Phase 3: Creating Deployment User ==="
  - sudo useradd -m -s /bin/bash deployer || true
  - echo "deployer:password123" | sudo chpasswd
  - echo "deployer ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/deployer
  
  - echo "=== Phase 4: Setting up NFS Client ==="
  - echo "$NFS_SERVER:/data/deployment /data/nfs  nfs vers=4,nr 0 0" | sudo tee -a /etc/fstab
  
  - echo "=== Phase 5: Applying Configurations ==="
  - sudo mkdir -p /data/nfs /opt/applications
  
  - echo "=== Phase 6: Fetching and Building Application ==="
  - cd /tmp
  - git clone https://github.com/your-org/your-app.git
  - cd your-app
  - curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  - export PATH="$HOME/.cargo/bin:$PATH"
  - cargo build --release
  - sudo install -m 0755 target/release/your-app /usr/local/bin/your-app
  - sudo chmod +x /usr/local/bin/your-app
  
  - echo "=== Phase 7: Creating Systemd Service ==="
  - sudo cat > /etc/systemd/system/your-app.service <<EOF
[Unit]
Description=Your Rust Application
After=network.target

[Service]
Type=simple
User=deployer
WorkingDirectory=/opt/applications/your-app
ExecStart=/usr/local/bin/your-app
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
  - sudo systemctl daemon-reload
  - sudo systemctl enable your-app.service

final_message: "Ubuntu 24.04 Server configured successfully via cloud-init."

# Prevent cloud-init from running again on subsequent boots
commands:
  - echo "0 cloud-init.per-services start" | sudo tee /etc/crontab > /dev/null || true

# System configuration - disable cloud-init auto-run
system_info:
  package_update: true
  package_upgrade: true
```

**meta-data**:
```yaml
instance-id: ubuntu-server-24.04
local-hostname: ubuntu-server
```

#### 4. **Boot-Only Script for First Boot**

Create `/iso/casper/first-boot.sh`:
```bash
#!/bin/bash
# Runs ONLY on first boot (via systemd)

# Clean cloud-init state to prevent re-running
rm -rf /var/lib/cloud/instance || false
rm -rf /var/lib/cloud/seed || false
rm -rf /var/lib/cloud/first-boot || false

# Verify deployment
if [ -f /usr/local/bin/your-app ]; then
    echo "✓ Application deployed successfully"
    echo "✓ System ready for use"
    systemctl status your-app.service
else
    echo "✗ Application deployment failed"
    exit 1
fi
```

#### 5. **First Boot Service**

Create `/etc/systemd/system/casper-firstboot.service`:
```ini
[Unit]
Description=Casper First Boot Setup
BindsTo=cloud-init.service
After=cloud-init.service

[Service]
Type=oneshot
ExecStart=/iso/casper/first-boot.sh
ExecStartPost=/bin/sleep 5

[Install]
WantedBy=multi-user.target
```

#### 6. **App Layer Runtime Deployment**

**No app layer needed!** Apps are deployed during cloud-init first boot.

If future apps want to be deployed:

```bash
# On the deployment server - deploy new app
cd /data/deployment/app-name
cargo build --release
./deploy.sh

# This app will be available to fresh boots
```

### **Stateless Boot Process**

**First Boot (Initialize → App Deploy → NFS Setup → Done)**
```
iPXE → ISO Boot → First Boot → Rust Install → App Build → NFS Mount → Boot Complete ✓
```

**Subsequent Reboots (Instant Clean Boot)**
```
iPXE → ISO Boot → Clean Ubuntu → Boot Complete (instant)
```

### **Build Structure**

```
docker/
├── custom-iso/
│   └── Dockerfile          # Ubuntu ISO generator
├── apps/
│   └── Dockerfile          # Optional - build Rust apps into /opt/apps
├── nginx.conf             # Serves ISO and seed files
└── docker-compose.yml     
```

### **NFS Persistence (Optional Manual)**

If you want NFS to persist across reboots:

```bash
# On the server (as root)
# Edit exports.conf
/data/deployment  192.168.1.0/24(ro,nfsvers=4,no_root_squash,nointr)

# On the new ISO, add to /etc/fstab (or cloud-init)
SERVER-IP:/data/deployment  /data/nfs  nfs  defaults,_netdev  0  0
```

### **Deployment Workflow**

1. **Build** custom ISO
2. **Serve** ISO + seed files via nginx
3. **PXE boot** target machine
4. **Wait ~3-5 minutes** for first boot (Rust install + app build)
5. **Reboot** - now stateless, instant boot
6. **Deploy apps** to NFS directory for next deployments

### **Why This Architecture?**

✅ **Truly Stateless** - every reboot is identical
✅ **Custom Kernel** - latest hardware support  
✅ **Runtime Build** - no frozen app versions in ISO
✅ **First-Boot Only** - no reconfiguration loops
✅ **Clean & Predictable** - standard Ubuntu ISO base
✅ **Flexible App Deployment** - deploy on demand

Does this architecture meet your needs? If yes, I'll proceed with the detailed implementation plan with all the file operations.