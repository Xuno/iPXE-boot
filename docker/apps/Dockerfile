# syntax=docker/dockerfile:1.7
FROM base_image AS builder

ENV DEBIAN_FRONTEND=noninteractive
ARG RUST_VERSION
ARG RUST_ARCH=x86_64-unknown-linux-gnu
ARG RUST_DIST_BASE=https://static.rust-lang.org/dist
ARG RUST_KEY_URL=https://keybase.io/rust/pgp_keys.asc
ARG RUST_SIGNING_FPR
ENV PATH="/opt/rust/bin:${PATH}"
ENV CARGO_HOME=/home/builder/.cargo

RUN test -n "$RUST_VERSION" \
    && apt-get update && apt-get install -y --no-install-recommends \
       build-essential \
       ca-certificates \
       curl \
       gnupg \
       pkg-config \
       xz-utils \
       mc \
    && rm -rf /var/lib/apt/lists/* \
    && RUST_PKG="rust-${RUST_VERSION}-${RUST_ARCH}.tar.xz" \
    && curl -fsSLO "${RUST_DIST_BASE}/${RUST_PKG}" \
    && curl -fsSLO "${RUST_DIST_BASE}/${RUST_PKG}.asc" \
    && curl -fsSL -o /tmp/rust-key.asc "${RUST_KEY_URL}" \
    && gpg --batch --import /tmp/rust-key.asc \
    && if [ -n "${RUST_SIGNING_FPR}" ]; then gpg --batch --list-keys --with-colons "${RUST_SIGNING_FPR}" | grep -q '^fpr:'; fi \
    && gpg --batch --verify "${RUST_PKG}.asc" "${RUST_PKG}" \
    && tar -xJf "${RUST_PKG}" \
    && "./rust-${RUST_VERSION}-${RUST_ARCH}/install.sh" --prefix=/opt/rust --without=rust-docs \
    && rm -rf \
       "/rust-${RUST_VERSION}-${RUST_ARCH}" \
       "/${RUST_PKG}" \
       "/${RUST_PKG}.asc" \
       /tmp/rust-key.asc \
       /root/.gnupg

RUN useradd -m -u 10001 builder

WORKDIR /src
COPY --chown=builder:builder Cargo.toml Cargo.lock* ./
COPY --chown=builder:builder src ./src
RUN chown -R builder:builder /src

USER builder

RUN --mount=type=cache,target=/home/builder/.cargo/registry,uid=10001,gid=10001 \
    --mount=type=cache,target=/home/builder/.cargo/git,uid=10001,gid=10001 \
    --mount=type=cache,target=/src/target,uid=10001,gid=10001 \
    cargo build --release \
    && cp -f /src/target/release/hello-ipxe /tmp/hello-ipxe

FROM base_image AS runtime

WORKDIR /runtime
COPY --from=builder /tmp/hello-ipxe /runtime/hello-ipxe

VOLUME ["/out"]

CMD ["/bin/bash", "-lc", "set -euo pipefail; TARGET_DIR=/out/current; [ -d \"$TARGET_DIR\" ] || { echo \"Missing $TARGET_DIR. Build base-os first.\"; exit 1; }; rm -rf /tmp/app-layer && mkdir -p /tmp/app-layer/opt/apps; cp -f /runtime/hello-ipxe /tmp/app-layer/opt/apps/hello-ipxe; mksquashfs /tmp/app-layer \"$TARGET_DIR/apps.filesystem.squashfs\" -comp zstd -b 1M -noappend -no-recovery; sha256sum \"$TARGET_DIR/apps.filesystem.squashfs\" > \"$TARGET_DIR/apps.filesystem.squashfs.sha256\"; ls -lah \"$TARGET_DIR\""]
