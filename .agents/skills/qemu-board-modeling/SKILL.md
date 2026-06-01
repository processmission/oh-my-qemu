---
name: qemu-board-modeling
description: Use for QEMU board, SoC, machine, memory map, boot path, FDT/ACPI, and IRQ topology modeling. Extends qemu-flow-plan and qemu-rlcr-loop; this skill only defines board-model decisions.
license: GPL-2.0-or-later
---

# QEMU Board and Machine Modeling

Use this domain skill when changing a QEMU machine or SoC: CPU clusters, memory maps, reset vectors, firmware/direct-kernel boot, FDT/ACPI, interrupt topology, and board-level device wiring.

## Flow dependencies

1. Start with `qemu-flow-plan` for non-trivial work.
2. Put all plans, boot logs, UART captures, FDT dumps, trace files, scratch scripts, and review notes under `build/agent/<task-slug>/`.
3. Use `qemu-rlcr-loop` for implementation/debugging rounds.
4. Use `qemu-build` for target binary builds.
5. Use `qemu-qtest` for machine creation and memory-map probes.
6. Use `qemu-debug` and `qemu-model-verification` for boot/runtime evidence.

No `.plan/`, `.humanize/`, root notes, or helper files in source directories.

## Hard policy boundary

Do not produce source code intended for QEMU upstream submission. QEMU currently declines contributions believed to include or derive from AI-generated content. Do not add DCO or review trailers.

## Board contract

A board model is topology and boot policy. A peripheral model is behavior.

The board should define:

- CPU type/count and reset state;
- RAM/ROM/MMIO/alias/unimplemented regions;
- interrupt controller graph and source numbers;
- clock/reset/bus wiring;
- firmware, direct-kernel, initrd, DTB/FDT, or ACPI boot policy;
- optional devices and user-visible machine properties.

The board should not emulate device register semantics.

## Required plan facts

Record these before implementation:

- compatibility target: board/SoC revision and intended firmware/SDK;
- closest upstream QEMU reference board;
- memory-map table with symbolic name, base, size, owner, IRQ, and type;
- boot ABI: entry point, reset vector, FDT pointer, privilege mode, RAM base;
- interrupt graph: CPU local interrupts, global controller contexts, cascades, MSI/PCI routing;
- known unimplemented regions and why they are safe for the workload.

## Realize order

Use dependency order:

1. machine/SoC state;
2. CPUs/harts;
3. root memory, RAM, ROM;
4. interrupt controllers and timers;
5. CPU interrupt inputs;
6. always-present devices;
7. MMIO maps and IRQ/clock/reset wiring;
8. optional devices;
9. firmware/kernel/initrd/DTB loading;
10. reset vector and reset hooks.

## Boot helper rule

Reuse architecture helpers before hand-rolling boot code. For example, RISC-V boards should prefer existing reset-vector and direct-kernel helpers unless the real hardware requires a custom ROM path. If firmware intentionally receives no FDT, model that intentionally instead of generating a fake one.

## Verification expectations

At minimum:

- target binary builds;
- qtest can instantiate the machine;
- qtest probes key MMIO bases or unimplemented regions;
- one representative IRQ path is tested when practical;
- boot smoke captures UART/console under `build/agent/<task-slug>/logs/`;
- image hashes and exact command lines are recorded.

## Anti-patterns

- Magic constants scattered through realize code.
- Device register behavior in board files.
- Fake FDT nodes for devices not actually modeled.
- Boot success caused only by globally ignoring invalid accesses.
- Adding many devices before CPU, timer, IRQ, and boot spine are proven.

## Upstream references

- QEMU code provenance and AI policy: `docs/devel/code-provenance.rst`.
- QEMU source layout: `docs/devel/codebase.rst`.
- GDB/debugging: `docs/system/gdb.rst`.
