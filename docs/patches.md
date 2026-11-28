# Carried Patches

The images build several components from upstream release sources (Valgrind,
zlib, QEMU) and carry a small set of patches on top. Each patch exists because
an upstream release did not build, or did not behave correctly, in this fork's
cross-compilation and `qemu-system` guest environment. This page records for
every patch the context in which the problem appeared, the expected behavior,
what the patch changes, and when the patch can be dropped.

Patches live in `docker/`, are `COPY`ed into the relevant build stage by the
target `Dockerfile`, and are applied by the component build script
(`docker/valgrind.sh`, `docker/zlib.sh`, `docker/qemu.sh`) guarded by file
existence — a target that does not copy a patch simply skips it. Re-evaluate
every patch whenever the patched component is version-bumped.

| Patch | Applied by | Targets | Kind |
| --- | --- | --- | --- |
| `valgrind-cross-compile-arm-tests.patch` | `valgrind.sh` (`patch -p0`) | all | cross-compile fallback |
| `valgrind-mips-open_tree_attr.patch` | `valgrind.sh` (`patch -p1`) | mipsel, mips64el | upstream backport |
| `valgrind-mips-sa_flags.patch` | `valgrind.sh` (`patch -p1`) | mipsel, mips64el | fork-only guard |
| `valgrind-s390x-cachegrind.patch` | `valgrind.sh` (`patch -p1`) | s390x | fork-only fallback |
| `zlib-s390x-vx.patch` | `zlib.sh` (`patch -p1`) | s390x | build flag fix |
| `qemu-malta-kernel-cmdline.patch` | `qemu.sh` (`git apply`) | mipsel, mips64el | capacity limit fix |

## `valgrind-mips-open_tree_attr.patch` — missing mips syscall number

**Context.** Valgrind 3.28.0 added a wrapper for the new `open_tree_attr`
syscall (upstream commit `ca60092a2`, bug 521054). The table entry
`LINXY(__NR_open_tree_attr, sys_open_tree_attr)` was appended to *every*
architecture's syscall table, but the `__NR_open_tree_attr` number define was
only added to the non-mips `vki-scnums-*.h` headers. Both mips images
therefore failed to compile coregrind with
`m_syswrap/syswrap-mips32-linux.c:1195:4: error: '__NR_open_tree_attr' undeclared here`.
The break surfaced on `main` after PR #34 merged — image builds only run on
push to `main`, never on pull requests. Valgrind 3.27.1 predates the wrapper
and was unaffected.

