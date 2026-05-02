#!/bin/bash

set -eux

export CC="${CROSS_TOOLCHAIN_PREFIX}gcc"
export LD="${CROSS_TOOLCHAIN_PREFIX}ld"
export AR="${CROSS_TOOLCHAIN_PREFIX}ar"

which "$CC" "$LD" "$AR"

[[ -n "$CROSS_TARGET" ]] || {
    echo "CROSS_TARGET environment variable is not defined"
    exit 1
}

HOST=
case $CROSS_TARGET in
riscv64gc-unknown-linux-gnu) HOST="riscv64-linux-gnu" ;;
*-*-*-*) HOST="$CROSS_TARGET" ;;
*-*-*) HOST="$CROSS_TARGET" ;;
*)
    echo "Invalid target specification for CROSS_TARGET: '$CROSS_TARGET'" >&2
    exit 1
    ;;
esac

install_packages wget lbzip2

cd

mkdir valgrind
cd valgrind
# FIX: retry
wget "https://sourceware.org/pub/valgrind/valgrind-${VALGRIND_VERSION}.tar.bz2"
wget "https://sourceware.org/pub/valgrind/sha512.sum"
sha256sum -c sha512.sum --ignore-missing | grep "^valgrind-${VALGRIND_VERSION}\s*:\s*OK"

tar xf valgrind-"${VALGRIND_VERSION}".tar.bz2

cd ~/valgrind/valgrind-"${VALGRIND_VERSION}"

dest_dir="/tmp/valgrind"
target_dir="/usr"

mkdir "$dest_dir"

./autogen.sh

# TODO: --enable-tls --enable-lto
# According to valgrind/configure file, the CROSS_TARGET is
# supported as is for the --host variable. If the target is not supported by
# valgrind, configure will exit with an error.
./configure --prefix="$target_dir" \
    --host="${HOST}"

make -"j$(nproc)" BUILD_DOCS=none
make install DESTDIR="$dest_dir"

cd
rm -rf valgrind/

exit 0
