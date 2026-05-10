# `cross-valgrind`

Drop-in replacement images for [`cross`][cross] with Valgrind installed.

This repository is an image-focused fork of `cross-rs/cross` for a subset of
`cross` targets which Valgrind supports. For most users, the recommended setup
is still the upstream `cross` CLI with image overrides pointing at images built
from this repository.

This project is in an alpha development stage. The version number is based on
the valgrind version inside the image and doesn't reflect the development
progress.

## Goals

- Provide drop-in replacement images for targets which are supported by
  Valgrind
- Make Valgrind available for cross-target execution.
- Modernize important tool versions in the image stack.

## Non-Goals

- This repository is not about changing the `cross` user experience or
  extending the upstream `cross` binary.
- Become a general-purpose fork of `cross` with divergent behavior.
- Track every upstream image or binary change immediately.
- Replace the upstream documentation for normal `cross` usage.

## What Is Different From Upstream

- Recent Debian-based images (>=Bookworm) instead of Ubuntu-based images
  (>=20.04)
- Valgrind included in the image stack (which results in bigger image sizes)
- newer QEMU, more recent Linux kernel
- a `qemu-system` execution path that can run the target binary under Valgrind

## Choosing Images

There are two practical ways to use images from this repository:

- override a specific target in `Cross.toml`
- override a specific target with `CROSS_TARGET_<TRIPLE>_IMAGE`

`CROSS_IMAGE` is not recommended as a general user setup path in this fork.
This repository uses image tags that do not reliably line up with the binary's
built-in default image version.

Valgrind uses the `qemu-system` runner. The runner can be configured explicitly
per target:

```toml
[target.aarch64-unknown-linux-gnu]
runner = "qemu-system"
```

```sh
export CROSS_TARGET_AARCH64_UNKNOWN_LINUX_GNU_RUNNER=qemu-system
```

or let `cross-valgrind` select it automatically when `CROSS_VALGRIND` is set.

## Quick Start

Install the normal `cross` CLI first:

```sh
cargo install cross
```

Then point your targets at images built from this repository.

### Option 1: `Cross.toml`

```toml
[target.aarch64-unknown-linux-gnu]
image = "ghcr.io/gungraun/aarch64-unknown-linux-gnu:latest"

[target.aarch64-unknown-linux-gnu.env]
passthrough = [
    "CROSS_VALGRIND=valgrind --tool=memcheck",
]
```

### Option 2: Environment Variables

```sh
export CROSS_TARGET_AARCH64_UNKNOWN_LINUX_GNU_IMAGE="ghcr.io/gungraun/aarch64-unknown-linux-gnu:latest"
export CROSS_VALGRIND="valgrind --tool=memcheck"
```

Then use `cross` as usual:

```sh
cross test --target aarch64-unknown-linux-gnu
```

## Using Valgrind

Valgrind support uses `qemu-system`. The `qemu-user` runner is not supported
for Valgrind execution. If `CROSS_VALGRIND` is set and no runner is configured,
`cross-valgrind` selects `qemu-system` automatically.

You must set `CROSS_VALGRIND` to the Valgrind command and arguments that should
run inside the guest system. For example:

```sh
export CROSS_VALGRIND="valgrind --tool=memcheck"
```

When set in the calling shell, `CROSS_VALGRIND` is passed through
automatically.

A working `Cross.toml` example looks like this:

```toml
[target.aarch64-unknown-linux-gnu]
image = "ghcr.io/gungraun/aarch64-unknown-linux-gnu:latest"

[target.aarch64-unknown-linux-gnu.env]
passthrough = [
    "CROSS_VALGRIND=valgrind --tool=memcheck",
]
```

Use `passthrough` when you want to store the Valgrind command in `Cross.toml`
instead of relying on the caller's shell environment.

Or with shell configuration only:

```sh
export CROSS_TARGET_AARCH64_UNKNOWN_LINUX_GNU_IMAGE="ghcr.io/gungraun/aarch64-unknown-linux-gnu:latest"
export CROSS_VALGRIND="valgrind --tool=memcheck"

cross run --target aarch64-unknown-linux-gnu
```

## Default Image Namespace via `CROSS_IMAGE`

This option is discouraged. If you build or use a `cross` binary from this fork
with `CROSS_IMAGE=ghcr.io/gungraun`, the default image resolution can point at
this repository's image namespace without per-target overrides.

`CROSS_IMAGE` only changes the image namespace. The default tag still comes
from the binary's built-in `DEFAULT_IMAGE_VERSION`, which does not reliably
match this repository's published image tags.

## Image Tags

This repository publishes a small set of tags.

- `main`: image built from the `main` branch
- `edge`: additional branch-build tag as produced by the current tagging logic
- `latest`: most recent stable image release
- `3.27.0-1`: stable image release tag derived from the git tags `v3.27.0-1`

Examples:

```text
ghcr.io/gungraun/aarch64-unknown-linux-gnu:main
ghcr.io/gungraun/aarch64-unknown-linux-gnu:edge
ghcr.io/gungraun/aarch64-unknown-linux-gnu:latest
ghcr.io/gungraun/aarch64-unknown-linux-gnu:3.27.0-1
```

## Supported Targets

This repository only provides a stripped-down set of images compared to
upstream `cross`.

| Target                            |
| --------------------------------- |
| `x86_64-unknown-linux-gnu`        |
| `i686-unknown-linux-gnu`          |
| `aarch64-unknown-linux-gnu`       |
| `armv7-unknown-linux-gnueabihf`   |
| `mipsel-unknown-linux-gnu`        |
| `mips64el-unknown-linux-gnuabi64` |
| `powerpc-unknown-linux-gnu`       |
| `powerpc64-unknown-linux-gnu`     |
| `powerpc64le-unknown-linux-gnu`   |
| `riscv64gc-unknown-linux-gnu`     |
| `s390x-unknown-linux-gnu`         |

## Validation

This repository runs the original CI tests and an additional Valgrind smoke
test.

## Contributing

Contributions are welcome if they align with the scope of this fork.

Changes whose main purpose is to improve the general `cross` CLI are usually
better proposed upstream.

## License

Licensed under either of:

- Apache License, Version 2.0 ([LICENSE-APACHE](LICENSE-APACHE) or
  <http://www.apache.org/licenses/LICENSE-2.0>)
- MIT License ([LICENSE-MIT](LICENSE-MIT) or
  <http://opensource.org/licenses/MIT>)

at your option.

## Upstream

Upstream project: [cross-rs/cross][cross]

[cross]: https://github.com/cross-rs/cross
