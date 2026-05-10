#!/usr/bin/env bash

set -x
set -eo pipefail

# shellcheck disable=SC1091
. lib.sh

max_kernel_version() {
    # kernel versions have the following format:
    #   `5.10.0-10-$arch`, where the `$arch` may be optional.
    local IFS=$'\n'
    local -a versions
    local major=0
    local minor=0
    local patch=0
    local release=0
    local index=0
    local version
    local x
    local y
    local z
    local r
    local is_larger

    read -r -d '' -a versions <<<"$1"
    for i in "${!versions[@]}"; do
        version="${versions[$i]}"
        x=$(echo "$version" | cut -d '.' -f 1)
        y=$(echo "$version" | cut -d '.' -f 2)
        z=$(echo "$version" | cut -d '.' -f 3 | cut -d '-' -f 1)
        r=$(echo "$version" | cut -d '-' -f 2)
        is_larger=

        if [ "$x" -gt "$major" ]; then
            is_larger=1
        elif [ "$x" -eq "$major" ] && [ "$y" -gt "$minor" ]; then
            is_larger=1
        elif [ "$x" -eq "$major" ] && [ "$y" -eq "$minor" ] && [ "$z" -gt "$patch" ]; then
            is_larger=1
        elif [ "$x" -eq "$major" ] && [ "$y" -eq "$minor" ] && [ "$z" -eq "$patch" ] && [ "$r" -gt "$release" ]; then
            is_larger=1
        fi

        if [ -n "$is_larger" ]; then
            index="$i"
            major="$x"
            minor="$y"
            patch="$z"
            release="$r"
        fi
    done

    echo "${versions[index]}"
}

