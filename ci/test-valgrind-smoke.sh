#!/usr/bin/env bash
set -eo pipefail

ci_dir=$(dirname "${BASH_SOURCE[0]}")
ci_dir=$(realpath "${ci_dir}")

# shellcheck disable=SC1091
. "${ci_dir}"/shared.sh

CROSS=$(binary_path cross "${PROJECT_HOME}" debug)

td=$(mktemp -d)
trap 'rm -rf "$td"' EXIT

cd "$td"

# Initialize a minimal Rust binary
cargo init --bin --name hello

# Build for the target
"${CROSS[@]}" build --target "$TARGET"

# Create Cross.toml that runs the binary under valgrind inside the VM
cat >Cross.toml <<EOF
[target.${TARGET}.env]
passthrough = [
  "CROSS_VALGRIND=valgrind --tool=memcheck --error-exitcode=1 --leak-check=full"
]
EOF

# Run under valgrind -- this exercises the full system path:
# cross → Docker → linux-runner → qemu-system → VM → dbclient → valgrind
"${CROSS[@]}" run --target "$TARGET"

echo "Valgrind smoke test passed for $TARGET"
