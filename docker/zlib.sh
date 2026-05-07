#!/usr/bin/env bash

# spell-checker: ignore localoptions dbclient ddropbear cflags

set -ex

# shellcheck disable=SC1091
. lib.sh

version="${ZLIB_VERSION:?A dropbear version should be present}"
destdir="/zlib"
toolchain="${CROSS_TOOLCHAIN_PREFIX%-}"

if_debian install_packages wget patch

build_dir="${HOME}/zlib"
mkdir -p "$build_dir"
pushd "$build_dir"

wget "https://zlib.net/zlib-${version}.tar.gz"
tar xzf "zlib-${version}.tar.gz"
cd "zlib-${version}"

export CC="${toolchain}-gcc"
export LD="${toolchain}-ld"
export AR="${toolchain}-ar"

which "$CC" "$LD" "$AR"

export CHOST="$toolchain"

# Fixes a bug in the configure script for s390x targets
if [[ -f /zlib-s390x-vx.patch ]]; then
    patch -p1 </zlib-s390x-vx.patch
fi
./configure --static

make -j"$(nproc)"

make DESTDIR="$destdir" install

popd
rm -rf "$build_dir"

purge_packages
