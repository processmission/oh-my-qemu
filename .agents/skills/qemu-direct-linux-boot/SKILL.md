---
name: qemu-direct-linux-boot
description: Use for booting Linux directly with QEMU kernel, DTB, initrd, append, serial console, root filesystem, timeout, and shell markers, without traversing firmware or bootloader stages.
---

# QEMU Direct Linux Boot

Use this workflow when QEMU should load a kernel directly, usually with `-kernel`, `-dtb`, `-initrd`, and `-append`.

## Primitive Composition

1. Use `qemu-flow-plan`.
2. Use `qemu-source-provenance` for kernel, DTB, initrd, rootfs, and QEMU binary.
3. Use `qemu-boot-run` to construct and run the command.
4. Use `qemu-model-verification` to report the boot milestone.
5. Use `qemu-debug` if the run hangs or faults.

## Inputs to Confirm

- QEMU binary and machine name;
- CPU, SMP, memory, accelerator, and machine properties;
- kernel image type expected by the target architecture;
- DTB path or generated FDT policy;
- initrd or block rootfs path;
- kernel command line, especially `console=`, `root=`, `rdinit=`, `init=`, and early console settings;
- expected marker, such as a shell prompt, init banner, or workload output.

## Command Rules

- Keep the command copy-pasteable.
- Route serial output deterministically, usually with `-nographic`.
- Include a timeout for non-interactive smoke tests.
- Store the full console log under `.oh-my-qemu/<task-slug>/logs/`.
- When the goal is an interactive shell, provide the exact command separately from the timed smoke command.

## Success Criteria

Direct boot success should name the marker reached. Examples: kernel decompressed, init started, initramfs shell, login prompt, workload completed. Do not claim the board model is correct from a banner alone.
