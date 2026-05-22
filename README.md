# iPXE Bootable Ubuntu 24.04 LTS Diskless Server

A PXE boot solution for Ubuntu 24.04 LTS diskless servers using iPXE for HTTP boot, including a custom live-server ISO, SFC/virtio network driver support, MTU 9000, cloud-init, and optional NFS.

## Overview

This project provides an iPXE boot stack—including the kernel, initrd, and filesystem images—deployed via a local HTTP server for network booting. Designed for production diskless servers with 40G network infrastructure.

## Project Structure

- `docker/`: Contains build scripts, Dockerfiles, and `docker-compose` configurations.
- `docker/http/`: The content directory for the HTTP server, which serves iPXE boot files, scripts, and ISO images.
- `docs/`: Additional documentation.
- `nfs/`: NFS configuration files.

## Features

- **PXE Network Boot**: Boot servers from the network via iPXE.
- **40G Network Support**: SFC driver with MTU 9000 jumbo frames.
- **ISO-over-HTTP Boot**: Custom Ubuntu Server live ISO fetched by casper.
- **Diskless Operation**: No local storage required on the client nodes.
- **Production Ready**: Tested on physical hardware and VMs.

## Quick Start

### Build the System

```bash
cd docker
bash -c build.sh
```
or 
```bash
cd docker
docker compose --progress=plain up --build 
docker compose down
```

### Start HTTP Server

```bash
cd docker
docker compose -f docker-compose.http.yml up -d
```

### Boot a Node

1. **Configure DHCP/PXE Server**  
   Set up your DHCP/PXE server to point clients to the iPXE bootloader via TFTP. The bootloader file is located at
   `http/root/boot.efi` for UEFI systems.

2. **Power On the Server**  
   Enable PXE boot in the BIOS/UEFI settings and power on the target server.

3. **Load iPXE Bootloader**  
   The system's firmware loads `boot.efi` via PXE and executes the embedded iPXE script `autoexec.ipxe` (located at
   `http/root/autoexec.ipxe`).

4. **Redirect to Boot Menu**  
   The `autoexec.ipxe` script automatically redirects to `http://<server-ip>/boot.ipxe`, which is served by the Nginx HTTP server
   from `http/root/boot.ipxe`.

5. **Select Boot Option**  
   The `boot.ipxe` script presents a boot menu. By default, it boots "Ubuntu 24.04 Server custom ISO".

6. **Load Kernel and Initrd**  
   The server fetches the kernel (`/boots/ubuntu-custom-iso/casper/vmlinuz`), initial ramdisk (
   `/boots/ubuntu-custom-iso/casper/initrd`), and the custom ISO image (`/iso/ubuntu-24.04-custom.iso`) over HTTP.

7. **Initialize with Cloud-Init**  
   Cloud-init reads the NoCloud configuration data from `/boots/ubuntu-custom-iso/cloud-init/` to configure the system on first
   boot.

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

