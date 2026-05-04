# iPXE Bootable Ubuntu 24.04 LTS Diskless Server

A production-ready PXE boot solution for Ubuntu 24.04 LTS diskless servers using iPXE for HTTP boot, SFC network driver for 40G networks (MTU 9000), and layered SquashFS filesystems.

## Overview

This project builds a complete iPXE boot stack—including the kernel, initrd, and layered filesystems—deployed via a local HTTP server for PXE network booting. Designed for production diskless servers with 40G network infrastructure (Sonic switch).

## Key Features

- **PXE Network Boot** - Boot servers from network via iPXE
- **40G Network Support** - SFC driver with MTU 9000 jumbo frames
- **Layered Filesystem** - SquashFS with overlay and NFS layers
- **Diskless Operation** - No local storage required
- **Multi-Node Support** - Deploy on multiple nodes simultaneously
- **Production Ready** - Tested on physical hardware and VMs

## Quick Start

### Build the System

```bash
cd docker
docker compose up --build base-os
docker compose up --build apps
```

### Start HTTP Server

```bash
docker compose -f docker-compose.http.yml up -d
```

### Boot a Node

1. Configure DHCP server to point to: `http://<server-ip>:8080/ubuntu/boot.ipxe`
2. Power on server with PXE enabled
3. Server boots into Ubuntu 24.04 LTS

## Architecture

```
┌──────────────┐
│  HTTP Server │
│   (Nginx)    │
└──────┬───────┘
       │
       │ iPXE boot
       ▼
┌──────────────┐
│  iPXE Boot   │
│  - HTTP fetch│
│  - SFC driver│
│  - MTU 9000  │
└──────┬───────┘
       │
       │ Load SquashFS
       ▼
┌──────────────┐
│  Ubuntu Root │
│  - Base FS   │
│  - App Layer │
│  - Overlay   │
│  - NFS       │
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ Diskless     │
│ Server       │
└──────────────┘
```

## Components

- **iPXE Bootloader** - Custom iPXE with SFC driver and MTU 9000 support
- **HTTP Server** - Nginx serving boot scripts and filesystems
- **Ubuntu 24.04 LTS** - Base OS in SquashFS format
- **Layered Filesystem** - Base + apps + overlay + NFS layers
- **SFC Driver** - Standard SFC driver for Sonic switch 40G NICs
- **Testing Framework** - Unit and integration tests without Docker

## Testing

Run tests directly on hardware/VMs:

```bash
cd tests
make test  # Run all tests
make unit  # Run unit tests
make test-ipxe  # Run iPXE boot tests
```

## Documentation

- [Deployment Guide](docs/DEPLOYMENT.md) - Complete deployment instructions
- [Troubleshooting Guide](docs/TROUBLESHOOTING.md) - Common issues and fixes
- [Layered Filesystem](docs/layered-filesystem.md) - Layer configuration details
- [Project Analysis](PROJECT_ANALYSIS.md) - Component breakdown

## Requirements

- Physical servers with 40G NICs (Sonic switch compatible)
- TFTP server (optional, iPXE can boot via HTTP)
- HTTP server (Nginx) configured
- Network infrastructure with DHCP and PXE support
- Sonic switch configured for jumbo frames

## Quick Links

- Build: `docker/build.sh`
- Test: `tests/test-ipxe-boot.sh all`
- HTTP Server: `docker/docker-compose.http.yml`

## License

This project is provided as-is for production use.

## Support

For issues or questions, refer to the [Troubleshooting Guide](docs/TROUBLESHOOTING.md) or check the test suite output.