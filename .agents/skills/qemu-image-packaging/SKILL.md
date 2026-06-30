---
name: qemu-image-packaging
description: Use for packaging QEMU boot media from kernels, DTBs, firmware, bootloaders, root filesystems, modules, and raw or qcow2 images, while recording layout, offsets, write commands, hashes, and mutation policy.
---

# QEMU Image Packaging

Use this workflow to create or update QEMU boot media: SD, eMMC, raw disk, qcow2, pflash, NOR, NAND, firmware containers, or rootfs images.

## Primitive Composition

1. Use `qemu-flow-plan`.
2. Use `qemu-source-provenance` for every input artifact.
3. Use `qemu-image-layout` to define the target layout before writing.
4. Package on a scratch copy unless the user explicitly requests otherwise.
5. Verify the resulting image and update `image-layout.md`.

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

## Handoff

After packaging, provide a copy-pasteable path and the image contract to `qemu-boot-run` or a boot workflow. If boot fails, re-check the image layout before changing QEMU source.
