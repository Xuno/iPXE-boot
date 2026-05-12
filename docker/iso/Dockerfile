FROM ubuntu:24.04

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
    && rm -rf /var/lib/apt/lists/*

COPY scripts/iso/build-iso.sh /build.sh

WORKDIR /root

RUN chmod +x /build.sh

VOLUME ["/out"]

CMD ["/build.sh"]
