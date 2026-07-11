---
name: qemu-image-packaging
description: Use for packaging QEMU boot media from kernels, DTBs, firmware, bootloaders, root filesystems, modules, and raw or qcow2 images, while recording layout, offsets, write commands, hashes, and mutation policy.
---

# QEMU Image Packaging

Use this primitive to create or update QEMU boot media: SD, eMMC, raw disk, qcow2, pflash, NOR, NAND, firmware containers, or rootfs images.

## Primitive Boundary

This primitive owns only packaging actions and their immediate output evidence:
base image creation, filesystem operations, raw writes, conversion commands,
hashes, and mutation policy. It consumes an explicit target layout and input
artifact list supplied by the caller and does not choose provenance,
image-layout, boot, or debug workflow steps.

## Packaging Flow

Record:

- base image or blank image creation command;
- virtual size, actual size, and format;
- partition or fixed-region map;
- filesystem creation or file copy commands;
- raw write operations, including offset or seek and block size;
- final image hash and any per-partition or per-file checks;
- whether the image is intended to be reused, treated as disposable, or refreshed before each run.

## Tool Rules

- Use `qemu-img` for QEMU image format conversion or inspection.
- Use partition/filesystem tools appropriate to the local image format.
- Prefer explicit offsets over implicit tool behavior for firmware regions.
- Keep large generated images out of source control.
- Store packaging logs and command transcripts under `.oh-my-qemu/<task-slug>/`.

## Output Contract

After packaging, provide a copy-pasteable output path, layout summary, hashes,
and mutation policy. If a later boot fails, the outer workflow decides whether
to revisit packaging, layout, command-line, or QEMU source behavior.
