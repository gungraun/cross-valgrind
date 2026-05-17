#!/usr/bin/env bash
set -exo pipefail

ci_dir=$(dirname "${BASH_SOURCE[0]}")
ci_dir=$(realpath "${ci_dir}")

# shellcheck disable=SC1091
. "${ci_dir}"/shared.sh

# Unset RUSTFLAGS
export RUSTFLAGS=""

export QEMU_STRACE=1

CROSS=$(binary_path cross "${PROJECT_HOME}" debug)
export CROSS=("${CROSS}")
export CROSS_FLAGS="-v"

td=$(mktemp -d)
trap 'rm -rf "$td"' EXIT

cd "$td"

cat <<EOF >Cross.toml
[target.${TARGET}]
runner = "qemu-system"
EOF

case "$TARGET" in
mips64el-unknown-linux-gnuabi64 | mipsel-unknown-linux-gnu)
    CROSS+=("+nightly")
    echo 'build-std = true' >>Cross.toml
    ;;
esac

# Create Cross.toml that runs the binary under valgrind inside the VM
cat <<EOF >>Cross.toml
[target.${TARGET}.env]
passthrough = [
  "CROSS_VALGRIND"
]
EOF

# Initialize a minimal Rust binary
cargo init --bin --name hello

# Build for the target
"${CROSS[@]}" build --target "$TARGET"

# Run under memcheck -- this exercises the full system path:
# cross → Docker → linux-runner → qemu-system → VM → dbclient → valgrind
export CROSS_VALGRIND="valgrind --tool=memcheck --vgdb=no"
"${CROSS[@]}" run --target "$TARGET"

# Run under callgrind with cache simulation with --cache-sim
# and explicit cache settings. This covers the s390x fallback path
# for QEMU systems that expose unusable ECAG cache geometry.

export CROSS_VALGRIND="valgrind --tool=callgrind --vgdb=no --cache-sim=yes \
--I1=32768,8,64 --D1=32768,8,64 --LL=8388608,16,64 \
--callgrind-out-file=callgrind.out"

case "$TARGET" in
# Callgrind hangs forever on this target.
mipsel-unknown-linux-gnu)
    echo "Skipping callgrind test for ${TARGET}"
    ;;
*)
    "${CROSS[@]}" run --target "$TARGET"
    ;;
esac

echo "Valgrind smoke test passed for $TARGET"
