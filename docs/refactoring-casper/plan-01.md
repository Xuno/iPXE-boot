## 🎯 Refactoring Plan: Ubuntu 24.04 ISO Boot with iPXE

### **Core Architecture Change**

**FROM**: Layered squashfs (filesystem + apps layer) → **TO**: Ubuntu ISO casper boot with cloud-init

### **Required Changes**

#### 1. **iPXE Boot Script Updates**

Replace current `boot.ipxe` with proper Ubuntu ISO casper boot:

```ipxe
#!ipxe
set server-ip 192.168.1.100
set server-port 8080
set base-url http://${server-ip}:${server-port}/ubuntu
set iso-name ubuntu-24.04-server-amd64.iso
set iso-filename ${iso-name}

echo ===========================================
echo Ubuntu 24.04 LTS ISO PXE Boot
echo ===========================================

dhcp net0 || exit 1

echo Fetching boot parameters...

# Set MTU
set net0/mtu 1500

# Boot Ubuntu ISO with casper protocol
kernel http://${base-url}/${iso-filename} \
    boot=casper \
    ip=dhcp \
    ds=nocloud;s=http://${base-url}/seed/ \
    file=/cdrom/preseed/ubuntu.seed \
    quiet \
    splash \
    noapic \
    nodma \
    nomodeset \
    --- \
    BOOT_IMAGE=/casper/vmlinuz

initrd http://${base-url}/initrd
boot
```

#### 2. **Cloud-Init Configuration**

Create these files in HTTP root:
- `docker/http/root/ubuntu/seed/user-data`
- `docker/http/root/ubuntu/seed/meta-data`
- `docker/http/root/ubuntu/seed/cloud-config`

**user-data**:
```yaml
#cloud-config
 
hostname: ubuntu-server
manage_pty: true
package_update: true
package_upgrade: true

users:
  - name: admin
    lock_passwd: false
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    shell: /bin/bash
    ssh_authorized_keys:
      - "YOUR_SSH_KEY_HERE"

runcmd:
  - echo "=== Installing Rust Toolchain ==="
  - curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable
  - source $HOME/.cargo/env
  - rustup component add cargo-clippy cargo-fmt rustfmt
  
  - echo "=== Setting up NFS client ==="
  - apt-get install -y nfs-common
  
  - echo "=== Creating mount point ==="
  - mkdir -p /data/nfs
  
  - echo "=== Deploying application ==="
  - cd /opt
  - git clone https://github.com/your-org/your-app.git
  - cd your-app
  - curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  - source $HOME/.cargo/env
  - cargo install --locked

final_message: "Diskless Ubuntu Server setup complete"
```

**meta-data**:
```yaml
instance-id: ubuntu-24.04-pxe
local-hostname: ubuntu-server
```

**cloud-config** (optional):
```yaml
#cloud-config
apt:
  primary:
    - arches: [default]
      uri: http://archive.ubuntu.com/ubuntu/
```

#### 3. **Docker Build Updates**

**Base Dockerfile**:
```dockerfile
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Install Ubuntu ISO components
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        xorriso \
        ca-certificates \
        cloud-init \
        linux-image-generic \
        initramfs-tools \
        squashfs-tools \
    && rm -rf /var/lib/apt/lists/*

# Prepare ISO root hierarchy
RUN mkdir -p /iso/casper /iso/casper/dist /iso/preseed

WORKDIR /iso
```

**Apps Dockerfile** (Simplified):
```dockerfile
FROM base_image AS builder

# Build your Rust application
WORKDIR /src
COPY *.rs Cargo.toml* ./
COPY src ./src

RUN cargo build --release

# Runtime layer - don't include in ISO
WORKDIR /runtime
COPY --from=builder target/release/app ./app

ENTRYPOINT ["/bin/bash", "-lc", "echo 'App layer built. Use ISO boot for runtime deployment.'"]
```

#### 4. **Build Script Refactor**

**docker/build.sh**:
```bash
#!/bin/bash
set -euo pipefail

# Build ISO
DOCKER_BUILDKIT=1 docker build -f docker/base/Dockerfile \
    -t ubuntu-iso:24.04 \
    --build-arg OS_VERSION=24.04 \
    .

# Copy ISO to HTTP server
cp ubuntu-iso.iso docker/http/ubuntu/

# Build apps layer
docker build -f docker/apps/Dockerfile \
    --build-arg RUST_VERSION=stable \
    --build-arg RUST_ARCH=x86_64-unknown-linux-gnu \
    .

echo "Build complete. ISO and app layer ready."
```

#### 5. **HTTP Directory Structure Update**

```
docker/http/
├── ubuntu/
│   ├── ubuntu-24.04-server-amd64.iso
│   ├── initrd              # Pre-installed initrd from ISO
│   └── seed/
│       ├── user-data
│       ├── meta-data
│       └── cloud-config
└── nginx.conf            # Update to serve ISO and seed files
```

#### 6. **NFS Configuration (Manual)**

Document NFS mount setup for after-boot configuration:

```bash
# On deployment server
/data/deployment  192.168.1.0/24(ro,nfsvers=4,no_root_squash,nointr)

# On Ubuntu client (via cloud-init or manual)
apt-get install -y nfs-common
mount -t nfs -o vers=4,nolock SERVER-IP:/data/deployment /data/nfs
```

### **Deployment Flow**

1. **iPXE** fetches `boot.ipxe`
2. **iPXE** downloads Ubuntu ISO from HTTP server
3. **iPXE** passes `ds=nocloud;s=URL` to kernel
4. **Cloud-init** runs from HTTP URL (no-data.yaml, meta-data)
5. **System** performs:
   - Configures hostname
   - Creates admin user with SSH key
   - Installs Rust toolchain
   - Builds and deploys your Rust application
   - Installs NFS client
   - Sets up mount points
6. **First reboot** completes deployment

### **Key Advantages**

✅ **Standard Ubuntu ISO** → Works reliably in real PXE environments
✅ **Cloud-init automation** → Handles all deployment steps automatically
✅ **Runtime Rust build** → App can be updated after deployment
✅ **Simplified network** → DHCP automatically set by cloud-init
✅ **Manual NFS** → Flexible persistent storage option

### **Implementation Order**

1. Create HTTP directory structure with seed files
2. Refactor iPXE boot script for ISO boot
3. Update Dockerfiles for ISO building
4. Update nginx.conf to serve new structure
5. Test cloud-init user-data syntax
6. Build and verify ISO boot

Would you like me to proceed with this refactoring?