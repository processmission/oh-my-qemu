---
name: qemu-kernel-build
description: Use for building Linux kernels for QEMU boot testing, including defconfig selection, cross compile variables, Docker or host toolchains, Image, DTB, modules, initramfs inputs, output hashes, and provenance records.
---

# QEMU Kernel Build

Use this primitive when a QEMU task needs a Linux kernel artifact to boot or debug a modeled board.

## Primitive Boundary

This primitive owns only Linux kernel build actions and output evidence:
configuration, toolchain, build command, logs, produced kernel artifacts,
modules, DTBs, and hashes. It consumes a kernel source tree and build goal
supplied by the caller and does not choose provenance, packaging, or boot
workflow steps.

## Build Flow

Record and verify:

- kernel source path, revision, and dirty state;
- architecture, cross compiler prefix, compiler path, and version;
- defconfig and any config fragment or manual `.config` change;
- output directory, build command, and parallelism;
- DTB names and destination paths;
- module install path if modules are needed;
- initramfs or rootfs source if the boot command depends on it.

## Command Shape

Use the kernel tree's preferred commands. Typical Linux patterns are:

```bash
make ARCH=<arch> O=<out> <defconfig>
make ARCH=<arch> O=<out> CROSS_COMPILE=<prefix> -j$(nproc) Image modules dtbs
```

If Docker is used, record image, mounts, user, working directory, and the command run inside the container.

## Output Rules

- Do not mix outputs from different kernel revisions without recording it.
- Hash the exact files passed to QEMU or packed into an image.
- Keep build logs under `.oh-my-qemu/<task-slug>/logs/`.
- If the kernel boots but modules fail to load, verify kernel release and module tree before changing QEMU.
