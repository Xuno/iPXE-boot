# iPXE-Boot Project

## Project Overview

A modern, production-ready iPXE boot system built on Ubuntu 24.04 LTS that enables quick, consistent system provisioning through cloud-init automation.

## Key Features

- **Custom Ubuntu 24.04 Live ISO**: Fully customizable, bootable operating system
- **Cloud-Init Automation**: Automatically configures and deploys applications on first boot
- **iPXE Network Boot**: Support for PXE and network-based boot configurations
- **Rust Application Support**: Integrated Rust toolchain for modern application deployment
- **Stateless Architecture**: Reboots are clean - no configuration persistence issues
- **NFS Provisioning**: Integrated NFS client for network storage access

## Architecture

```
┌──────────────┐    ┌──────────────────┐    ┌──────────────────┐
│   iPXE       │    │   Custom ISO     │    │ Cloud-Init       │
│   Boot       │───▶│  (Ubuntu 24.04)  │───▶│  Automation      │
└──────────────┘    └──────────────────┘    └──────────────────┘
                         │                         │
                         ▼                         ▼
                  ┌──────────────┐         ┌──────────────┐
                  │  First Boot  │         │  Rust Runtime│
                  │  (Install &  │         │  Application │
                  │   Deploy)    │         │   Build)     │
                  └──────────────┘         └──────────────┘
                         │                         │
                         ▼                         ▼
                  ┌──────────────┐         ┌──────────────┐
                  │  NFS Server  │         │  Stateless   │
                  │  Storage     │         │  System      │
                  └──────────────┘         └──────────────┘
```

## Tech Stack

- **Base OS**: Ubuntu 24.04 LTS
- **Boot System**: ISO + iPXE
- **Configuration**: Cloud-Init
- **Language**: Rust (for applications)
- **Build Tools**: Docker, xorriso, squashfs-tools

## Build Status

✅ **Core Functionality**: Complete and tested
✅ **ISO Builder**: Docker-based, reproducible builds
✅ **Cloud-Init**: Automated configuration and deployment
✅ **iPXE Integration**: Network boot support

## Current Version

**Version**: 1.0.0
**Release Date**: 2025
**Status**: Production Ready