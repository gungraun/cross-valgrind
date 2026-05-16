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
  "CROSS_VALGRIND=valgrind --tool=memcheck --vgdb=no"
]
EOF

# Initialize a minimal Rust binary
cargo init --bin --name hello

# Build for the target
"${CROSS[@]}" build --target "$TARGET"

# Run under valgrind -- this exercises the full system path:
# cross → Docker → linux-runner → qemu-system → VM → dbclient → valgrind
"${CROSS[@]}" run --target "$TARGET"

echo "Valgrind smoke test passed for $TARGET"
