---
name: qemu-image
description: Inspect or package QEMU disk, SD, eMMC, flash, pflash, firmware, raw, and qcow2 images. Use for read-only image format, partition, region, offset, sector-size, and hash analysis, or for explicitly authorized image creation, conversion, partitioning, filesystem population, and fixed-offset writes with readback and rollback evidence.
---

# QEMU Image

Inspect boot-media layouts without changing them, or package new media only when the requested writes and exact target are authorized.

## Audit workflow

For every non-trivial task, choose a stable task slug and keep agent-only
records under:

```text
.oh-my-qemu/<task-slug>/
├── audit.md        # Baseline, mode, authorization, decisions, evidence, and gaps
├── commands.md     # Redacted commands, working directories, and results
├── logs/           # Decisive inspection, packaging, and verification output
├── scripts/        # Task-specific helper scripts and intermediate documents
└── output/         # Working copies, backups, readbacks, and generated images
```

In a Git worktree, add `.agents/`, `.oh-my-qemu/`, and `builds/` to the
repository-local exclude file returned by
`git rev-parse --git-path info/exclude` before writing task artifacts or build
outputs. Preserve existing entries and avoid
duplicates. If QEMU itself must be built, use only a source-root
`builds/build-<target>/` build tree; never use an unqualified `build/`
directory. Record a baseline and handoff
`git status --short --untracked-files=all`; distinguish pre-existing changes
from task changes and verify that no `.agents/`, `.oh-my-qemu/`, or `builds/`
path is staged or tracked. Never stage or commit files while using this skill.
Record redacted commands, their working directories and outcomes in
`commands.md`, put helper scripts in `scripts/`, and put raw decisive output in
`logs/`. Store generated images, third-party dependency outputs, and other
non-QEMU build binaries in `output/`. Report the audit directory and all
unresolved gaps at handoff.

## Select the mode

- Use **inspect** by default, including for ambiguous requests. Keep the target
  image or device read-only and limit actions to identification, measurement,
  hashing, and verification. Do not mount read-write, repair a filesystem or
  image, convert, resize, rebase, amend, repartition, or write raw bytes.
- Use **package** only when the user explicitly requests creation, conversion,
  population, or mutation and the exact output path or device and allowed
  changes are clear. Authorization to inspect is not authorization to write.
- If a command's write behavior is uncertain, stop and resolve it before use.
  Prefer a task-local working copy for experiments and never mutate an input
  artifact by default.

Record the selected mode, target, authorization boundary, and intended outputs
in `audit.md` before taking an action that can write.

## Inspect an image

1. Resolve the exact path without following an ambiguous glob. Record whether
   it is a regular file, block device, symlink, or backing-chain member.
2. Identify the container format independently from its contents. Record raw,
   qcow2, or other format; virtual and allocated size; backing files; and any
   format features that affect mutation. Do not infer format from the suffix.
3. Record the partition-table type and the logical sector size reported by the
   relevant tool. List partition and fixed-region start, end, size, type or
   GUID, filesystem, purpose, and alignment. Include boot data outside a
   partition table.
4. Express every address with an explicit unit and base. Derive a byte offset
   as `start_sector * logical_sector_size`; never assume 512-byte sectors.
   Distinguish image-relative, partition-relative, and nested-container
   offsets.
5. Compute SHA-256 for the inspected image and important inputs when practical.
   Record the exact hashing command and identify any unhashable or changing
   target as a gap.

Prefer read-only forms of locally available tools such as `file`, `qemu-img
info`, `fdisk -l`, `sfdisk --dump`, and `sha256sum` or `shasum -a 256`. Treat
tool absence or an unsupported format as an unresolved gap, not as permission
to mutate the image.

## Plan a package operation

Before writing, record this contract in `audit.md`:

```markdown
| Output | Format | Virtual size | Existing target? | Mutation policy |
| --- | --- | --- | --- | --- |

| Region | Start byte | Start sector | Sector size | Size | Type/filesystem | Source |
| --- | --- | --- | --- | --- | --- | --- |

| Order | Operation | Input | Output region | Offset/seek | Block size | Bounds | Readback |
| --- | --- | --- | --- | --- | --- | --- | --- |
```

- Resolve every input and output path, record available space, and hash each
  input. Separate firmware, bootloader, kernel, DTB, initrd, root filesystem,
  and modules even when the final output combines them.
- Record the image format, partition table, logical sector size, alignment,
  fixed regions, filesystem choices, write order, and expected final size.
- For each write, state whether the offset is in bytes or sectors and which
  base it is relative to. When using `dd`, record `bs`, `seek`, `skip`, `count`,
  and truncation behavior. Prove that `offset + payload_size` stays within its
  assigned region and the image, and reject unintended overlaps.
- Classify the target as immutable input, working copy, disposable output, or
  reusable mutable media. Account for later guest, firmware, pflash, qcow2, or
  filesystem writes; use a clean copy or overlay when repeatability matters.

## Package and verify

1. Create a new output under `output/` unless the user authorized another
   exact path. For an existing target, require explicit overwrite or in-place
   authorization and first prepare a verified backup or another documented,
   reversible strategy.
2. Create or convert the container, partition it, create filesystems, copy
   files, and perform fixed-offset writes in the recorded order. Preserve
   sparse allocation when required and do not let a raw write truncate the
   output unintentionally.
3. Flush pending writes before verification. Re-inspect format, virtual and
   allocated size, partitions, sector size, regions, and filesystems without
   repair options.
4. Read back every material write. Compare file contents or extracted byte
   ranges with their source by SHA-256 or byte comparison, and verify partition
   boundaries and filesystem contents independently of command success.
5. Hash the complete output after packaging and record both pre-mutation and
   final hashes where an existing image or base copy was involved. A command
   exit status alone is not readback evidence.

Do not pass an image to QEMU as proof of correct packaging: boot behavior can
mutate media and does not establish byte-for-byte placement.

## Roll back safely

- Define rollback before the first write: remove an incomplete new output, or
  restore an existing target from the verified backup or clean base. Keep the
  backup until verification and handoff unless the user authorizes its removal.
- Prefer building a temporary output and publishing it only after readback.
  Never attempt in-place rollback without a known-good source and exact bounds.
- If packaging or readback fails, stop further writes, preserve evidence, run
  only the authorized rollback, and verify the restored target's format,
  layout, size, and hash. Report any partial mutation or failed rollback as an
  unresolved gap.

## Handoff

Provide the selected mode, exact inspected or packaged path, format and layout
summary, sector size and offset units, input and output SHA-256 values, mutation
policy, readback results, rollback state, audit directory, and unresolved gaps.
