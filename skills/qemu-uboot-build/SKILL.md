---
# SPDX-FileCopyrightText: Copyright (c) 2026 Process Mission
# SPDX-License-Identifier: MIT
name: qemu-uboot-build
description: Use for building U-Boot artifacts for QEMU firmware boot testing, including defconfig selection, cross compile variables, SPL/TPL, U-Boot proper, FIT or ITB files, BL31 or TF-A dependencies, logs, hashes, and provenance.
---

# QEMU U-Boot Build

## Audit workflow

For non-trivial workspace writes, use a stable
`.oh-my-qemu/<task-slug>/` directory and create only needed entries:

```text
.oh-my-qemu/<task-slug>/
├── audit.md      # Baseline, scope, decisions, evidence, verification, and gaps
├── commands.md   # Redacted commands, working directories, and results
├── logs/         # Decisive build, test, runtime, or diagnostic logs
├── scripts/      # Temporary scripts, probes, parsers, and harnesses
└── output/       # Generated deliverables, dependencies, and non-QEMU binaries
```

Before changing source or mutable artifacts, record the workspace root,
revision, `git status --short`, pre-existing changes, goal, scope, and
acceptance checks in `audit.md`. Log exact redacted commands and results in
`commands.md`; record revisions, configurations, tool versions, and hashes when
they affect reproducibility. Separate observations from inferences and edit
source only when requested.

Keep QEMU builds under source-root `builds/build-<target>/`; put third-party
dependencies and non-QEMU binaries in task `output/`. Before writing audit
artifacts or configuring QEMU in a Git worktree, add `.agents/`,
`.oh-my-qemu/`, and `builds/` to the repository-local file from
`git rev-parse --git-path info/exclude`; preserve existing entries and avoid
duplicates. Never stage or commit those directories. At handoff, verify them
absent from `git status --short`. Report the task directory and unresolved gaps.

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
