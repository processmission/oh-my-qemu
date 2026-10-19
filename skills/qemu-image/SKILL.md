---
# SPDX-FileCopyrightText: Copyright (c) 2026 Process Mission
# SPDX-License-Identifier: MIT
name: qemu-image
description: Inspect or package QEMU disk, SD, eMMC, flash, pflash, firmware, raw, and qcow2 images. Use for read-only image format, partition, region, offset, sector-size, and hash analysis, or for explicitly authorized image creation, conversion, partitioning, filesystem population, and fixed-offset writes with readback and rollback evidence.
---

# QEMU Image

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

## Select the mode

- Use **inspect** by default, including for ambiguous requests. Keep the target read-only and
  limit actions to identification, measurement, hashing, and verification.
- Use **extract** for read-only unpacking or forensics of firmware and disk images. Record the
  extraction tool, version, and layout; write extracted content only under task `output/`; never
  mutate the input image.
- Use **package** only when the user explicitly requests creation, conversion, population, or
  mutation and the output path and allowed changes are clear. Authorization to inspect is not
  authorization to write.
- If a command's write behavior is uncertain, stop and resolve it first. Prefer a task-local
  working copy and never mutate an input artifact by default.

Record the selected mode, target, authorization boundary, and intended outputs in `audit.md`
before any action that can write.

## Inspect an image

1. Resolve the exact path without following an ambiguous glob; record whether it is a regular
   file, block device, symlink, or backing-chain member.
2. Identify the container format independently from its contents: raw, qcow2, or other; virtual
   and allocated size; backing files; format features that affect mutation. Do not infer format
   from the suffix.
3. Record the partition-table type and the logical sector size reported by the tool. List
   partition and fixed-region start, end, size, type or GUID, filesystem, purpose, and alignment,
   including boot data outside a partition table.
4. Express every address with an explicit unit and base; derive byte offsets from start sector
   times logical sector size. Distinguish image-relative, partition-relative, and nested-container
   offsets.
5. Compute SHA-256 for the inspected image and important inputs when practical; record the exact
   command and identify an unhashable or changing target as a gap.

Use read-only tool forms first. See `references/packaging.md` for the tool matrix and the
packaging, readback, and cross-repo contracts.

## Package contract

Before writing, start from `assets/packaging-plan-template.md` and record the output, region,
and operation tables from `references/packaging.md` in `audit.md`. Resolve every input and
output path, hash each input, and separate firmware, bootloader, kernel, DTB, initrd, root
filesystem, and modules even when the final image combines them.

For each write, state whether the offset is bytes or sectors and which base it is relative to.
When using `dd`, record `bs`, `seek`, `skip`, `count`, and truncation behavior; prove that
`offset + payload_size` stays within its assigned region and the image, and reject overlaps.
Classify each target as immutable input, working copy, disposable output, or reusable mutable
media, and account for later guest or firmware writes.

## Package and verify

1. Create a new output under `output/` unless another exact path is authorized. For an existing
   target, require explicit overwrite or in-place authorization and prepare a verified backup.
2. Perform operations in the recorded order; preserve sparse allocation where required and do not
   let a raw write truncate the output unintentionally.
3. Flush pending writes, then re-inspect format, sizes, partitions, sector size, regions, and
   filesystems without repair options.
4. Read back every material write and compare file contents or extracted byte ranges with their
   source by SHA-256 or byte comparison. A command exit status is not readback evidence.
5. Hash the complete output; record pre-mutation and final hashes when a base or existing image
   was involved.

Do not treat a QEMU boot as proof of correct packaging: boot behavior can mutate media and does
not establish byte-for-byte placement.

## Cross-repo packaging contract

When images and boot files are consumed by another repository or test suite:

- keep separately consumable boot files (kernel image, initramfs, DTB, firmware) when the direct
  boot path needs them rather than only a combined image;
- pin artifact hashes and record the hash expected by the consuming test;
- a local HTTP server can serve test assets; record URL, port, document root, and asset hashes;
- metadata names such as `REQUIRED_IMAGES` or `SUPPORTED_BOOT_MODES` are repository-specific and
  stay in that repository; do not copy the vocabulary into QEMU or this skill as a contract.

## Roll back safely

Define rollback before the first write: remove an incomplete new output, or restore a target from
the verified backup or clean base. Keep the backup until verification and handoff unless removal
is authorized. Prefer building a temporary output and publishing it after readback. If packaging
or readback fails, stop writes, preserve evidence, run only the authorized rollback, and verify
the restored target. Report partial mutation or failed rollback as an unresolved gap.

## Handoff

Provide the selected mode, exact inspected or packaged path, format and layout summary, sector
size and offset units, input and output SHA-256 values, mutation policy, readback results,
rollback state, audit directory, and unresolved gaps.

## Upstream references

- `docs/tools/qemu-img.rst`
- `docs/system/invocation.rst`
- `docs/devel/code-provenance.rst`

Paths can differ between QEMU versions; locate them in the checked-out tree.
