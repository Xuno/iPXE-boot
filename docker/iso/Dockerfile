FROM ubuntu:24.04

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    xorriso squashfs-tools syslinux genisoimage zstd \
    && rm -rf /var/lib/apt/lists/*

COPY scripts/iso/build-iso.sh /build.sh
COPY iso /data

WORKDIR /root

RUN chmod +x /build.sh
