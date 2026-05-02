#!/usr/bin/env bash
set -euo pipefail

# Map target triple to linux-runner qemu arch argument
case "$TARGET" in
armv7-*) ARCH=armv7hf ;;
riscv64gc-*) ARCH=riscv64 ;;
*)
    ARCH=${TARGET%%-*}
    ;;
esac

td=$(mktemp -d)
trap 'rm -rf "$td"' EXIT

cd "$td"

# Initialize a minimal Rust binary
cargo init --bin --name hello

# Build for the target
cross build --target "$TARGET"

# Create Cross.toml that runs the binary under valgrind inside the VM
cat >Cross.toml <<EOF
[target.${TARGET}]
runner = "/linux-runner ${ARCH} /usr/bin/valgrind --error-exitcode=1 --leak-check=full"
EOF

# Run under valgrind -- this exercises the full system path:
# cross → Docker → linux-runner → qemu-system → VM → dbclient → valgrind
cross run --target "$TARGET"

echo "Valgrind smoke test passed for $TARGET"
