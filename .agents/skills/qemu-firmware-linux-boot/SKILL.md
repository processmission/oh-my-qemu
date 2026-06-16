---
name: qemu-firmware-linux-boot
description: Use for booting Linux through firmware or bootloader stages in QEMU, including BIOS, pflash, ROM, SPL, TPL, U-Boot, TF-A, EDK2, boot media, serial logs, timeout markers, and debug handoff.
---

# QEMU Firmware Linux Boot

Use this workflow when Linux must be reached through firmware or bootloader code rather than direct kernel loading.

## Primitive Composition

1. Use `qemu-flow-plan`.
2. Use `qemu-source-provenance` for firmware, bootloader, kernel, DTB, rootfs, and QEMU.
3. Use `qemu-image-layout` for boot media, pflash, ROM, or disk images.
4. Use `qemu-boot-run` to run and log the firmware path.
5. Use `qemu-debug` to isolate the failing stage if boot stalls.
6. Use `qemu-model-verification` to report the reached milestone.

## Stage Checklist

Record each expected stage and marker:

- reset vector or ROM entry;
- first firmware console output;
- SPL/TPL or early loader milestone;
- trusted firmware or monitor handoff if present;
- bootloader prompt or autoboot path;
- kernel entry;
- Linux console and rootfs or shell marker.

## Command Rules

- Keep firmware inputs and boot media inputs distinct in the command record.
- Record firmware environment assumptions and any interactive bootloader commands.
- Use disposable or refreshed images when firmware writes runtime state.
- Capture the entire serial log; summarize the first failing stage in `evidence.md`.
- If Linux uses a different console from firmware, state which QEMU chardev carries each log.

## Debug Handoff

For timeouts, narrow by stage before changing source:

- add `-S -s` or another gdbstub backend for guest state;
- add focused QEMU log flags or trace events;
- use instruction logs only around a bounded PC window when possible;
- compare image layout and firmware inputs before assuming model behavior is wrong.
