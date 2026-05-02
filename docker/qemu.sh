#!/usr/bin/env bash

# spell-checker: ignore libiscsi libnfs opengl werror lmount libz autoclean
# spell-checker: ignore malloc biosdir libzstd libssh libbz libfuse lseek
# spell-checker: ignore membarrier qcow vhost vdpa vvfat linuxboot kvmvapic
# spell-checker: ignore vgabios nvmm whpx mshv nsis nvram multiboot, qboot
# spell-checker: ignore bootrom npcm libxen openbios pnor ndrv skiboot slof
# spell-checker: ignore opensbi riscv

# Sources for building qemu:
# https://www.qemu.org/docs/master/about/build-platforms.html
# https://www.qemu.org/docs/master/devel/build-system.html
# https://wiki.qemu.org/Hosts/Linux

set -ex

# shellcheck disable=SC1091
. lib.sh

version="${QEMU_VERSION:?A qemu version should be present}"
qemu_arch="$1"
qemu_build_dir="${HOME}/qemu"

# These are the packages and libraries needed by the dynamically linked qemu.
# They should be added to `common.sh` Note that slirp is already built manually
# and installed:
# * libblkid1
# * libc6
# * libc6-dev
# * libffi8
# * libglib2.0
# * libglib2.0-dev
# * libmount1
# * libpcre2-8-0
# * zlib1g
# * libzstd1
# * libssh-4
# * libbz2-1.0
# * libxen-dev
# * fuse3

# These are the packages needed to build qemu. Mostly from
# https://packages.debian.org/source/stable/qemu
install_packages \
    bindgen \
    bison \
    debhelper \
    device-tree-compiler \
    fcode-utils \
    flex \
    g++ \
    libattr1-dev \
    libcap-ng-dev \
    libffi-dev \
    libpixman-1-dev \
    libselinux1-dev \
    libssl-dev \
    meson \
    ninja-build \
    pkg-config \
    python3 \
    python3-tomli \
    python3-sphinx \
    python3-sphinx-rtd-theme \
    python3-venv \
    rustc-web \
    xsltproc \
    xz-utils \
    zlib1g-dev \
    libzstd-dev \
    libssh-dev \
    libbz2-dev \
    libfuse3-dev \
    bzip2

mkdir -p "$qemu_build_dir"
cd "$qemu_build_dir"

wget "https://download.qemu.org/qemu-${version}.tar.xz"
tar xJf "qemu-${version}.tar.xz"
cd "qemu-${version}"

mkdir -p build
cd build

../configure \
    --without-default-features \
    --disable-docs \
    --disable-install-blobs \
    --disable-werror \
    --enable-kvm \
    --enable-tcg \
    --enable-plugins \
    --enable-xen \
    --enable-xen-pci-passthrough \
    --enable-attr \
    --enable-avx2 \
    --enable-avx512bw \
    --enable-bzip2 \
    --enable-fuse \
    --enable-fuse-lseek \
    --enable-hv-balloon \
    --enable-l2tpv3 \
    --enable-libssh \
    --enable-lto \
    --enable-malloc-trim \
    --enable-malloc=system \
    --enable-membarrier \
    --enable-qcow1 \
    --enable-qed \
    --enable-slirp \
    --enable-strip \
    --enable-vdi \
    --enable-vhost-crypto \
    --enable-vhost-kernel \
    --enable-vhost-net \
    --enable-vhost-user \
    --enable-vhost-user-blk-server \
    --enable-vhost-vdpa \
    --enable-virtfs \
    --enable-vmdk \
    --enable-vvfat \
    --enable-zstd \
    --prefix=/usr \
    --target-list="${qemu_arch}-softmmu,${qemu_arch}-linux-user"

dest_dir=/qemu
make -j"$(nproc)"
mkdir -p "$dest_dir"
make install DESTDIR="$dest_dir"

# We haven't installed all blobs to save around 300MB disk space.
biosdir="${dest_dir}/usr/share/qemu"
firmware_dir="${biosdir}/firmware"

mkdir -p "$biosdir" "${firmware_dir}"

# Common for all qemu architectures
cp ../pc-bios/*.rom \
    ../pc-bios/qemu-nsis.bmp \
    ../pc-bios/vof-nvram.bin \
    ../pc-bios/vof.bin \
    ../pc-bios/linuxboot*.bin \
    ../pc-bios/vgabios*.bin \
    "$biosdir"

case "$qemu_arch" in
i386 | x86_64)
    cp ../pc-bios/{kvmvapic,linuxboot,multiboot{,_dma},pvh}.bin \
        ../pc-bios/bios*.bin \
        "$biosdir"
    ;;
arm)
    cp ../pc-bios/npcm{7,8}xx_bootrom.bin \
        "$biosdir"
    bzip2 -d ../pc-bios/edk2-arm-*.bz2
    cp ../pc-bios/edk2-arm-* \
        "$biosdir"
    sed 's:@DATADIR@:/usr/share/qemu:' \
        ../pc-bios/descriptors/60-edk2-arm.json >"${firmware_dir}/60-edk2-arm.json"
    ;;
aarch64)
    bzip2 -d ../pc-bios/edk2-aarch64-*.bz2 ../pc-bios/edk2-arm-vars*.bz2
    cp ../pc-bios/edk2-aarch64-* \
        ../pc-bios/edk2-arm-vars* \
        "$biosdir"
    sed 's:@DATADIR@:/usr/share/qemu:' \
        ../pc-bios/descriptors/60-edk2-aarch64.json >"${firmware_dir}/60-edk2-aarch64.json"
    ;;
mips | mipsel | mips64el) ;;
ppc | ppc64)
    cp ../pc-bios/{openbios-ppc,pnv-pnor.bin,qemu_vga.ndrv,skiboot.lid,slof.bin,u-boot*} \
        "$biosdir"
    ;;
s390x)
    cp ../pc-bios/s390-ccw.img "$biosdir"
    ;;
riscv64)
    cp ../pc-bios/opensbi-riscv{32,64}*.bin "$biosdir"
    ;;
*)
    bail "Unsupported qemu architecture: '$qemu_arch'"
    ;;
esac

rm -rf "${qemu_build_dir}"

purge_packages

exit 0
