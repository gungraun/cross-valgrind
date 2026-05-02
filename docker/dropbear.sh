#!/usr/bin/env bash

# spell-checker: ignore localoptions dbclient ddropbear cflags

set -ex

# shellcheck disable=SC1091
. lib.sh

version="${DROPBEAR_VERSION:?A dropbear version should be present}"
dest_dir="/dropbear"
toolchain="${CROSS_TOOLCHAIN_PREFIX%-}"
debian_arch="$1"

# To be sure since we install dropbear statically on the host
apt-get purge -y dropbear

dpkg --add-architecture "${debian_arch}" || echo "foreign-architecture ${debian_arch}" >/etc/dpkg/dpkg.cfg.d/multiarch
if_debian install_packages \
    gnupg \
    wget \
    zlib1g \
    zlib1g-dev \
    zlib1g:"$debian_arch" \
    zlib1g-dev:"$debian_arch"

build_dir="${HOME}/dropbear"
mkdir -p "$build_dir"
pushd "$build_dir"

wget "https://github.com/mkj/dropbear/archive/refs/tags/DROPBEAR_${version}.tar.gz"
tar xzf "DROPBEAR_${version}.tar.gz"
cd "dropbear-DROPBEAR_${version}"

# Two builds. The first is for the host and the second for the image. The image
# build needs to be cross-compiled with the target triple.

# https://github.com/mkj/dropbear/blob/master/src/default_options.h
cp /dropbear_options.h localoptions.h

# Remove this unwanted message if it is present
sed -i '/skipping hostkey/d' src/cli-kex.c || true

common_opts=(
    "--prefix=/usr"
    "--enable-static"
    "--disable-lastlog"
    "--disable-pututline"
    "--disable-pututxline"
    "--disable-shadow"
    "--disable-syslog"
    "--disable-utmp"
    "--disable-utmpx"
    "--disable-wtmp"
    "--disable-wtmpx"
)

./configure "${common_opts[@]}"

make -j"$(nproc)" PROGRAMS="dbclient dropbearkey scp"
make PROGRAMS="dbclient dropbearkey scp" install

make clean

export CC="${toolchain}-gcc"
export LD="${toolchain}-ld"
export AR="${toolchain}-ar"

which "$CC" "$LD" "$AR"

./configure "${common_opts[@]}" \
    --host="$toolchain"

make -j"$(nproc)" PROGRAMS="dropbear scp"
make DESTDIR="$dest_dir" PROGRAMS="dropbear scp" install

popd
rm -rf "$build_dir"

purge_packages

exit 0
