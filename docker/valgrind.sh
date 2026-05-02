#!/bin/bash

set -euxo pipefail

# shellcheck disable=SC1091
. lib.sh

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

strip_quotes() {
    local s="$1"
    # Only strip if the string is fully wrapped in matching quotes
    if [[ "$s" == \"*\" ]]; then
        s="${s#\"}"
        s="${s%\"}"
    elif [[ "$s" == \'*\' ]]; then
        s="${s#\'}"
        s="${s%\'}"
    fi
    printf '%s' "$s"
}

IFS=' ' read -ra configure_args <<<"$(strip_quotes "${VALGRIND_CONFIGURE_ARGS}")"
IFS=' ' read -ra configure_extra_args <<<"$(strip_quotes "${VALGRIND_CONFIGURE_EXTRA_ARGS}")"
IFS=' ' read -ra make_extra_args <<<"$(strip_quotes "${VALGRIND_MAKE_EXTRA_ARGS}")"
IFS=' ' read -r cflags <<<"$(strip_quotes "${VALGRIND_CFLAGS}")"

install_packages wget lbzip2 patch

cd

mkdir valgrind
cd valgrind

asset_name=valgrind-${VALGRIND_VERSION}
asset="${asset_name}.tar.bz2"

wget "https://sourceware.org/pub/valgrind/${asset}"
wget "https://sourceware.org/pub/valgrind/sha512.sum"
sha512sum -c sha512.sum --ignore-missing | grep "^${asset}\s*:\s*OK"

tar xf "${asset}"

cd ~/valgrind/"${asset_name}"

if [[ -f /valgrind-mips64-sa_flags.patch ]]; then
    patch -p1 </valgrind-mips64-sa_flags.patch
fi

dest_dir="/valgrind"
mkdir -p "$dest_dir"

if [[ -n "$cflags" ]]; then
    export CFLAGS="${cflags}"
fi

# According to valgrind/configure file, the CROSS_TARGET is supported as is for
# the --host variable. If the target is not supported by valgrind, configure
# will exit with an error.
./configure "${configure_args[@]}" \
    --host="${HOST}" \
    "${configure_extra_args[@]}"

make -"j$(nproc)" BUILD_DOCS=none "${make_extra_args[@]}"
make install DESTDIR="$dest_dir"

cd
rm -rf valgrind/

purge_packages

exit 0
