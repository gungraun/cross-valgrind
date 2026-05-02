#!/usr/bin/env bash

set -ex

# shellcheck disable=SC1091
. lib.sh

if [[ -n "$1" ]] && [[ "$1" -eq "static" ]]; then
    static=true
else
    static=false
fi

version="${SLIRP_VERSION:?A slirp version should be present}"

build_dir="${HOME}/slirp"
mkdir -p "$build_dir"
pushd "$build_dir"

# List of build dependencies:
# https://gitlab.freedesktop.org/slirp/libslirp/-/blob/v4.9.1/.gitlab-ci.yml
install_packages \
    gcc \
    libglib2.0-dev \
    meson \
    ninja-build \
    pkg-config \
    zlib1g

wget "https://gitlab.freedesktop.org/slirp/libslirp/-/archive/v${version}/libslirp-v${version}.tar.gz"
tar xzf "libslirp-v${version}.tar.gz"
cd "libslirp-v${version}"

if $static; then
    meson setup --default-library static build
    ninja -C build
    install -m 644 build/libslirp.a /usr/lib64/
else
    meson setup --prefix /usr build
    ninja -C build install
fi

popd
rm -rf "$build_dir"

exit 0
