---
# SPDX-FileCopyrightText: Copyright (c) 2026 Process Mission
# SPDX-License-Identifier: MIT
name: qemu-kernel-build
description: Use for building Linux kernels for QEMU boot testing, including defconfig selection, cross compile variables, Docker or host toolchains, Image, DTB, modules, initramfs inputs, output hashes, and provenance records.
---

# QEMU Kernel Build

## Audit workflow

For a non-trivial task that writes to the workspace, use only the needed entries under
`.oh-my-qemu/<task-slug>/`: `audit.md` (baseline, plan, decisions, evidence, verification, and
gaps), `commands.md` (redacted commands, working directories, and results), `logs/` (decisive
build, test, and runtime output), `scripts/` (probes, parsers, and harnesses), and `output/`
(generated deliverables, third-party dependencies, and non-QEMU binaries). Keep QEMU's own build
tree at source-root `builds/build-<target>/`, never an unqualified `build/`. In a Git worktree,
add `.agents/`, `.oh-my-qemu/`, and `builds/` to the file from
`git rev-parse --git-path info/exclude` before writing artifacts or configuring QEMU; preserve
existing entries and avoid duplicates. Never stage or commit these paths; stage source only when
the user explicitly requests that separate action. At handoff, reconcile `git status --short`
with the baseline and report the task directory, build directory, source changes, pre-existing
changes, and unresolved gaps.

## QEMU upstream boundary

QEMU's official GitLab and mailing lists are upstream channels. A patch becomes an upstream
contribution when it is sent to the maintainers selected through `MAINTAINERS`. Do not prepare or
send agent-generated code, documentation, commit messages, or patches for upstream submission; see
the checked-out tree's `docs/devel/code-provenance.rst`. Research, debugging, analysis, local
experiments, verification, and workflow guidance remain allowed. Local branches, commits, patch
files, pushes, and pull requests are not by themselves upstream contributions; perform those Git
actions only when requested.

## Scope

Build Linux kernel artifacts consumed by QEMU. QEMU itself belongs to `qemu-build` and U-Boot to
`qemu-uboot-build`. Keep kernel outputs under the task `output/` directory.

## Config provenance

Record kernel source revision and dirty state; architecture and defconfig; every config fragment
and the resulting `.config`; exact commands; and a hash of `.config`. A merged config is not a
plain defconfig: record the fragments and merge command. Copy `assets/build-record-template.md`
into the task directory for every kernel build.

## Build flow

Record cross compiler prefix, absolute compiler path and version; output directory and
parallelism; DTB names and destinations; module install path; initramfs or rootfs inputs; and a
hash of every artifact passed to QEMU or packed into an image. A typical shape, adapted to the
tree's own documentation:

```bash
make ARCH=<arch> O=<abs-output>/linux-<arch> <defconfig>
make ARCH=<arch> O=<abs-output>/linux-<arch> CROSS_COMPILE=<prefix> -j<nproc> Image modules dtbs
```

Use an absolute `O=` path; relative paths are resolved differently by recursive make. If Docker
is used, record image, mounts, user, working directory, and the command inside the container.

## Initramfs

Build initramfs explicitly when the boot contract needs one: create a tree, copy required
binaries and init, pack with `cpio` in newc format, compress only when the boot command expects
compression, and hash the archive passed to QEMU. Initramfs and block rootfs are different
contracts; record which one the run uses.

## Modules and release check

- Install modules into a task-local directory; check the kernel release in
  `include/config/kernel.release` against the installed `/lib/modules/` directory name.
- If modules fail to load, compare running kernel release and module tree before changing QEMU
  or the driver.
- For an external module against a prepared kernel output, use `KBUILD_MODPOST_WARN=1` when
  `Module.symvers` is absent and record the weakened symbol check; `Image modules_prepare` is
  enough when a full module set is not needed.

## Common failures

| Symptom | Check |
| --- | --- |
| `dtc`, `flex`, `bison`, or `libssl` missing | host build dependencies |
| Compiler or target mismatch | `CROSS_COMPILE`, `ARCH`, compiler path and version |
| Output appears in the source tree | missing or relative `O=` |
| Image rejected by QEMU | compressed vs uncompressed image expected by the machine |
| Module version mismatch | kernel release vs module tree |

## Upstream references

- `docs/system/linuxboot.rst`
- `docs/system/invocation.rst`
- `docs/devel/testing/main.rst`
- `docs/devel/code-provenance.rst`

Paths can differ between QEMU versions; locate them in the checked-out tree.
