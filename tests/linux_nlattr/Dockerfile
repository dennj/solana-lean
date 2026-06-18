FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    bc \
    bison \
    build-essential \
    ca-certificates \
    clang \
    clang-19 \
    cmake \
    cpio \
    file \
    flex \
    git \
    libelf-dev \
    libgmp-dev \
    libssl-dev \
    libuv1-dev \
    lld \
    lld-19 \
    llvm \
    llvm-19 \
    llvm-19-dev \
    make \
    perl \
    pkg-config \
    python3 \
    qemu-system-misc \
    rsync \
    xz-utils \
  && rm -rf /var/lib/apt/lists/*
