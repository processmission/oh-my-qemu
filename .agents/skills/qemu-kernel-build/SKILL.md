---
name: qemu-kernel-build
description: Use for building Linux kernels for QEMU boot testing, including defconfig selection, cross compile variables, Docker or host toolchains, Image, DTB, modules, initramfs inputs, output hashes, and provenance records.
---

# QEMU Kernel Build

Use this skill when a QEMU task needs a Linux kernel artifact to boot or debug a modeled board.

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

This skill owns Linux kernel build actions and output evidence:
configuration, toolchain, build command, logs, produced kernel artifacts,
modules, DTBs, and hashes.

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
