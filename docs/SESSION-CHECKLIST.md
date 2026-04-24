# Session Checklist

Use this at the start of a fresh session.

## 1) Confirm Working Directory
- Repo root: `iPXE-boot`
- Build commands run from: `iPXE-boot/docker`

## 2) Validate Compose
- `docker compose config --services`
- Expected services: `base-os`, `apps`

## 3) Validate Boot Script Parameters
- Open `docker/http/root/ubuntu/boot.ipxe`
- Confirm:
  - `url=.../filesystem.squashfs`
  - `layerfs-path=apps.filesystem.squashfs`

## 4) Validate Outputs
- Base outputs under `docker/http/boots/ubuntu/current/`:
  - `vmlinuz`
  - `initrd.img`
  - `filesystem.squashfs`
- App layer output:
  - `apps.filesystem.squashfs`

## 5) Build Order
1. Build base first (creates/updates `current`)
2. Build apps second (writes layer into `current`)

## 6) Security Check
- Rust installer signature verification enabled.
- `RUST_SIGNING_FPR` set in env if pinning is required.
