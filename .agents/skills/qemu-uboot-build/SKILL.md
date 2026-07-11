---
name: qemu-uboot-build
description: Use for building U-Boot artifacts for QEMU firmware boot testing, including defconfig selection, cross compile variables, SPL/TPL, U-Boot proper, FIT or ITB files, BL31 or TF-A dependencies, logs, hashes, and provenance.
---

# QEMU U-Boot Build

Use this primitive when a QEMU task needs U-Boot, SPL, TPL, FIT, ITB, or firmware-chain artifacts.

## Primitive Boundary

This primitive owns only U-Boot build actions and output evidence: defconfig,
toolchain, external inputs, build command, logs, boot-stage artifacts, and
hashes. It consumes a U-Boot source tree and build goal supplied by the caller
and does not choose provenance, image packaging, or boot workflow steps.

## Build Flow

Record:

- U-Boot source path, revision, and dirty state;
- board defconfig and any config fragments;
- architecture, cross compiler prefix, compiler version, and output directory;
- external dependencies such as BL31, TEE, firmware blobs, device trees, or DDR init binaries;
- output artifacts such as `spl/u-boot-spl`, `u-boot`, `u-boot.bin`, `u-boot.itb`, or platform-specific combined images;
- exact command, log path, and hashes.

## Command Shape

Use local documentation first. Typical U-Boot patterns are:

```bash
make O=<out> <board_defconfig>
make O=<out> CROSS_COMPILE=<prefix> -j$(nproc)
```

If a firmware chain requires environment variables such as `BL31`, record their resolved paths and hashes before building.

## Output Rules

- Treat each boot stage as a separate provenance item.
- Do not assume a combined image contains the expected stage; inspect and record the packaging command.
- If firmware reaches U-Boot but Linux does not boot, separate U-Boot command/environment issues from QEMU model issues.
