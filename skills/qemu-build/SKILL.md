---
# SPDX-FileCopyrightText: Copyright (c) 2026 Process Mission
# SPDX-License-Identifier: MIT
name: qemu-build
description: Use for configuring, reusing, building, or diagnosing named QEMU build directories under source-root builds/, including target-specific, debug, sanitizer, and trace configurations. Use for the QEMU source tree only; kernel and U-Boot builds belong to qemu-kernel-build and qemu-uboot-build.
---

# QEMU Build

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

## Scope boundary

This skill configures and builds the QEMU source tree only. Use `qemu-kernel-build` for Linux
kernel artifacts and `qemu-uboot-build` for U-Boot and firmware-stage artifacts. One named build
directory per component; one skill per build class.

## Build directory rule

Use a descriptive directory under source-root `builds/` for every configuration, such as
`builds/build-aarch64/` or `builds/build-riscv64-debug/`. Never configure QEMU in `build/`, the
source root, or the task `output/` directory. Reuse a directory only when its recorded
configuration matches the task.

Inspect before creating or reconfiguring: `config.log` for the configure command and source
path; `build.ninja` for configured state; `pyvenv/bin/meson` for Meson commands;
`meson-logs/meson-log.txt` for configure failures. If `config.log` names a different source
root, prefix, or toolchain, the directory is stale: create a new named directory instead.

## Environment preflight

Record absolute paths and versions before the first build; do not rely on an interactive shell.
Run `scripts/preflight.sh` first, or see `references/host-matrix.md` for host notes and failures.

- `command -v ninja meson python3 pkg-config cc` and each resolved path plus version.
- The build directory's `pyvenv/bin/meson` and the configured Ninja when `PATH` lacks them.
- A readable and writable `HOME` for the executing user; a Meson reconfigure can fail when
  `HOME` belongs to another user.
- Compiler, sysroot, and `pkg-config` paths recorded in `config.log`.
- Host runtime libraries needed to run the built QEMU; if missing, build and run in the
  documented container and record both environments.

## Concurrency

Run one configure step and one Ninja invocation per build directory at a time. Do not share a
build directory between concurrent agents or tasks. If a build is already running, inspect its
process and log, then wait or use a separate named build directory.

## Configure

From the QEMU source root:

```bash
mkdir -p builds/build-aarch64
cd builds/build-aarch64
../../configure --target-list=aarch64-softmmu
```

Use `../../configure --help` in the build directory for options supported by the checked-out
version. Typical options are `--enable-debug`, `--enable-trace-backends=log`, and
`--enable-asan` or `--enable-ubsan` or `--enable-tsan`. Reconfigure from `config.log`,
changing only the needed option; keep the target list and diagnostic options unless the task
changes them.

Record any deviation, for example `--disable-werror` with the warning text that forced it. Do not
disable warnings silently, and for generated-source failures fix the generator input rather than
files under `builds/build-<target>/`.

## Build

From the source root, build the whole configuration or prefer narrow targets:

```bash
ninja -C builds/build-aarch64
ninja -C builds/build-riscv64 qemu-system-riscv64 tests/qtest/<test-name>
```

Use `-v` only for diagnosis.

## Pre-compile checklist

Before a long build after source edits: confirm edited headers are included; confirm called QEMU
APIs and struct fields exist in the checked-out tree; confirm feature guards match configured
targets and options; confirm new sources and qtests are registered in Meson; confirm changed
public signatures have all call sites updated.

## Canonical gate

For a change or a build claim, record these results before reporting PASS: the narrow build of
the affected target from a named build directory; the matching qtest or focused verification;
`scripts/checkpatch.pl` when source patches exist; `git diff --check` and reconciliation of
`git status --short`. Record the build in `assets/build-record-template.md`; report every
skipped gate as an unresolved gap.

## Failure classification

- Configure: missing dependency, unsupported option, Python/Meson issue, compiler mismatch,
  unreadable `HOME`, or stale build directory.
- Compile: API/type/include/feature-guard mismatch; check the checked-out headers and nearby
  maintained code.
- Link: missing object in Meson, missing dependency, target-specific source not linked.
- Generated source: QAPI, trace-events, decodetree, or another Meson generator input.
- Toolchain/host: sanitizer or compiler incompatibility, missing host library.

When background or sub-agent execution is unavailable, run the build as a bounded foreground
command, keep the full log under task `logs/`, and report the exit status and failure excerpt
instead of claiming completion.

## Upstream references

- `docs/devel/build-system.rst`
- `docs/devel/testing/main.rst`
- `docs/devel/submitting-a-patch.rst`
- `docs/devel/code-provenance.rst`

Paths can differ between QEMU versions; locate them in the checked-out tree.
