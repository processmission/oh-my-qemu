---
# SPDX-FileCopyrightText: Copyright (c) 2026 Process Mission
# SPDX-License-Identifier: MIT
name: qemu-uboot-build
description: Use for building U-Boot artifacts for QEMU firmware boot testing, including defconfig selection, cross compile variables, SPL/TPL, U-Boot proper, FIT or ITB files, BL31 or TF-A dependencies, logs, hashes, and provenance.
---

# QEMU U-Boot Build

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

Build U-Boot and its loader stages for QEMU firmware boot tests. QEMU itself belongs to
`qemu-build` and the Linux kernel to `qemu-kernel-build`. Keep U-Boot outputs and dependency
packages under the task `output/` directory.

## Build flow

Record U-Boot source revision and dirty state; board defconfig and config fragments; cross
compiler prefix, absolute path, and version; output directory; external dependencies such as
BL31/TF-A, TEE or OP-TEE, DDR init, device trees, or vendor firmware blobs; and a hash of every
artifact consumed by QEMU or packaged into an image. Adapt the tree's documentation:

```bash
make O=<abs-output>/uboot <board_defconfig>
make O=<abs-output>/uboot CROSS_COMPILE=<prefix> -j<nproc>
```

Use an absolute `O=` path. When the firmware chain needs environment variables such as `BL31`,
record their resolved paths and hashes before building. Some vendor U-Boot trees must be built
in-tree or with vendor-specific variables; inspect the tree's documentation and record any
deviation from the generic shape.

## Artifact inspection

Inspect every artifact before use; a filename does not describe its contents.

- Use `file`, `dumpimage -l`, and `mkimage` metadata to identify SPL, U-Boot proper, FIT/ITB,
  and combined images; record sizes, load addresses, and component names.
- Treat each boot stage as a separate provenance item and hash it separately.
- A combined image may contain a different stage than expected: record the packaging command and
  verify the embedded bytes. FIT signing needs keys and a policy; do not call an image signed
  when signing was not configured.
- Copy `assets/artifact-manifest-template.md` and fill one row per stage before packaging.

## Firmware chain packaging

When packaging U-Boot into a vendor firmware image (FIP, BIOS, or a flash image):

- record the input U-Boot artifact hash and the documented destination offset;
- package an isolated copy and compare the embedded bytes against the source artifact at that
  offset, not only the container hash;
- record whether TF-A/BL31 was built from source or supplied as a blob, with revision and hash;
- keep the source media read-only and write the test image to a task-local path.

## Common failures

| Symptom | Check |
| --- | --- |
| `dtc`, `pyelftools`, `swig`, or `libssl` missing | host build dependencies |
| Compiler or target mismatch | `CROSS_COMPILE`, board defconfig, compiler version |
| Missing BL31 or FIT component | external dependency path and packaging command |
| Boot reaches no firmware prompt | image layout, boot media, and console routing |

## Upstream references

- `docs/system/linuxboot.rst`
- `docs/system/invocation.rst`
- `docs/devel/testing/main.rst`
- `docs/devel/code-provenance.rst`

Paths can differ between QEMU versions; locate them in the checked-out tree.
