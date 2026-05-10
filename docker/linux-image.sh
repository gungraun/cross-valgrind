#!/usr/bin/env bash

set -x
set -eo pipefail

# shellcheck disable=SC1091
. lib.sh

main() {
    # select debian arch
    local arch="$1"
    case "${arch}" in
    aarch64)
        arch=arm64
        ;;
    armv7)
        arch=armhf
        ;;
    i686)
        arch=i386
        ;;
    powerpc64)
        arch=ppc64
        ;;
    powerpc64le)
        arch=ppc64el
        ;;
    x86_64)
        arch=amd64
        ;;
    mips | mipsel | mips64el | powerpc | riscv64 | s390x)
        ;;
    *)
        echo "Invalid arch: ${arch}"
        exit 1
        ;;
    esac

    install_packages cpio \
        sharutils

    local pkgdir="/tmp/packages"

    mkdir -p /qemu
    cd /qemu

    # Install packages into rootfs
    root="root-${arch}"
    mkdir -p "${root}"/{bin,etc/dropbear,root,sys,dev,proc,sbin,tmp,usr/{bin,sbin},var/log}
    for deb in "${pkgdir}"/*.deb; do
        dpkg -x "${deb}" "${root}"/
    done

    # Install dropbear
    cp -a /tmp/dropbear/* "${root}"/
    rm -rf /tmp/dropbear

    dropbearkey -t rsa -f "${root}/etc/dropbear/dropbear_rsa_host_key"
    dropbearkey -t ecdsa -f "${root}/etc/dropbear/dropbear_ecdsa_host_key"
    dropbearkey -t ed25519 -f "${root}/etc/dropbear/dropbear_ed25519_host_key"

    # Install util-linux/setarch
    cp -a /tmp/util-linux/setarch "${root}"/usr/bin/
    rm -rf /tmp/util-linux

    cp "${root}/boot/vmlinu"* kernel

    # initrd
    mkdir -p "${root}/modules"
    if ls -d "${root}/usr/lib/modules"/*/kernel; then
        prefix='/usr'
    else
        prefix=''
    fi
    cp -v \
        "${root}${prefix}/lib/modules"/*/kernel/drivers/net/net_failover.ko* \
        "${root}${prefix}/lib/modules"/*/kernel/drivers/net/virtio_net.ko* \
        "${root}${prefix}/lib/modules"/*/kernel/drivers/virtio/* \
        "${root}${prefix}/lib/modules"/*/kernel/fs/netfs/netfs.ko* \
        "${root}${prefix}/lib/modules"/*/kernel/fs/9p/9p.ko* \
        "${root}${prefix}/lib/modules"/*/kernel/fs/fscache/fscache.ko* \
        "${root}${prefix}/lib/modules"/*/kernel/net/9p/9pnet.ko* \
        "${root}${prefix}/lib/modules"/*/kernel/net/9p/9pnet_virtio.ko* \
        "${root}${prefix}/lib/modules"/*/kernel/net/core/failover.ko* \
        "${root}/modules" || true # some file may not exist
    rm -rf "${root:?}/boot"
    rm -rf "${root:?}${prefix}/lib/modules"

    cat <<'EOF' >"${root}/etc/hosts"
127.0.0.1 localhost qemu
EOF

    cat <<'EOF' >"$root/etc/hostname"
qemu
EOF

    cat <<'EOF' >"$root/etc/passwd"
root::0:0:root:/root:/bin/sh
EOF

    # dropbear complains when this file is missing
    touch "${root}/var/log/lastlog"

    if [[ -e "${root}/usr/bin/busybox" ]]; then
        busybox='/usr/bin/busybox'
    else
        busybox='/bin/busybox'
    fi
    cat <<EOF >"${root}/init"
#!${busybox} sh

set -ex

${busybox} --install

mkdir -p /dev /proc /run /sys /tmp

mount -t devtmpfs none /dev
mount -t proc proc /proc
mount -t sysfs sys /sys

mkdir -p /dev/pts
mount -t devpts none /dev/pts

mount -t tmpfs none /run
mkdir -p /run/lock

mount -t tmpfs none /tmp

mount

# some archs does not have virtio modules
# fscache is builtin on riscv64
insmod /modules/failover.ko || insmod /modules/failover.ko.xz || true
insmod /modules/net_failover.ko || insmod /modules/net_failover.ko.xz || true
insmod /modules/virtio.ko || insmod /modules/virtio.ko.xz || true
insmod /modules/virtio_ring.ko || insmod /modules/virtio_ring.ko.xz || true
insmod /modules/virtio_mmio.ko || insmod /modules/virtio_mmio.ko.xz || true
insmod /modules/virtio_pci_legacy_dev.ko || insmod /modules/virtio_pci_legacy_dev.ko.xz || true
insmod /modules/virtio_pci_modern_dev.ko || insmod /modules/virtio_pci_modern_dev.ko.xz || true
insmod /modules/virtio_pci.ko || insmod /modules/virtio_pci.ko.xz || true
insmod /modules/virtio_net.ko || insmod /modules/virtio_net.ko.xz || true
insmod /modules/netfs.ko || insmod /modules/netfs.ko.xz || true
insmod /modules/fscache.ko || insmod /modules/fscache.ko.xz || true
insmod /modules/9pnet.ko || insmod /modules/9pnet.ko.xz
insmod /modules/9pnet_virtio.ko || insmod /modules/9pnet_virtio.ko.xz || true
insmod /modules/9p.ko || insmod /modules/9p.ko.xz

ip addr add 127.0.0.1/8 dev lo
ip link set lo up

ip addr add 10.0.2.15/24 dev eth0
ip link set eth0 up

ip route add default via 10.0.2.2 dev eth0

mkdir /target
mount -t 9p -o trans=virtio target /target -oversion=9p2000.u || true

mkdir /opt
mount -t 9p -o trans=virtio valgrind /opt -oversion=9p2000.u || true

exec dropbear -F -B
EOF

    if [[ "${arch}" == "riscv64" ]]; then
        # Symlink dynamic loader to /lib/ld-linux-riscv64-lp64d.so.1
        mkdir -p "${root}/lib"
        ln -s /usr/lib/riscv64-linux-gnu/ld-linux-riscv64-lp64d.so.1 "${root}/lib/ld-linux-riscv64-lp64d.so.1"
    elif [[ "${arch}" == "ppc64" ]]; then
        # Fixing the error: Kernel panic - not syncing: No working init found.
        mkdir -p "${root}/lib64"
        ln -s /usr/lib/powerpc64-linux-gnu/ld64.so.1 "${root}/lib64/ld64.so.1"
    elif [[ "${arch}" == "powerpc" ]]; then
        # Fixing the error: Kernel panic - not syncing: No working init found.
        mkdir -p "${root}/lib"
        ln -s /usr/lib/powerpc-linux-gnu/ld.so.1 "${root}/lib/ld.so.1"
    fi

    chmod +x "${root}/init"
    cd "${root}"
    find . | cpio --create --format='newc' --quiet | gzip >../initrd.gz
    cd -

    # Clean up
    rm -rf "/qemu/${root}" "$pkgdir"
    ls -lh /qemu
}

main "${@}"
