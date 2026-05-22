ARG UBUNTU_VER=ubuntu:24.04
FROM ${UBUNTU_VER} AS base

ARG UBUNTU_VER
RUN echo "Building on top of ${UBUNTU_VER}"
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    file \
    gnupg \
    initramfs-tools \
    isolinux \
    rsync \
    squashfs-tools \
    xorriso \
    xz-utils \
    zstd \
    iproute2 \
    iputils-ping \
    host \
    jq \
    && rm -rf /var/lib/apt/lists/*

FROM base AS builder
COPY scripts/iso/build-iso.sh /build.sh
RUN chmod +x /build.sh
WORKDIR /root
VOLUME ["/out"]
CMD ["/build.sh"]
