# AGENTS.md

## Project Overview

`cross-valgrind` is a fork of [cross-rs/cross](https://github.com/cross-rs/cross) (crate name `cross`) whose sole purpose is building and publishing cross-compilation Docker images with Valgrind installed. The images are consumed by [gungraun](../gungraun/), a sibling Rust benchmarking framework that runs Valgrind tools via the `qemu-system` runner (`qemu-user` is not supported).

**The `cross` Rust binary is not a development target of this fork.** Do not modify `src/` (behavior, features, CLI) except where needed to make tests pass. Fork-specific changes belong in `docker/`, `crosstool-ng/`, `ci/`, and `targets.toml` (the image surface).

- Rust 2021, MSRV `1.85.0` (`rust-version` in `Cargo.toml`).
- Workspace: the `cross` crate at the root plus the `xtask` workspace member (dev tooling).
- Image releases use the bundled Valgrind version and a fork-specific suffix; `-1` denotes the first stable image revision for that Valgrind version.
- Images are published as `ghcr.io/gungraun/<target>` with tags `main` (built from `main`), `edge` (branch builds), `latest`, and release tags derived from git tags (`v3.28.0-1` → `3.28.0-1`).
- Consumers run the *upstream* `cross` CLI with per-target image overrides (`Cross.toml` `image = …` or `CROSS_TARGET_<TRIPLE>_IMAGE`). `CROSS_IMAGE` is not recommended here: fork tags don't line up with the binary's built-in default image version.
- Supported targets are a stripped-down subset of upstream `cross` (11 Linux targets); the authoritative list is `targets.toml` (README "Supported Targets" mirrors it).
- Image stack differs from upstream: Debian ≥Bookworm base (upstream: Ubuntu ≥20.04), Valgrind in the stack (larger images), newer QEMU and a more recent Linux kernel.
- User-facing docs live in `docs/` (config file, environment variables, custom images, recipes, etc.) — consult them before changing CLI/config behavior.

## Setup Commands

- Clone with submodules: `git clone --recursive` (submodule: `docker/cross-toolchains`). If already cloned: `git submodule update --init --recursive`.
- Build: `cargo build` (no extra system deps; Docker/container engine only needed for image work).
- Local dev helpers: `cargo xtask install-git-hooks`.

## Development Workflow

`cargo xtask …` is an alias for `cargo run -p xtask -- …` (defined in `.cargo/config.toml`, which also defines `cargo build-docker-image`). Key commands:

| Command | Purpose |
|---|---|
| `cargo xtask check` | Run formatting checks and lints (`--all`, `--python`, `--flake8`) |
| `cargo xtask test` | Run the test suite (Python tests via `--python`/`PYTHON`, `--tox`/`TOX`) |
| `cargo xtask build-docker-image …` | Build a target Docker image (`CROSS_BUILD_OPTS` passes build options) |
| `cargo xtask configure-crosstool …` | Regenerate crosstool-ng configs from `crosstool-ng/*.config.in` (env: `GCC_VERSION`, `GLIBC_VERSION`, `UCLIBC_VERSION`, `MUSL_VERSION`, `NEWLIB_VERSION`, `LINUX_VERSION`) |
| `cargo xtask codegen` | Regenerate `src/docker/provided_images.rs` from `targets.toml` — run after editing `targets.toml` |
| `cargo xtask changelog build --release VERSION` | Build the changelog (`--dry-run`/`DRY_RUN`) |
| `cargo xtask changelog validate [FILES…]` | Validate changelog entries |
| `cargo xtask ci-job check` | Workspace/release metadata check (CI runs this) |
| `cargo xtask ci-job target-matrix …` | Generate the CI target matrix (`TARGETS` overrides selection) |

## Testing Instructions

- Run all Rust tests (CI command): `cargo test --locked --all-targets --workspace --all-features`.
- Rust tests are inline unit tests (`#[cfg(test)]`) in `src/`; there is no top-level `tests/` directory. Add tests in the module you change.
- Image tests are shell scripts, not `cargo test`: `ci/test.sh` and `ci/test-valgrind-smoke.sh`. They require a built target image (`cargo xtask build-docker-image …`) and Docker.
- Python tests for Android tooling live in `docker/android/tests/` (see its README); run via `cargo xtask test --python`.

## Code Style

- Formatting check (CI): `cargo fmt -- --check`. Note: `rustfmt.yml` in the repo root is not read by `cargo fmt` (rustfmt only reads `rustfmt.toml`); CI formats with default stable rustfmt.
- Lint (CI): `cargo clippy --locked --all-targets --all-features --workspace -- -D warnings`.
- `clippy.toml`: `std::path::Path::display` is disallowed — use the project's UTF-8 conversion or debug formatting; `unwrap` is allowed in tests.
- Shell scripts are checked with ShellCheck in CI (`ci/`, `docker/*.sh`).
- `deny.toml` is checked with cargo-deny (CI uses `EmbarkStudios/cargo-deny-action`).
- Spelling: `cspell.json` with custom dictionary `.dicts/custom.txt` — add project terms there. Not enforced by CI in this fork.

## Build and Deployment

- Docker images: per-target `docker/Dockerfile.*` with shared scripts in `docker/`; build via `cargo xtask build-docker-image`. CI builds, tests (`ci/test.sh`, `ci/test-valgrind-smoke.sh` — the fork's additional Valgrind smoke test), then pushes from `main` with `cargo xtask build-docker-image -v --push …`.
- `CROSS_VALGRIND` integration contract (what gungraun relies on): consumers set `CROSS_VALGRIND` to the Valgrind command + args to run inside the guest (e.g. `valgrind --tool=memcheck`) and forward it via `Cross.toml` `target.<triple>.env.passthrough`. When `CROSS_VALGRIND` is present in the container and no runner is configured, `qemu-system` is selected automatically. Do not break this passthrough/auto-selection behavior when touching runner or image logic.
- `targets.toml` defines the default targets and their capabilities; it feeds `cargo xtask codegen` (`src/docker/provided_images.rs`) and the CI target matrix.
- CI (`.github/workflows/`): `ci.yml` (PRs, merge queue, pushes to `main`/`staging`/`trying`/`develop` and tags — shellcheck, deny, fmt, clippy, test, metadata, per-target image jobs), `try.yml` (comment-triggered test builds), `weekly.yml` (scheduled cargo-deny).
- Release: `cargo xtask changelog build --release VERSION` runs via the `cargo release` pre-release hook.

## Branches and Pull Requests

- Day-to-day work lands on `develop` and merges to `main` via PR (CI also uses `staging`/`trying` merge-queue branches).
- Every PR adds a changelog entry: `.changes/${pr}.json` (issue entries: `_${issue}.json`; multiple PRs: `${pr1}-${pr2}.json`; array for multiple changes). Fields: `description`, `type` (`added`/`changed`/`fixed`/`removed`/`internal`), optional `issues`, `breaking`. See `.changes/README.md` and `.changes/template`.
- Fork-specific changes go to `CHANGELOG-cross-valgrind.md`; `CHANGELOG.md` is inherited from upstream.
- Before committing, run `cargo fmt --check` (`cargo fmt`), the clippy command above, and the test command.
- CONTRIBUTING.md points to upstream cross-rs conduct and discussions.

## Gotchas

- The `cross` binary is upstream code: leave `src/` untouched unless a change is required to make tests work. This fork is about the images, not the tool.
- Valgrind support uses `qemu-system` runners only; do not route through `qemu-user`. Valgrind lives inside the image, not in the container engine.
- `.cargo/config.toml` defines the `xtask` and `build-docker-image` cargo aliases — don't remove them, and use string-literal form for any new cargo config values (comment there explains why).
- There is no CI enforcement of changelog entries or spelling in this fork; the conventions above still apply.
- Never modify or reset the `docker/cross-toolchains` submodule checkout beyond what a task requires.
