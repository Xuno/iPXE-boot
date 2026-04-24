# syntax=docker/dockerfile:1.7
FROM rust:1.86-bookworm AS builder

WORKDIR /src
COPY Cargo.toml Cargo.lock* ./
COPY src ./src

RUN --mount=type=cache,target=/usr/local/cargo/registry \
    --mount=type=cache,target=/src/target \
    cargo build --release

FROM base_image

WORKDIR /runtime

COPY --from=builder /src/target/release/hello-ipxe /runtime/hello-ipxe

VOLUME ["/out"]

CMD ["/bin/bash", "-lc", "cp -f /runtime/hello-ipxe /out/hello-ipxe && sha256sum /out/hello-ipxe > /out/hello-ipxe.sha256 && ls -lah /out"]
