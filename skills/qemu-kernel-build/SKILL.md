---
# SPDX-FileCopyrightText: Copyright (c) 2026 Process Mission
# SPDX-License-Identifier: MIT
name: qemu-kernel-build
description: Use for building Linux kernels for QEMU boot testing, including defconfig selection, cross compile variables, Docker or host toolchains, Image, DTB, modules, initramfs inputs, output hashes, and provenance records.
---

# QEMU Kernel Build

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

Record and verify:

- kernel source path, revision, and dirty state;
- architecture, cross compiler prefix, compiler path, and version;
- defconfig and any config fragment or manual `.config` change;
- output directory under `.oh-my-qemu/<task-slug>/output/`, build command, and
  parallelism;
- DTB names and destination paths;
- module install path if modules are needed;
- initramfs or rootfs source if the boot command depends on it.

## Command Shape

Use the kernel tree's preferred commands. Typical Linux patterns are:

```bash
make ARCH=<arch> O=<task-output>/linux-<arch> <defconfig>
make ARCH=<arch> O=<task-output>/linux-<arch> \
  CROSS_COMPILE=<prefix> -j$(nproc) Image modules dtbs
```

If Docker is used, record image, mounts, user, working directory, and the command run inside the container.

## Output Rules

- Do not mix outputs from different kernel revisions without recording it.
- Keep the kernel build tree, installed modules, dependency packages, and
  produced binaries under `.oh-my-qemu/<task-slug>/output/`.
- Hash the exact files passed to QEMU or packed into an image.
- Keep build logs under `.oh-my-qemu/<task-slug>/logs/`.
- If the kernel boots but modules fail to load, verify kernel release and module tree before changing QEMU.
