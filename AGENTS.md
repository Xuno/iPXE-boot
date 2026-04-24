# iPXE Boot Project Context

This file is a fast-start context for new sessions in this repository.

## Goal
- Build an upgradable iPXE live boot system with independently upgradable runtime layers.
- Use Docker Compose in `docker/` as the build orchestrator.

## Current Architecture
- `base-os` service builds:
  - `vmlinuz`
  - `initrd.img`
  - `filesystem.squashfs`
  - output into `docker/http/boots/ubuntu/<timestamp>/` and updates `current` symlink.
- `apps` service builds Rust app artifacts and produces:
  - `apps.filesystem.squashfs`
  - into `docker/http/boots/ubuntu/current/`
- iPXE boot script passes casper `layerfs-path` for runtime layering.

## Key Runtime Layering Rule
- Do **not** merge app layer into base squashfs at build time.
- Use casper layering at boot time (`layerfs-path=...`) so layers remain independently upgradable.

## Important Files
- Compose: `docker/docker-compose.yml`
- Build wrapper: `docker/build.sh`
- Base image build script: `docker/entrypoint/build.sh`
- Base Dockerfile: `docker/base/Dockerfile`
- App layer Dockerfile: `docker/apps/Dockerfile`
- iPXE scripts:
  - `docker/http/root/boot.ipxe`
  - `docker/http/root/ubuntu/boot.ipxe`

## How To Build
From `docker/`:
1. `docker compose --progress=plain up --build base-os`
2. `docker compose --progress=plain up --build apps`

Or run:
1. `./build.sh`

## Boot Behavior
- `boot.ipxe` should point to:
  - `url=${base-boots-url}/filesystem.squashfs`
  - `layerfs-path=apps.filesystem.squashfs`

Casper resolves layers by dotted parent chain. Naming must follow this rule.

## Security Decisions
- Rust toolchain install uses standalone Rust tarball with GPG signature verification.
- Key fingerprint pinning is supported by `RUST_SIGNING_FPR`.

## Env/Args For Apps Build
- `RUST_VERSION`
- `RUST_ARCH`
- `RUST_DIST_BASE`
- `RUST_KEY_URL`
- `RUST_SIGNING_FPR`

See `docker/.env.example`.

## Known Operational Notes
- Run compose commands from `docker/` directory.
- Keep generated HTTP artifacts out of git where possible.
- If app layer build fails with permissions in `/src`, ensure `/src` ownership is `builder:builder` in Dockerfile.

## Next Improvements (Optional)
- Version app layers per release instead of always writing only to `current`.
- Add integrity manifest combining base + app layer hashes for rollout/rollback checks.
