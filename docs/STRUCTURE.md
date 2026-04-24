# Project Structure

## Root
- `.env`, `.env.example`: local environment defaults.
- `AGENTS.md`: persistent context for new sessions.
- `docker/`: build/runtime assets.

## docker/
- `docker-compose.yml`: orchestrates `base-os` and `apps`.
- `build.sh`: convenience wrapper for ordered builds.
- `.env.example`: app-layer build arguments.

## docker/base/
- `Dockerfile`: Ubuntu base OS image for live boot payload.

## docker/entrypoint/
- `build.sh`: builds kernel/initrd/base squashfs, updates `current` symlink.

## docker/apps/
- `Dockerfile`: Rust app builder + app layer squashfs producer.
- `Cargo.toml`, `src/main.rs`: sample Rust app template.

## docker/http/
- `root/`: nginx-served iPXE scripts.
- `boots/ubuntu/`: versioned boot payloads + `current` symlink.
- `iso/`: optional ISO assets.
