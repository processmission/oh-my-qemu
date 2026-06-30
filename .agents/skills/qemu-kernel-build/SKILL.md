---
name: qemu-kernel-build
description: Use for building Linux kernels for QEMU boot testing, including defconfig selection, cross compile variables, Docker or host toolchains, Image, DTB, modules, initramfs inputs, output hashes, and provenance records.
---

# QEMU Kernel Build

Use this workflow when a QEMU task needs a Linux kernel artifact to boot or debug a modeled board.

## Primitive Composition

1. Use `qemu-flow-plan` for scope, acceptance criteria, and artifact root.
2. Use `qemu-source-provenance` before building.
3. Build the kernel with the local tree's documented method.
4. Update `source-provenance.md` with produced `Image`, `vmlinux`, DTBs, modules, initramfs inputs, and hashes.
5. Hand off to `qemu-direct-linux-boot`, `qemu-firmware-linux-boot`, or `qemu-image-packaging`.

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
