#!/usr/bin/env bash

# spell-checker: ignore localoptions dbclient ddropbear cflags

set -ex

# shellcheck disable=SC1091
. lib.sh

version="${DROPBEAR_VERSION:?A dropbear version should be present}"
dest_dir="/dropbear"
toolchain="${CROSS_TOOLCHAIN_PREFIX%-}"

# To be sure since we install dropbear statically on the host
apt-get update
apt-get purge -y dropbear

if_debian install_packages \
    gnupg \
    wget \
    zlib1g \
    zlib1g-dev

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

zlib_dir=/tmp/zlib/usr/local
mkdir zlibincludes
mv "$zlib_dir/include/"{zlib,zconf}.h zlibincludes/

# Extract libcrypt-dev from pre-downloaded packages
libcrypt_deb=$(find /tmp/packages -name "libcrypt-dev_*.deb" | head -1)
mkdir -p /tmp/libcrypt-dev
dpkg -x "$libcrypt_deb" /tmp/libcrypt-dev

libcrypt_incdir=$(find /tmp/libcrypt-dev -name "crypt.h" -exec dirname {} \;)
libcrypt_libdir=$(find /tmp/libcrypt-dev -name "libcrypt.a" -exec dirname {} \;)

mkdir libcrypt_includes
mv "${libcrypt_incdir}/crypt.h" libcrypt_includes/
CFLAGS="-I$(pwd)/zlibincludes -I$(pwd)/libcrypt_includes"
export CFLAGS
export LDFLAGS="-L${zlib_dir}/lib -L${libcrypt_libdir}"
export LIBS="${zlib_dir}/lib/libz.a ${libcrypt_libdir}/libcrypt.a"
# bypass the configure check
export ac_cv_func_crypt=yes
export ac_cv_lib_crypt_crypt=yes

./configure "${common_opts[@]}" \
    --host="$toolchain"

make -j"$(nproc)" PROGRAMS="dropbear scp"
make DESTDIR="$dest_dir" PROGRAMS="dropbear scp" install

popd
rm -rf "$build_dir"

purge_packages

exit 0
