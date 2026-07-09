---
name: qemu-firmware-linux-boot
description: Use for booting Linux through firmware or bootloader stages in QEMU, including BIOS, pflash, ROM, SPL, TPL, U-Boot, TF-A, EDK2, boot media, serial logs, timeout markers, and debug handoff.
---

# QEMU Firmware Linux Boot

Use this primitive when Linux must be reached through firmware or bootloader code rather than direct kernel loading.

## Primitive Boundary

This skill describes only the firmware-to-Linux boot path contract:

- firmware, bootloader, kernel, DTB, rootfs, and QEMU inputs;
- boot media, pflash, ROM, or disk image expectations;
- serial markers for each firmware handoff stage;
- the first failing stage when boot stalls;
- the reached Linux milestone when boot succeeds.

Do not use this skill to orchestrate other flow primitives. Dynamic workflow
skills decide whether and how to combine this primitive with other
primitives.

## Stage Checklist

Record each expected stage and marker:

- reset vector or ROM entry;
- first firmware console output;
- SPL/TPL or early loader milestone;
- trusted firmware or monitor handoff if present;
- bootloader prompt or autoboot path;
- boot media access;
- kernel entry;
- Linux console and rootfs or shell marker.

## Stage Milestones

For implementation or debugging work, expose the stage checklist as explicit
milestones that an outer workflow can consume. The final Linux shell or full
boot result is the final acceptance criterion, not the default first
milestone.

Default round boundaries are:

- reset vector or ROM entry;
- early firmware services;
- SPL/TPL or early loader milestone;
- trusted firmware or monitor handoff if present;
- bootloader entry or autoboot path;
- boot media access;
- kernel entry;
- Linux console and rootfs or shell marker;
- documentation or handoff notes.

Each milestone must name:

- the expected serial, trace, or debugger marker;
- the current verification gate;
- the next firmware handoff stage it unlocks.

By default, a single debugging or implementation step should not span more
than one firmware handoff stage. If it must cross stages, record why before
making changes.

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
