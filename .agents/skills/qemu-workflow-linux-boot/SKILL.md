---
name: qemu-workflow-linux-boot
description: Use for booting Linux in QEMU through either direct kernel loading or firmware and bootloader stages, selecting the path from task inputs while preserving provenance, boot logs, debug handoff, and verification evidence.
---

# QEMU Linux Boot

Use this workflow when the task is to boot Linux under QEMU and the request may
need either direct kernel loading or a firmware/bootloader chain.

## Path Selection

Classify the boot path before composing primitives:

- Use **direct Linux boot** when QEMU should load the kernel itself with options
  such as `-kernel`, `-dtb`, `-initrd`, and `-append`, without traversing
  firmware or bootloader stages.
- Use **firmware Linux boot** when Linux must be reached through BIOS, pflash,
  ROM, SPL, TPL, U-Boot, TF-A, EDK2, OpenSBI, vendor firmware, or boot media
  that firmware reads.
- If the user explicitly names a path, follow that path.
- If the request only asks for a fast Linux smoke boot and provides a kernel,
  prefer direct boot.
- If the request is validating a board's real boot chain, firmware behavior, or
  boot media layout, prefer firmware boot.
- If required artifacts are missing or the path is ambiguous, record the gap in
  the plan before running QEMU.

## Flow Composition

This workflow may compose these flow primitives as needed:

1. `qemu-plan` to freeze scope, artifact root, selected boot path, and
   acceptance criteria.
2. `qemu-source-provenance` for QEMU, kernel, DTB, initrd, rootfs, firmware,
   bootloader, and boot media inputs.
3. `qemu-image-layout` only when the selected path depends on boot media,
   pflash, ROM images, disks, partitions, or writable image state.
4. `qemu-boot-run` to construct the QEMU command, run it, capture logs, and
   classify the immediate result.
5. `qemu-debug` to isolate the failing stage if boot hangs or faults.
6. `qemu-model-verification` to report the reached Linux milestone.
7. `qemu-rlcr-loop` for staged implementation or debugging rounds when source
   or boot artifact changes are required.

The selected path determines the boot contract; do not run both paths unless
the task explicitly asks for comparison or fallback evidence.

## Direct Boot Contract

Record these inputs:

- QEMU binary and machine name;
- CPU, SMP, memory, accelerator, and machine properties;
- kernel image type expected by the target architecture;
- DTB path or generated FDT policy;
- initrd or block rootfs path;
- kernel command line, especially `console=`, `root=`, `rdinit=`, `init=`,
  and early console settings;
- expected marker, such as a shell prompt, init banner, or workload output.

Direct boot command rules:

- Keep the command copy-pasteable.
- Route serial output deterministically, usually with `-nographic`.
- Include a timeout for non-interactive smoke tests.
- Store the full console log under `.oh-my-qemu/<task-slug>/logs/`.
- When the goal is an interactive shell, provide the exact command separately
  from the timed smoke command.

## Firmware Boot Contract

Record these inputs:

- firmware, bootloader, kernel, DTB, rootfs, and QEMU inputs;
- boot media, pflash, ROM, or disk image expectations;
- serial markers for each firmware handoff stage;
- the first failing stage when boot stalls;
- the reached Linux milestone when boot succeeds.

Record each expected stage and marker:

- reset vector or ROM entry;
- first firmware console output;
- SPL/TPL or early loader milestone;
- trusted firmware or monitor handoff if present;
- bootloader prompt or autoboot path;
- boot media access;
- kernel entry;
- Linux console and rootfs or shell marker.

Firmware command rules:

- Keep firmware inputs and boot media inputs distinct in the command record.
- Record firmware environment assumptions and any interactive bootloader
  commands.
- Use disposable or refreshed images when firmware writes runtime state.
- Capture the entire serial log; summarize the first failing stage in
  `evidence.md`.
- If Linux uses a different console from firmware, state which QEMU chardev
  carries each log.

## Stage Milestones

For firmware implementation or debugging work, expose the stage checklist as
explicit milestones that an outer workflow can consume. The final Linux shell
or full boot result is the final acceptance criterion, not the default first
milestone.

Default firmware round boundaries are:

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

## Success Criteria

Boot success should name the marker reached. Examples: kernel decompressed,
init started, initramfs shell, login prompt, workload completed, or Linux shell.
Do not claim board or device correctness from a banner alone.

## Debug Handoff

For timeouts, narrow by path and stage before changing source:

- for direct boot, compare kernel command line, console, DTB, initrd/rootfs,
  and machine options before assuming model behavior is wrong;
- for firmware boot, compare image layout, firmware inputs, boot media access,
  and handoff markers before assuming model behavior is wrong;
- add `-S -s` or another gdbstub backend for guest state;
- add focused QEMU log flags or trace events;
- use instruction logs only around a bounded PC window when possible.
