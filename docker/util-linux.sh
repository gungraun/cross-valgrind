#!/usr/bin/env bash

# spell-checker: ignore btrfs poman libuuid

set -ex

# shellcheck disable=SC1091
. lib.sh

version="${UTIL_LINUX_VERSION:?A util-linux version should be present}"
# The main version without the patch version. The patch version can be absent.
main_version="$(IFS=. read -r major minor _ <<<"$version" && echo -n "${major}.${minor}")"

dest_dir="/util-linux"
toolchain="${CROSS_TOOLCHAIN_PREFIX%-}"

build_dir="${HOME}/util-linux"
mkdir -p "$build_dir"
pushd "$build_dir"

wget "https://www.kernel.org/pub/linux/utils/util-linux/v${main_version}/util-linux-${version}.tar.gz"
tar xzf "util-linux-${version}.tar.gz"
cd "util-linux-${version}"

export CC="${toolchain}-gcc"
export LD="${toolchain}-ld"
export AR="${toolchain}-ar"

which "$CC" "$LD" "$AR"

# Disable as much as possible without using --disable-all-programs. There's no
# switch to turn on `setarch` again and that's the only program we actually need
# in the qemu image.

# spell-checker: disable
./configure \
    --host="$toolchain" \
    --prefix /usr \
    --disable-agetty \
    --disable-asciidoc \
    --disable-bash-completion \
    --disable-bfs \
    --disable-blkid \
    --disable-cal \
    --disable-chfn-chsh \
    --disable-chfn-chsh-password \
    --disable-chmem \
    --disable-chsh-only-listed \
    --disable-cramfs \
    --disable-dmesg \
    --disable-eject \
    --disable-enosys \
    --disable-exch \
    --disable-fallocate \
    --disable-fdisks \
    --disable-fsck \
    --disable-fstrim \
    --disable-hardlink \
    --disable-hexdump \
    --disable-hwclock \
    --disable-hwclock-cmos \
    --disable-hwclock-gplv3 \
    --disable-ipcmk \
    --disable-ipcrm \
    --disable-ipcs \
    --disable-irqtop \
    --disable-kill \
    --disable-last \
    --disable-libblkid \
    --disable-libfdisk \
    --disable-liblastlog2 \
    --disable-libmount \
    --disable-libmount-mountfd-support \
    --disable-libsmartcols \
    --disable-libuuid \
    --disable-logger \
    --disable-login \
    --disable-losetup \
    --disable-lsblk \
    --disable-lscpu \
    --disable-lsfd \
    --disable-lsirq \
    --disable-lslogins \
    --disable-lsmem \
    --disable-lsns \
    --disable-mesg \
    --disable-minix \
    --disable-mkfs \
    --disable-more \
    --disable-mount \
    --disable-mount \
    --disable-mountpoint \
    --disable-nologin \
    --disable-nsenter \
    --disable-option-checking \
    --disable-pam-lastlog2 \
    --disable-partx \
    --disable-pg-bell \
    --disable-pipesz \
    --disable-pivot_root \
    --disable-plymouth_support \
    --disable-poman \
    --disable-pylibmount \
    --disable-raw \
    --disable-rename \
    --disable-rfkill \
    --disable-runuser \
    --disable-schedutils \
    --disable-scriptutils \
    --disable-setpriv \
    --disable-setterm \
    --disable-su \
    --disable-sulogin \
    --disable-swapon \
    --disable-switch_root \
    --disable-ul \
    --disable-unshare \
    --disable-utmpdump \
    --disable-uuidd \
    --disable-uuidgen \
    --disable-waitpid \
    --disable-wall \
    --disable-wdctl \
    --disable-whereis \
    --disable-wipefs \
    --disable-zramctl \
    --without-btrfs \
    --without-python \
    --without-systemd \
    --without-udev
# spell-checker: enable

make -j"$(nproc)"
make DESTDIR="$dest_dir" install

cd
rm -rf "$build_dir"

exit 0
