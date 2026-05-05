# Architecture Documentation

## System Design

### Boot Flow

```
1. iPXE Network Boot
   ├─ DHCP Discovery
   ├─ IP Configuration
   ├─ MTU Negotiation (9000 for 40G networks)
   └─ ISO Download Selection

2. ISO Boot Process
   ├─ BIOS/UEFI Selection
   ├─ Load Isolinux/GRUB Kernel
   ├─ Load Initramfs (initrd)
   ├─ Execute Casper Startup
   ├─ Unpack SquashFS Filesystem
   ├─ Mount Filesystem
   └─ Execute Cloud-Init

3. First Boot Experience
   ├─ Install Rust Toolchain (first time only)
   ├─ Build/Deploy Applications
   ├─ Configure NFS Clients
   ├─ Set up Admin User
   └─ Reboot for Stateful System

4. Subsequent Boots
   ├─ Direct Boot from Stateful System
   ├─ Run Pre-installed Applications
   ├─ No Additional Configuration Needed
   └─ Clean Reboot (Stateless)
```

### Component Architecture

#### Build System (Docker)

```yaml
ubuntu-24.04-base:
  - Ubuntu 24.04 LTS base image
  - Docker Compose orchestration
  - Base OS generation (vmlinuz, initrd, squashfs)

rust-apps:
  - Rust toolchain installation
  - Application compilation
  - Layered application filesystem

iso-builder:
  - XORRISO for ISO creation
  - SquashFS generation
  - Boot configuration
```

#### Boot Components

**1. iPXE Scripts**
```ipxe
set timeout=10
set base-url=http://server/iso
set boots-url=http://server/boots/ubuntu/current
set layer-leaf=apps.filesystem.squashfs
```

**2. ISO Structure**
```
ubuntu-24.04-custom.iso
├── /isolinux/
│   ├── isolinux.bin (bootloader)
│   ├── boot.cat (catalog)
│   └── isolinux.cfg (menu)
├── /boot/grub/
│   ├── grub.cfg (boot menu)
│   └── efi grub
├── /casper/
│   ├── filesystem.squashfs (rootfs)
│   ├── vmlinuz (kernel)
│   └── initrd (initramfs)
└── /.disk/
    └── info (disk metadata)
```

**3. Cloud-Init Configuration**
```yaml
# First boot automation
package_update: true
package_upgrade: true
runcmd:
  - Install dependencies
  - Configure network
  - Setup users
  - Deploy applications
```

## Data Flow

### During Build

```
Developer
    ↓
Docker Compose
    ↓
Base OS Build
    ├── Compile Linux Image (vmlinuz)
    ├── Build Initramfs (initrd)
    └── Create SquashFS (filesystem.squashfs)
    ↓
Application Build
    ├── Install Rust Toolchain
    └── Compile Applications
    ↓
ISO Assembly
    ├── Combine Base + Apps
    ├── Create ISO Metadata
    └── Generate Boot Files
```

### During Runtime (First Boot)

```
Network Boot Trigger
    ↓
iPXE (PXE/iPXE Protocol)
    ↓
IP Assignment & Network Setup
    ↓
Load ISO Bootloaders
    ↓
Load Kernel & Initramfs
    ↓
Execute SquashFS Mount
    ↓
Cloud-Init Automation Trigger
    ↓
Application Deployment Pipeline
    ├── Rust Toolchain Installation
    ├── Application Compilation
    ├── Service Configuration
    └── NFS Client Setup
    ↓
Stateful System Creation
    ↓
First Reboot
    ↓
Stateless System Operation
```

## State Management

### Stateful State (First Boot)
- Rust toolchain installed (no longer needed)
- Applications compiled and installed
- NFS clients configured
- Admin user created with credentials
- System ready for production use

### Stateless State (Subsequent Boots)
- Applications already present (no re-deployment)
- Network configuration (cloud-init done)
- User credentials configured (cloud-init done)
- Clean, predictable boot behavior

## Security Considerations

### Build Security
- Rust toolchain from official download with GPG verification
- Docker image builds in isolated environment
- No untrusted external dependencies
- Pre-seeded package sources (Ubuntu APT)

### Runtime Security
- Admin user with proper password
- SSH server configuration (future)
- Firewall rules (future)
- System hardening (future)

## Performance Optimization

### Network
- MTU set to 9000 for 40G networks (Jumbo Frames)
- iPXE timeout configured (10 seconds)
- Fast network boot protocol

### Storage
- SquashFS compression (zstd)
- Minimal filesystem size optimization
- Efficient boot from ISO

### Boot
- No configuration persistence (clean reboots)
- Parallel application builds
- Cached Rust toolchain (once per first boot)

## Extensibility Points

### Easy Modification Areas

1. **Cloud-Init Configuration**
   - Location: `scripts/cloud/deploy-cloud-init.sh`
   - Modify: Application deployment commands, user creation, package lists

2. **Application Stack**
   - Location: `docker/apps/`
   - Add: New Docker containers for application services
   - Mount: Additional volumes for application data

3. **Boot Configuration**
   - Location: `iso/` and `scripts/boot/boot.ipxe`
   - Customize: Boot menu items, timeouts, network settings
   - Add: Custom iPXE scripts for additional functionality

4. **Build System**
   - Location: `docker/docker-compose.yml`
   - Scale: Add more build services for larger applications
   - Optimize: Parallel builds for faster iteration cycles

## Known Limitations

1. **First Boot Time**
   - 3-5 minutes for first boot (includes Rust installation and compilation)
   - Subsequent boots: < 30 seconds

2. **Network Dependency**
   - First boot requires network connectivity
   - Requires DNS/HTTP server for ISO delivery

3. **Storage Space**
   - ISO size: ~100MB
   - Runtime system: ~500MB-1GB depending on applications

4. **Platform Support**
   - x86_64 architecture only
   - BIOS and UEFI supported
   - No ARM support currently

## Future Roadmap

### Planned Enhancements

**Phase 1: Production Features**
- [ ] HTTPS support for ISO delivery
- [ ] System hardening (SELinux/AppArmor)
- [ ] Automated update mechanism
- [ ] Health check endpoints

**Phase 2: Advanced Features**
- [ ] Multiple application containers
- [ ] Load balancing support
- [ ] Database integration
- [ ] Kubernetes readiness

**Phase 3: Developer Experience**
- [ ] Hot-reload for applications
- [ ] Local development integration
- [ ] Automated testing pipeline
- [ ] CI/CD integration

### Planned Improvements

**Performance**
- [ ] Faster Rust compilation
- [ ] Parallel application builds
- [ ] Caching mechanisms

**Usability**
- [ ] Improved iPXE menu options
- [ ] Multi-language support
- [ ] Enhanced logging
- [ ] Remote management interface

## Troubleshooting Guide

### Common Issues

**Issue**: First boot stuck after cloud-init
- **Solution**: Check logs in `/var/log/cloud-init/`
- **Verify**: Network connectivity and DNS resolution

**Issue**: ISO won't boot
- **Solution**: Verify ISO integrity, check boot order
- **Test**: Boot into rescue mode if needed

**Issue**: Applications not starting
- **Solution**: Check service logs, verify dependencies
- **Debug**: Run applications manually to see errors

**Issue**: NFS connection fails
- **Solution**: Verify NFS server accessibility
- **Check**: Firewall rules and MTU settings

## Contact & Support

For questions or issues:
- Repository Issues
- Documentation updates
- Architecture questions

---

*Last Updated: 2025*
*Version: 1.0.0*