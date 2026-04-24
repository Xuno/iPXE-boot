# Troubleshooting

This file captures common failures seen in this project and the practical fix.

## 1) `no such service: base-os`

### Symptom
- Running `docker compose ... base-os` fails with:
- `no such service: base-os`

### Cause
- Command executed from wrong directory, so another compose project is used.

### Fix
- Run from `docker/`:
- `cd docker`
- `docker compose config --services`
- Expected: `base-os`, `apps`

## 2) Rust build fails with lockfile permission error

### Symptom
- `failed to write /src/Cargo.lock`
- `Permission denied (os error 13)`

### Cause
- `/src` created as root; build runs as `builder`.

### Fix
- Ensure Dockerfile has:
- `RUN chown -R builder:builder /src`
- before `USER builder`.

## 3) `COPY --from=builder ... hello-ipxe: not found`

### Symptom
- Runtime stage copy fails because file not present.

### Cause
- Binary built into a cache-mounted location or wrong expected path.

### Fix
- In builder stage, copy artifact to stable path after build:
- `cp -f /src/target/release/hello-ipxe /tmp/hello-ipxe`
- In runtime stage:
- `COPY --from=builder /tmp/hello-ipxe /runtime/hello-ipxe`

## 4) Concern: `curl | sh` for rustup is unsafe

### Symptom
- Security risk identified: remote script as root.

### Fix
- Use standalone Rust archive with GPG verification:
1. Download `rust-<version>-<arch>.tar.xz` and `.asc`
2. Import trusted Rust release key
3. `gpg --verify ...`
4. Install from verified archive

## 5) GPG warning: `key is not certified with a trusted signature`

### Symptom
- Build log shows warning after good signature.

### Cause
- Fresh container keyring has no web-of-trust path.

### Fix
- Pin fingerprint in env:
- `RUST_SIGNING_FPR=108F66205EAEB0AAA8DD5E1C85AB96E6FA1BE5FE`
- Good signature + fingerprint pinning is expected model in CI/container.

## 6) App layer not applied at runtime

### Symptom
- App files missing after boot.

### Cause
- `boot.ipxe` missing `layerfs-path` kernel arg or wrong layer filename.

### Fix
- In `docker/http/root/ubuntu/boot.ipxe`, ensure:
- `url=${base-boots-url}/filesystem.squashfs`
- `layerfs-path=apps.filesystem.squashfs`

## 7) Independent layer upgrades not working

### Symptom
- App changes require rebuilding base image.

### Cause
- App layer merged into base squashfs during base build.

### Fix
- Keep layers independent:
1. Build `base-os` to create/update `current`
2. Build `apps` to write `apps.filesystem.squashfs` into `current`
3. Boot with `layerfs-path=<leaf-layer>`

## 8) Casper multi-layer naming confusion

### Symptom
- Unsure how to chain multiple layers.

### Rule
- Casper computes parent layers by stripping dotted prefixes from `layerfs-path` leaf.

### Example
- Leaf: `feature.apps.filesystem.squashfs`
- Required files:
1. `filesystem.squashfs`
2. `apps.filesystem.squashfs`
3. `feature.apps.filesystem.squashfs`

All must exist in the same boot directory (`boots/ubuntu/current`).

## 9) Quick recovery commands

From `docker/`:
1. `docker compose down`
2. `docker compose --progress=plain up --build base-os`
3. `docker compose --progress=plain up --build apps`
4. Check `http/boots/ubuntu/current/` contents
