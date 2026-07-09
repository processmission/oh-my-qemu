---
name: qmu-workflow-board-modeling
description: Use for QEMU board, SoC, machine, memory map, boot path, FDT/ACPI, and IRQ topology modeling. Extends qemu-plan and qemu-rlcr-loop; board work must add or extend qemu-qtest coverage for verification.
---

# QEMU Board and Machine Modeling

Use this domain skill when changing a QEMU machine or SoC: CPU clusters, memory maps, reset vectors, firmware/direct-kernel boot, FDT/ACPI, interrupt topology, and board-level device wiring.

## Flow dependencies

1. Start with `qemu-plan` for non-trivial work.
2. Put all plans, boot logs, UART captures, FDT dumps, trace files, scratch scripts, and review notes under `.oh-my-qemu/<task-slug>/`.
3. Before the first source mutation, MUST use `qemu-rlcr-loop` and keep
   implementation/debugging inside RLCR rounds.
4. Use `qemu-build` for target binary builds.
5. Use `qemu-qtest` to add or extend board qtest cases for machine creation, memory-map probes, and representative IRQ/device wiring.
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

## qtest verification requirement

Board-modeling work must be verified through `qemu-qtest`, not only through boot smoke. For every new board, SoC, memory-map change, reset-vector change, or IRQ topology change:

- add a new `tests/qtest/<board-or-soc>-test.c` case, or extend the closest existing board qtest;
- register it in `tests/qtest/meson.build` under the correct architecture bucket;
- instantiate the machine with the minimal arguments required for the board;
- probe key RAM/ROM/MMIO/unimplemented bases from the memory-map table;
- verify reset-visible state when qtest can observe it;
- test one representative interrupt/device wiring path when practical;
- run the narrow Meson qtest name from `build/`;
- store the command, result, and log path under `.oh-my-qemu/<task-slug>/`.

If a board change cannot be covered by qtest, record the technical reason in the plan and use `qemu-model-verification` for the replacement evidence. A firmware boot log is supplemental evidence, not a substitute for qtest coverage.

## Verification expectations

At minimum:

- target binary builds;
- `qemu-qtest` adds or extends a board case for the changed machine/SoC behavior;
- the qtest can instantiate the machine with minimal arguments;
- the qtest probes key MMIO/RAM/ROM/unimplemented bases from the memory-map table;
- the qtest covers one representative IRQ or device wiring path when practical;
- boot smoke captures UART/console under `.oh-my-qemu/<task-slug>/logs/` when firmware compatibility is in scope;
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
