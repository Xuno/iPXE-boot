# Quick Start Guide

## For New Developers

This guide will help you get up and running with the iPXE-Boot project quickly.

## Prerequisites

- Docker (version 20.10+)
- Git
- QEMU (optional, for testing)
- 1GB+ RAM and 10GB+ disk space

## Installation

### 1. Clone the Repository
```bash
git clone <repository-url>
cd iPXE-boot
```

### 2. Verify Docker Installation
```bash
docker --version
docker-compose --version
```

## Quick Start

### Build the Custom Ubuntu ISO

1. **Build the Docker Image**
```bash
cd docker/iso
docker build -t ubuntu-iso-builder .
```

2. **Generate the ISO**
```bash
docker run --rm \
  -v $(pwd)/../iso:/iso \
  ubuntu-iso-builder /iso/build-iso.sh
```

3. **Verify ISO Generation**
```bash
ls -lh iso/ubuntu-24.04-custom-*.iso
```

### Test the ISO

#### Option 1: Using QEMU (Recommended)
```bash
qemu-system-x86_64 \
  -cdrom iso/ubuntu-24.04-custom-*.iso \
  -m 2G \
  -nographic
```

#### Option 2: Using Physical Machine
1. Burn ISO to USB/thumb drive
2. Change BIOS boot order to boot from USB
3. Press Enter to confirm

#### Option 3: Network Boot
1. Configure iPXE server
2. Set up boot parameters
3. Boot from network

## First Boot Experience

### What Happens on First Boot?

1. **Cloud-Init Automates Everything**
   - Installs Rust toolchain (first time only)
   - Builds and deploys applications
   - Configures NFS clients
   - Sets up administrator user

2. **You'll See Output**
   - Installation progress
   - Build logs
   - Configuration messages

3. **System Reboots Automatically**
   - After first boot completes
   - System is now "stateful" and ready

### Subsequent Boot

- **Faster Boot**: < 30 seconds
- **No Further Setup**: Applications already installed
- **Clean Reboot**: No configuration persistence

## Common Development Tasks

### Modify Applications

1. **Edit Your Rust Apps**
```bash
# Find your application location
vim resources/rustapps/app-1/src/main.rs

# Recompile
cd resources/rustapps/app-1
cargo build --release
```

2. **Update ISO Build**
```bash
# The build script automatically picks up new applications
docker run --rm -v $(pwd)/iso:/iso ubuntu-iso-builder /iso/build-iso.sh
```

### Customize Cloud-Init

Edit the cloud-config:
```bash
vim resources/cloud-init/cloud-config.yaml
```

Common customizations:
- Add/remove packages
- Change application deployment order
- Modify admin user credentials
- Add custom commands

### Recreate the ISO

```bash
# Clean previous ISO
rm -f iso/ubuntu-24.04-custom-*.iso

# Run build script
./scripts/iso/build-iso.sh
```

## Project Structure

```
iPXE-boot/
├── iso/                          # Boot files and ISO output
│   ├── isolinux/                 # BIOS boot loader
│   ├── boot/                     # GRUB EFI bootloader
│   ├── rootfs/                   # Filesystem root
│   └── *.iso                     # Generated bootable ISO
├── resources/                    # Project resources
│   ├── cloud-init/               # System automation
│   ├── preseed/                  # Installation settings
│   └── rustapps/                 # Application code
├── scripts/                      # Automation scripts
│   ├── boot/                     # iPXE configuration
│   ├── cloud/                    # Deployment scripts
│   └── iso/                      # ISO build utilities
└── docker/                       # Build configuration
    ├── docker-compose.yml        # Orchestration
    └── iso/                      # ISO builder image
```

## Key System Components

### 1. iPXE Boot Script
Location: `scripts/boot/boot.ipxe`
Purpose: Network boot configuration

### 2. ISO Structure
Location: `iso/`
Purpose: Bootable operating system

### 3. Cloud-Init Configuration
Location: `resources/cloud-init/cloud-config.yaml`
Purpose: First-boot automation scripts

### 4. Application Stack
Location: `resources/rustapps/`
Purpose: Rust application code

## Understanding the Boot Flow

```
Network Boot
    ↓
iPXE Script
    ↓
Ubuntu ISO
    ↓
Cloud-Init (First Time)
    ├─ Install Rust
    ├─ Deploy Apps
    └─ Configure NFS
    ↓
First Reboot
    ↓
Stateful System
    ↓
Subsequent Boots
    ↓
Stateless System
```

## Troubleshooting

### Issue: Docker Build Fails
**Solution**:
```bash
# Clean and rebuild
docker system prune -a
docker build -f docker/iso/Dockerfile -t ubuntu-iso-builder . --no-cache
```

### Issue: ISO Won't Boot
**Solution**:
- Verify ISO file integrity
- Check boot order in BIOS/UEFI
- Try alternative boot method (USB vs. network)
- Enable verbose mode in iPXE

### Issue: Cloud-Init Hangs
**Solution**:
- Check network connectivity
- Verify DNS resolution
- Review cloud-init logs: `/var/log/cloud-init/`
- Ensure proper permissions

### Issue: First Boot Too Slow
**Expected**: First boot ~3-5 minutes (includes Rust install)
**Subsequent**: Fast boots <30 seconds

## Performance Tuning

### Network
- Set MTU to 9000 for 40G networks
- Verify network connectivity
- Test boot on local network first

### Storage
- Ensure 10GB+ disk for first boot
- Space for applications
- Temporary files cleanup

### Memory
- Minimum 1GB RAM
- Recommended 2GB+ for applications
- 4GB+ for development

## Development Workflow

### Adding a New Application

1. **Create your Rust application**
```bash
# Follow standard Rust structure
cd resources/rustapps
cargo new my-new-app
cd my-new-app
cargo build --release
```

2. **Update cloud-init**
```bash
# Add your app name to deployment list
vim resources/cloud-init/cloud-config.yaml
# Look for: deploy-apps runcmd section
```

3. **Rebuild ISO**
```bash
./scripts/iso/build-iso.sh
```

4. **Test**
```bash
qemu-system-x86_64 -cdrom iso/ubuntu-24.04-custom-*.iso -nographic
```

### Testing Without ISO

While you need the ISO for real boot testing, you can modify apps while keeping ISO unchanged because:

1. Applications are compiled on first boot
2. System is stateful after first boot
3. Modifying apps doesn't affect boot process
4. Only affects subsequent first boots

### Updating Production System

1. Make code changes in `resources/rustapps/`
2. Rebuild ISO with `./scripts/iso/build-iso.sh`
3. Deploy new ISO to target
4. System automatically updates on first boot

## FAQ

**Q: Do I need to rebuild the ISO every time?**
A: Only when you change applications or need to test on fresh machine

**Q: Can I develop locally without the ISO?**
A: Yes, applications are built on the target system

**Q: What's the recovery procedure?**
A: Just boot the ISO again and let cloud-init reconfigure

**Q: How do I access the system after boot?**
A: Default admin user with credentials set by cloud-init

**Q: Can I use this for multiple machines?**
A: Yes, just provision a fresh ISO on each machine

## Next Steps

1. ✅ Review architecture documentation
2. ✅ Understand boot flow
3. ✅ Test ISO boot
4. ✅ Modify and experiment
5. ✅ Deploy to production

## Support

For detailed documentation:
- See `README.md` - Project overview
- See `architecture.md` - System design
- See `tasks.md` - Development history
- Check logs: `journalctl -f`

---

*Remember: The first boot will take 3-5 minutes for initial setup. After that, system boots in <30 seconds.*