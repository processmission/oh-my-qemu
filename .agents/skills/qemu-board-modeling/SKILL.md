---
name: qemu-board-modeling
description: Use for QEMU board, SoC, machine, memory map, boot path, FDT/ACPI, and IRQ topology modeling with qtest-backed verification of machine creation, memory maps, and representative device wiring.
---

# QEMU Board and Machine Modeling

Use this domain skill when changing a QEMU machine or SoC: CPU clusters, memory maps, reset vectors, firmware/direct-kernel boot, FDT/ACPI, interrupt topology, and board-level device wiring.

## Audit workflow

For every non-trivial task that writes to the workspace, choose a stable task
slug and keep all agent-only records under `.oh-my-qemu/<task-slug>/`. Create
only the entries the task needs:

```text
.oh-my-qemu/<task-slug>/
├── audit.md      # Baseline, scope, decisions, evidence, verification, and gaps
├── commands.md   # Redacted commands, working directories, and results
├── logs/         # Decisive build, test, runtime, or diagnostic logs
├── scripts/      # Temporary scripts, probes, parsers, and harnesses
└── output/       # Generated deliverables, dependencies, and non-QEMU binaries
```

Before changing source or mutable artifacts, record the workspace root,
branch/revision, `git status --short`, user-owned dirty paths, goal, scope, and
acceptance checks in `audit.md`. Record exact redacted commands and results in
`commands.md`; record source revisions, configurations, tool versions, and
input/output hashes when they affect reproducibility. Separate observations
from inferences and create or change source files only when requested.

Put every QEMU build in a named directory under the QEMU source root, such as
`builds/build-aarch64/`. Put third-party dependency artifacts and non-QEMU
binaries under the task's `output/` directory. In a Git worktree, before
writing audit records or configuring QEMU, add `.agents/`, `.oh-my-qemu/`, and
`builds/` to the repository-local exclude file returned by
`git rev-parse --git-path info/exclude`; preserve existing entries and avoid
duplicates. Never stage or commit those directories. Before handoff, verify
that `git status --short` contains none of them, then report the task directory
and unresolved gaps.

## Workflow

1. Freeze the board contract, allowed paths, and observable acceptance checks.
2. Inspect the current machine, nearby boards, tests, boot ABI, and authoritative
   hardware sources before changing code.
3. Work in small reviewable source-change rounds and record each round's paths,
   verification, review result, and gaps in `audit.md`.
4. Build the affected target and add or extend board qtests for machine
   creation, memory-map probes, and representative IRQ/device wiring.
5. Use boot or workload evidence only as a supplemental integration gate and
   state exactly what it proves.

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

Board-modeling work must be verified through focused qtests, not only through boot smoke. For every new board, SoC, memory-map change, reset-vector change, or IRQ topology change:

- add a new `tests/qtest/<board-or-soc>-test.c` case, or extend the closest existing board qtest;
- register it in `tests/qtest/meson.build` under the correct architecture bucket;
- instantiate the machine with the minimal arguments required for the board;
- probe key RAM/ROM/MMIO/unimplemented bases from the memory-map table;
- verify reset-visible state when qtest can observe it;
- test one representative interrupt/device wiring path when practical;
- run the narrow Meson qtest name from the matching
  `builds/build-<target>/` directory;
- store the command, result, and log path under `.oh-my-qemu/<task-slug>/`.

If a board change cannot be covered by qtest, record the technical reason and replacement evidence in `audit.md`. A firmware boot log is supplemental evidence, not a substitute for qtest coverage.

## Verification expectations

At minimum:

- target binary builds;
- a focused qtest adds or extends a board case for the changed machine/SoC behavior;
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