**What it does.** Verbatim backport of upstream commit
[137816076](https://sourceware.org/git/?p=valgrind.git;a=commit;h=1378160766199b554aa60a7a7bd4f01449faaa85)
"mips: Add missing open_tree_attr syscall definition":
`#define __NR_open_tree_attr (__NR_Linux + 467)` for mips32 and for mips64
(n32 and n64). Expected behavior is restored — `open_tree_attr` is wrapped on
mips like on every other architecture.

**Drop when.** The first Valgrind release that contains commit 137816076
(anything after 3.28.0).

## `valgrind-cross-compile-arm-tests.patch` — configure checks without cross-compile fallback

**Context.** Valgrind 3.28.0's `configure` added two checks — "is
armv8.2-a+dotprod / armv8-a+crypto supported for tests" — that execute test
programs via `AC_RUN_IFELSE` without a cross-compilation fallback. All targets
except `x86_64-unknown-linux-gnu` cross-compile Valgrind on x86_64 CI runners,
so `configure` aborted with `cannot run test program while cross compiling`
for every cross-compiled target, ARM or not. The break surfaced on `main`
after the Valgrind 3.28.0 bump (PR #33) merged; pull request CI does not build
images.

**What it does.** When `cross_compiling=yes`, both checks report "no" instead
of aborting. Native builds are unchanged. The checks only gate building
Valgrind's own ARM-specific test binaries, which these images never build or
install.

**Drop when.** A Valgrind release adds cross-compiling fallbacks to these
checks. Note the patch touches the *generated* `configure` script, so it must
be regenerated from `configure.ac` if it stops applying.

## `valgrind-mips-sa_flags.patch` — kernel sa_flags assert on mips

**Context.** coregrind's `handle_SCSS_change` asserts that the `sa_flags` the
kernel reports for a restored signal handler equal what Valgrind installed. On
the mips guests the fork runs under the `qemu-system` runner, the kernel
reports modified flags, and the assert aborts Valgrind at startup. Observed
during the initial fork bring-up. Upstream already excludes mips from the
neighboring signal-consistency checks; this extends the same treatment to the
`sa_flags` equality assert.

**What it does.** Compiles `vg_assert(ksa_old.sa_flags == …)` out for
`VGP_mips32_linux` and `VGP_mips64_linux` only.

**Drop when.** Not upstreamed; keep until an upstream Valgrind release
handles mips here, then re-evaluate.

## `valgrind-s390x-cachegrind.patch` — unusable ECAG cache geometry under QEMU

**Context.** On s390x, Valgrind queries the cache geometry with the ECAG
instruction and asserts the values are usable. Under the fork's `qemu-system`
guest runner ECAG is available but returns garbage geometry, so cachegrind
aborted instead of running. Seen during fork bring-up (commit `2c6c674`,
changelog 3.27.0-alpha.2: "fall back from unusable QEMU ECAG cache geometry
and allow explicit cache settings").

**What it does.**

- `coregrind/m_cache.c`: sanity-check ECAG-reported values (size, line size,
  associativity) and fail detection gracefully instead of building a broken
  cache model.
- `cachegrind/cg_arch.c`: on failed detection fall back to the z10-EC default
  cache configuration instead of asserting, and stop rejecting values that the
  user explicitly set with cachegrind command line options — explicit settings
  always win.

**Drop when.** Not upstreamed (the trigger is QEMU TCG's ECAG behavior, not an
upstream Valgrind bug). Keep; re-evaluate if QEMU or Valgrind change ECAG
handling.

## `zlib-s390x-vx.patch` — vector flag missing in zlib's s390x build

**Context.** zlib's `configure` detects s390x vector-facility support and
defines `HAVE_S390X_VX`, but adds only that define to `CFLAGS`/`SFLAGS` — not
the vector compiler flag it detected (`$VGFMAFLAG`). The VX-accelerated
`crc32_vx` objects then fail to build under the fork's s390x cross toolchain,
whose default `-march` predates the vector facility.

**What it does.** Appends `$VGFMAFLAG` next to `-DHAVE_S390X_VX` in
`CFLAGS`/`SFLAGS`.

**Drop when.** A zlib release connects the two itself; check `configure` on
zlib version bumps.

## `qemu-malta-kernel-cmdline.patch` — 256-byte boot environment limit on Malta

**Context.** The `qemu-system` runner forwards project, target, toolchain and
other mounts into the guest as dynamic 9p mounts, encoded as a long kernel
command line (commit `e5b22b1`, changelog 3.27.0-alpha.1). QEMU's Malta board
code caps each boot environment entry — which carries that command line — at
256 bytes, silently truncating the generated argument lists.

**What it does.** QEMU `hw/mips/malta.c`: `ENVP_ENTRY_SIZE` 256 → 1024.

**Drop when.** A QEMU release raises the Malta environment entry size; check
`hw/mips/malta.c` on QEMU version bumps.

## Adding a new patch

1. Reproduce the failure locally, e.g.
   `podman build --target valgrind -f Dockerfile.<target> .` from `docker/`.
2. Create a git-style diff against the exact release sources the build
   downloads: `docker/<component>-<topic>.patch`.
3. Add it to the `COPY` line of the Dockerfile(s) of the affected targets
   only.
4. Apply it in the component build script, guarded by file existence:
   ```sh
   if [[ -f /<component>-<topic>.patch ]]; then
       patch -p1 </<component>-<topic>.patch
   fi
   ```
   (`patch -p0` if the diff has no `a/` `b/` prefixes, `git apply` for
   checkouts instead of release tarballs.)
5. Document it here: context, expected behavior, what it does, drop-when.
6. Rebuild the affected targets and add a `.changes/<pr>.json` entry.
