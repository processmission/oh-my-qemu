---
name: qemu-uboot-build
description: Use for building U-Boot artifacts for QEMU firmware boot testing, including defconfig selection, cross compile variables, SPL/TPL, U-Boot proper, FIT or ITB files, BL31 or TF-A dependencies, logs, hashes, and provenance.
---

# QEMU U-Boot Build

Use this skill when a QEMU task needs U-Boot, SPL, TPL, FIT, ITB, or firmware-chain artifacts.

## Audit workflow

For every non-trivial task that writes to the workspace, choose a stable task
slug and keep all agent-only records under `.oh-my-qemu/<task-slug>/`. Create
only the entries the task needs:

```text
.oh-my-qemu/<task-slug>/
├── audit.md      # Baseline, scope, decisions, evidence, verification, and gaps
├── commands.md   # Redacted commands, working directories, and results
├── logs/         # Decisive build, test, runtime, or diagnostic logs
├── scripts/      # Temporary scripts, probes, parsers, and harnesses
└── output/       # Generated deliverables, dependencies, and non-QEMU binaries
```

Before changing source or mutable artifacts, record the workspace root,
branch/revision, `git status --short`, user-owned dirty paths, goal, scope, and
acceptance checks in `audit.md`. Record exact redacted commands and results in
`commands.md`; record source revisions, configurations, tool versions, and
input/output hashes when they affect reproducibility. Separate observations
from inferences and create or change source files only when requested.

Put every QEMU build in a named directory under the QEMU source root, such as
`builds/build-aarch64/`. Put third-party dependency artifacts and non-QEMU
binaries under the task's `output/` directory. In a Git worktree, before
writing audit records or configuring QEMU, add `.agents/`, `.oh-my-qemu/`, and
`builds/` to the repository-local exclude file returned by
`git rev-parse --git-path info/exclude`; preserve existing entries and avoid
duplicates. Never stage or commit those directories. Before handoff, verify
that `git status --short` contains none of them, then report the task directory
and unresolved gaps.

## Scope

This skill owns U-Boot build actions and output evidence: defconfig,
toolchain, external inputs, build command, logs, boot-stage artifacts, and
hashes.

## Build Flow

Record:

- U-Boot source path, revision, and dirty state;
- board defconfig and any config fragments;
- architecture, cross compiler prefix, compiler version, and output directory
  under `.oh-my-qemu/<task-slug>/output/`;
- external dependencies such as BL31, TEE, firmware blobs, device trees, or DDR init binaries;
- output artifacts such as `spl/u-boot-spl`, `u-boot`, `u-boot.bin`, `u-boot.itb`, or platform-specific combined images;
- exact command, log path, and hashes.

## Command Shape

Use local documentation first. Typical U-Boot patterns are:

```bash
make O=<task-output>/uboot <board_defconfig>
make O=<task-output>/uboot CROSS_COMPILE=<prefix> -j$(nproc)
```

If a firmware chain requires environment variables such as `BL31`, record their resolved paths and hashes before building.

## Output Rules

- Treat each boot stage as a separate provenance item.
- Keep dependency packages and all U-Boot build outputs under
  `.oh-my-qemu/<task-slug>/output/`.
- Do not assume a combined image contains the expected stage; inspect and record the packaging command.
- If firmware reaches U-Boot but Linux does not boot, separate U-Boot command/environment issues from QEMU model issues.
