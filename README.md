# iPXE-Boot

A Docker-based build system for creating a network-bootable iPXE live environment with independently upgradable layers.

## Overview

This project builds a complete iPXE boot stack—including the kernel, initrd, and layered filesystems—deployed via a local HTTP server for PXE network booting.

## Architecture

The architecture uses **Casper layering** to enforce runtime filesystem composition. This keeps the base OS and application layers independent and upgradable without merging them at build time. Instead, the layers are merged at boot time via the `layerfs-path` mechanism.

## Key Components

*   **Base OS (`docker/base/`)**:
    *   Builds the Ubuntu kernel (`vmlinuz`), initrd (`initrd.img`), and base OS filesystem (`filesystem.squashfs`).
*   **Apps Service (`docker/apps/`)**:
    *   Builds Rust application artifacts into a separate `apps.filesystem.squashfs` layer.
*   **HTTP Module (`docker/http/`)**:
    *   Serves iPXE boot scripts and versioned artifacts via Nginx using a `current` symlink.

## Key Technologies

*   **Orchestration**: Docker Compose
*   **Base OS**: Ubuntu
*   **Application Build**: Rust (with GPG signature verification)
*   **Boot Environment**: iPXE
*   **Runtime Layering**: Casper
*   **Filesystem**: SquashFS (compressed read-only)

## Configuration & Scripts

*   **`docker-compose.yml`**:
    *   Service orchestration.
    *   Supports Rust build arguments: `RUST_VERSION`, `RUST_ARCH`, and `RUST_SIGNING_FPR` (GPG fingerprint).
*   **`docker/build.sh`**:
    *   A wrapper script that executes the base OS build followed by the apps build sequentially using Docker Compose.
*   **Environment Variables**:
    *   `RUST_VERSION`: Specifies the Rust toolchain version.
    *   `RUST_ARCH`: Specifies the target architecture.
    *   `RUST_SIGNING_FPR`: Specifies the GPG key fingerprint for verification.
*   **`.env` files**: Store local environment defaults.

## Build Flow

1.  Run `docker/build.sh`.
2.  The script invokes the base OS build.
3.  The script invokes the apps build sequentially.