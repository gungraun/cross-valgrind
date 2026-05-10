#!/usr/bin/env bash

set -x
set -euo pipefail

# shellcheck disable=SC1091
. lib.sh

install_packages \
    autoconf \
    automake \
    binutils \
    ca-certificates \
    curl \
    file \
    gcc \
    git \
    libtool \
    m4 \
    make

if_centos install_packages \
    clang-devel \
    gcc-c++ \
    gcc-gfortran \
    glibc-devel \
    pkgconfig

if_debian install_packages \
    fuse3 \
    g++ \
    gfortran \
    gzip \
    libblkid1 \
    libbz2-1.0 \
    libc6 \
    libc6-dev \
    libclang-dev \
    libffi8 \
    libglib2.0 \
    libglib2.0-dev \
    libmount1 \
    libpcre2-8-0 \
    libssh-4 \
    libxen-dev \
    libzstd1 \
    pkg-config \
    tar \
    util-linux \
    wget \
    zlib1g

if_debian prune_docs
