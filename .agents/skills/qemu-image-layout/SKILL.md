---
name: qemu-image-layout
description: Use as a QEMU flow primitive to describe and verify raw, qcow2, SD, eMMC, flash, or firmware image layouts, including partitions, offsets, write operations, mutation policy, and hashes.
---

# QEMU Image Layout

Use this primitive before packaging or booting any disk, SD, eMMC, flash, pflash, firmware, or multi-partition image.

## Primitive Boundary

This primitive owns only the image layout contract: format, size, partitions,
regions, offsets, write order, mutation policy, and hashes. It consumes
already selected input artifact paths and does not choose provenance,
packaging, boot-run, or debug workflow steps.

## Layout Record

Use this structure:

```markdown
# Image Layout

## Image Summary

| Image | Format | Virtual size | Actual size | SHA256 | Mutable? |
| --- | --- | --- | --- | --- | --- |

## Partition or Region Map

| Region | Start | Size | Type | Filesystem | Purpose | Source |
| --- | --- | --- | --- | --- | --- | --- |

## Write Operations

| Order | Input | Output image | Offset/seek | Block size | Size | Command | Verified by |
| --- | --- | --- | --- | --- | --- | --- | --- |

## Boot-Relevant Files

## Mutation Policy

## Verification Notes
```

## Rules

- Work on a scratch copy unless the user explicitly wants to mutate the original image.
- Record byte offsets or sector offsets unambiguously. Include block size when using `dd`.
- Record partition start sectors before deriving absolute offsets.
- Hash the image before and after packaging when repeatability matters.
- Treat firmware, bootloader, kernel, DTB, rootfs, and modules as separate inputs even when packed into one image.
- If a boot failure appears after repeated runs, check whether the image was mutated before changing QEMU model code.

## Useful Checks

```bash
qemu-img info <image>
fdisk -l <image>
sfdisk -d <image>
file <image>
sha256sum <image>
```

Use platform-specific tools only when the local image format requires them, and record the exact command.
