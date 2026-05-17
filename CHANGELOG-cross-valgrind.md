<!--
Added for new features.
Changed for changes in existing functionality.
Deprecated for soon-to-be removed features.
Removed for now removed features.
Fixed for any bug fixes.
Security in case of vulnerabilities.
-->

# Changelog

All notable changes to this project will be documented in this file.

This is the CHANGELOG for the `cross-valgrind` fork. Here is the original
[CHANGELOG](./CHANGELOG.md) of the upstream `cross` project.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to
[Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [3.27.0-alpha.1] - 2026-05-16

### Added

- Added dynamic 9p mount forwarding for the `qemu-system` runner, including
  project, target, toolchain, cargo, `/opt`, `/tmp`, and safe Docker mounts.
- Added a QEMU Malta kernel command-line patch so MIPS guests can receive the
  longer dynamic mount argument list.

### Changed

- Reworked `qemu-system` command construction and kernel argument handling in
  `linux-runner`.
- Forwarded selected Docker/container environment variables into the QEMU guest
  Valgrind execution environment.
- Updated README guidance for passing `CROSS_VALGRIND` through `Cross.toml`.

### Fixed

- Fixed the QEMU VM lock handling so the lock is not unintentionally kept open
  by the QEMU child process.
- Updated the Valgrind smoke test to pass `--vgdb=no` because `/tmp` is mounted
  through 9p and 9p does not support Valgrind vgdb shared-memory mmap.

## [3.27.0-alpha.0] - 2026-05-10

- Initial release
