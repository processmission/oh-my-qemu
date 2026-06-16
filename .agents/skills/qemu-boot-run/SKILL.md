---
name: qemu-boot-run
description: Use as a QEMU workflow primitive to construct, run, log, and classify reproducible QEMU boot commands for kernels, firmware, disks, initramfs images, serial consoles, timeouts, and success or failure markers.
---

# QEMU Boot Run

Use this primitive whenever the task is to run QEMU and observe a boot milestone, whether the boot path is direct kernel boot, firmware boot, a guest OS shell, a test appliance, or a boot hang reproducer.

## Composition

1. Start from `qemu-flow-plan`.
2. Use `qemu-source-provenance` for binaries, images, DTBs, kernels, initramfs, and firmware.
3. Use `qemu-image-layout` for boot media or flash images.
4. Write the runnable command and result to `build/agent/<task-slug>/boot-run.md`.
5. Use `qemu-debug` on failures and `qemu-model-verification` for final claims.

## Command Record

Record:

- QEMU binary path and build directory;
- machine, CPU, accelerator, SMP, memory, and machine properties;
- kernel, firmware, DTB, initrd, disk, pflash, or block device inputs;
- serial, monitor, display, networking, and storage options;
- kernel command line or firmware environment assumptions;
- timeout, expected success marker, and known failure markers;
- console log path under `build/agent/<task-slug>/logs/`.

## Run Rules

- Prefer a single copy-pasteable command.
- Use `-nographic` or explicit chardev routing for deterministic console capture.
- Keep QEMU monitor and guest serial behavior clear; do not hide which console carries Linux logs.
- Use `timeout` for smoke tests unless an interactive shell is the requested deliverable.
- Preserve exact output in a log file and summarize only decisive lines in `evidence.md`.
- If a run hangs, capture the last meaningful marker before adding debug flags.

## Failure Handoff

When a run fails or times out, classify the first suspect before editing source:

- wrong or stale artifact;
- image layout mismatch;
- QEMU command mismatch;
- boot ABI or firmware handoff mismatch;
- missing device behavior;
- guest OS or rootfs issue.

Then use `qemu-debug` with a focused window: guest gdbstub, host debugger, QEMU log flags, trace events, or instruction logs.