main() {
    # arch in the rust target
    local arch="${1}" \
        kversion='6.*'

    local debsource
    local kernel=
    local libgcc="libgcc-s1"
    local ncurses=

    # select debian arch and kernel version
    case "${arch}" in
    aarch64)
        arch=arm64
        kernel="${kversion}-arm64"
        ;;
    armv7)
        arch=armhf
        kernel="${kversion}-armmp"
        ;;
    i686)
        arch=i386
        kernel="${kversion}-686"
        ;;
    mips)
        # mips was discontinued in bullseye, so we have to use buster.
        debsource="deb http://http.debian.net/debian/ buster main"
        debsource="${debsource}\ndeb http://security.debian.org/ buster/updates main"
        kernel='4.*-4kc-malta'
        ncurses="=6.1*"
        libgcc="libgcc1"
        ;;
    mipsel)
        kernel="${kversion}-4kc-malta"
        ;;
    mips64el)
        kernel="${kversion}-5kc-malta"
        ;;
    powerpc)
        kernel="7.*-powerpc"
        debsource="deb http://ftp.ports.debian.org/debian-ports unstable main"
        debsource="${debsource}\ndeb http://ftp.ports.debian.org/debian-ports unreleased main"
        ;;
    powerpc64)
        # there is no stable port
        arch=ppc64
        kernel="7.*-powerpc64"
        debsource="deb http://ftp.ports.debian.org/debian-ports unstable main"
        debsource="${debsource}\ndeb http://ftp.ports.debian.org/debian-ports unreleased main"
        ;;
    powerpc64le)
        arch=ppc64el
        kernel="${kversion}-powerpc64le"
        ;;
    riscv64)
        kernel="${kversion}-riscv64"
        ;;
    s390x)
        kernel="${kversion}-s390x"
        ;;
    x86_64)
        arch=amd64
        kernel="${kversion}-amd64"
        ;;
    *)
        echo "Invalid arch: ${arch}"
        exit 1
        ;;
    esac

    install_packages sharutils \
        gnupg

    if [[ -n "$debsource" ]]; then
        [[ -e /etc/apt/sources.list ]] && mv /etc/apt/sources.list /etc/apt/sources.list.bak
        mv /etc/apt/sources.list.d /etc/apt/sources.list.d.bak
        echo -e "${debsource}" >/etc/apt/sources.list
    fi

    # Old ubuntu does not support --add-architecture, so we directly change multiarch file
    if [ -f /etc/dpkg/dpkg.cfg.d/multiarch ]; then
        cp /etc/dpkg/dpkg.cfg.d/multiarch /etc/dpkg/dpkg.cfg.d/multiarch.bak
    fi
    dpkg --add-architecture "${arch}" || echo "foreign-architecture ${arch}" >/etc/dpkg/dpkg.cfg.d/multiarch

    # Use a single connection per url which is slower but should fix the
    # intermittent error: curl: (16) Error in the HTTP2 framing layer
    for url in \
        'https://www.ports.debian.org/archive_'{2020,2021,2022,2023,2024,2025,2026}.key \
        'https://ftp-master.debian.org/keys/release-'{7,8,9,10,11,12,13}.asc \
        'https://ftp-master.debian.org/keys/archive-key-'{8,9,10,11,12,13}-security.asc \
        'https://ftp-master.debian.org/keys/archive-key-'{7.0,8,9,10,11,12,13}.asc; do
        curl --retry 3 -sSfL "$url" -O
    done

    mkdir -p /etc/apt/trusted.gpg.d
    for key in *.asc *.key; do
        if [[ "${key}" == *.asc ]]; then
            gpg --dearmor <"${key}" >"/etc/apt/trusted.gpg.d/${key%.asc}.gpg"
        else
            gpg --dearmor <"${key}" >"/etc/apt/trusted.gpg.d/${key%.key}.gpg"
        fi
        rm "${key}"
    done

    # allow apt-get to retry downloads
    echo 'APT::Acquire::Retries "3";' >/etc/apt/apt.conf.d/80-retries

    apt-get update

    mkdir -p "/packages"
    chmod 777 "/packages"

    # Need to limit the kernel version and select the best version
    # if we have a wildcard. This is because some matches, such as
    # `linux-image-4.*-4kc-malta` can match more than 1 package,
    # which will prevent further steps from working.
    if [[ "$kernel" == *'*'* ]]; then
        packages=$(apt-cache search ^linux-image-"$kernel$" --names-only)
        names=$(echo "$packages" | cut -d ' ' -f 1)
        kversions="${names//linux-image-/}"
        kernel=$(max_kernel_version "$kversions")
    fi

    cd "/packages"

    # Download packages needed by image stage
    apt-get -d --no-install-recommends download \
        "busybox:${arch}" \
        "libc6-dbg:${arch}" \
        "libc6:${arch}" \
        "libcrypt-dev:${arch}" \
        "libcrypt1:${arch}" \
        "libgmp10:${arch}" \
        "libtomcrypt1:${arch}" \
        "libtommath1:${arch}" \
        "linux-image-${kernel}:${arch}" \
        ncurses-base"${ncurses}"

    if [[ "$arch" == "ppc64" || "$arch" == "powerpc" ]]; then
        apt-get -d --no-install-recommends download \
            "linux-base-${kernel}:${arch}" \
            "linux-binary-${kernel}:${arch}" \
            "linux-modules-${kernel}:${arch}"
    fi

    local dpkg_arch
    dpkg_arch=$(dpkg --print-architecture)
    local libgcc_packages=("${libgcc}:${arch}" "libstdc++6:${arch}")
    if [[ "${arch}" != "${dpkg_arch}" ]]; then
        apt-get -d --no-install-recommends download "${libgcc_packages[@]}"
    else
        # host arch has conflicting versions of the packages installed
        # this prevents us from downloading them, so we need to
        # simply grab the last version from the debian sources.
        # we're search for a paragraph with:
        #   Maintainer: Debian
        # but not
        #   Original-Maintainer: Debian
        #
        # then, we extract the version record and download **only**
        # packages matching that specific version.
        local version_info
        local version_record
        local version
        for package in "${libgcc_packages[@]}"; do
            version_info=$(apt-cache show "${package}")
            version_record=$(echo "${version_info}" | perl -n00e 'print if /^Maintainer: Debian/m')
            version=$(echo "${version_record}" | grep 'Version: ' | cut -d ' ' -f 2)
            apt-get -d --no-install-recommends download "${package}=${version}"
        done

    fi

    purge_packages
}

main "${@}"
