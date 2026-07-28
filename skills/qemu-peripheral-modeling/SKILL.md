---
# SPDX-FileCopyrightText: Copyright (c) 2026 Process Mission
# SPDX-License-Identifier: MIT
name: qemu-peripheral-modeling
description: Use for QEMU peripheral, accelerator, MMIO, qdev, or SysBusDevice modeling with register contracts, an explicit register framework decision, and qtest-backed verification.
---

# QEMU Peripheral Modeling

## Audit workflow

For non-trivial workspace writes, use a stable
`.oh-my-qemu/<task-slug>/` directory and create only needed entries:

```text
.oh-my-qemu/<task-slug>/
├── audit.md      # Baseline, scope, decisions, evidence, verification, and gaps
├── commands.md   # Redacted commands, working directories, and results
├── logs/         # Decisive build, test, runtime, or diagnostic logs
├── scripts/      # Temporary scripts, probes, parsers, and harnesses
└── output/       # Generated deliverables, dependencies, and non-QEMU binaries
```

Before changing source or mutable artifacts, record the workspace root,
revision, `git status --short`, pre-existing changes, goal, scope, and
acceptance checks in `audit.md`. Log exact redacted commands and results in
`commands.md`; record revisions, configurations, tool versions, and hashes when
they affect reproducibility. Separate observations from inferences and edit
source only when requested.

Keep QEMU builds under source-root `builds/build-<target>/`; put third-party
dependencies and non-QEMU binaries in task `output/`. Before writing audit
artifacts or configuring QEMU in a Git worktree, add `.agents/`,
`.oh-my-qemu/`, and `builds/` to the repository-local file from
`git rev-parse --git-path info/exclude`; preserve existing entries and avoid
duplicates. Never stage or commit those directories. At handoff, verify them
absent from `git status --short`. Report the task directory and unresolved gaps.

## Workflow

1. Freeze the register, IRQ, DMA, reset, migration, and allowed-path contract.
2. When facts come from drivers, datasheets, firmware, or regfiles, extract a
   source-cited register contract before modeling; do not fill gaps from memory.
3. Work in small reviewable source-change rounds and record each round's paths,
   verification, review result, and gaps in `audit.md`.
4. Build the affected target and map each modeled behavior to focused qtests.
5. Use traces or workload evidence for integration claims and state what remains
   unproven.

## QEMU upstream boundary

QEMU's official GitLab and mailing lists are upstream project channels. A
patch becomes an upstream contribution when sent to the mailing-list recipients
selected through `MAINTAINERS`; do not prepare or send agent-generated patches
for that submission. Local branches, commits, patch files, pushes, and pull
requests are not by themselves QEMU upstream contributions. Perform those Git
actions only when requested and follow the workspace's Git policy.

## Device modeling contract

A real hardware block should be a first-class device. Board code wires topology; device code owns behavior.

For each device, define in `audit.md`:

- MMIO base(s), size(s), endianness, and accepted access widths;
- register reset values, masks, read/write behavior, W1C bits, aliases, and reserved-bit behavior;
- cross-register dependencies, feature flows, and register-bit combinations needed to enable or observe a function;
- IRQ outputs and level/edge semantics;
- timer, clock, reset, DMA, and bus dependencies;
- migration-visible state vs local caches;
- existing stub/unimplemented boundary;
- reference evidence: datasheet, SDK driver, firmware trace, sibling QEMU device.

When the source of truth is external to QEMU, do not begin modeling from memory or from a partial driver skim. Require a source-cited register contract with register facts, cross-register dependencies, behavioral sequences, conflicts, confidence levels, and qtest candidates.

## QEMU object shape

Default shape unless nearby code uses a clearer convention:

- `SysBusDevice` or the subsystem's existing base class;
- one owned `MemoryRegion` per register window;
- explicit `qemu_irq` outputs;
- reset/realize hooks in the local style;
- `VMStateDescription` for guest-visible migratable state;
- named properties only for real board/SoC variation.

Do not put register side effects in board files.

## Register bank framework decision

Before designing a guest-visible control/status register bank:

1. Read applicable policy files present in the target QEMU workspace.
2. If they do not decide, use the user's explicit compatible framework
   direction.
3. If neither decides, inspect nearby devices in the same subsystem for a clear
   maintained convention.
4. Select `RegisterInfo` or manual MMIO callbacks and record the evidence and
   rationale in `.oh-my-qemu/<task-slug>/audit.md`.

Stop at the first decisive input. Use `RegisterInfo` from the checked-out QEMU
tree as the default when none decides. Manual MMIO callbacks are permitted when
this decision gate justifies them; they are not a failure merely because they
do not use `RegisterInfo`.

For the `RegisterInfo` path, use the current tree rather than remembered API
signatures. QEMU versions can differ, so inspect the local implementation:

- read `include/hw/core/register.h` for the current `RegisterAccessInfo`, `RegisterInfo`, `RegisterInfoArray`, and `register_init_block*` API;
- read `include/hw/core/registerfields.h` for the current register/field macros;
- search the checked-out tree for `RegisterAccessInfo`, `register_init_block8`, `register_init_block32`, `register_init_block64`, `register_read_memory`, `register_write_memory`, `register_reset`, and `register_array_get_owner`;
- prefer examples in the same subsystem or nearby architecture before using generic examples;
- if a named reference path is absent in another QEMU version, re-search by symbol instead of assuming the old path.

Current-tree reference families to inspect first:

- simple register bank with callbacks and VMState:
  `hw/dma/xlnx-zynq-devcfg.c`; inspect its header only for public declarations,
  not as a location for new register definitions;
- IRQ/status register side effects: `hw/intc/xlnx-zynqmp-ipi.c`;
- wrapped read/write handlers that still delegate to `RegisterInfo`: `hw/misc/xlnx-versal-trng.c`;
- broader Xilinx-style banks: search `hw/misc`, `hw/dma`, `hw/intc`, `hw/nvram`, and `hw/rtc` for `register_init_block32`.

For either framework, keep the complete register definition in the device `.c`
file:

- register offset and field definitions from the registerfields macros;
- register storage sized from the register map;
- a matching `RegisterInfo` array and `RegisterAccessInfo` table when selected;
- the manual read/write callbacks and `MemoryRegionOps` when selected;
- register-local read, write, and reset hooks;
- reset logic appropriate to the selected framework;
- VMState for guest-visible register storage and other migratable state.

Do not put register offsets, field macros, `RegisterAccessInfo` tables,
backing storage, `RegisterInfo` arrays, or register semantics in a header. A
header may expose only non-register-layout declarations genuinely required
outside the device translation unit, such as a public QOM type or cross-unit
helper prototype.

When using `RegisterInfo`, use its hooks deliberately:

- use pre-write hooks to filter or transform a write before storage;
- use post-write hooks for IRQ/status/timer/DMA side effects after storage;
- use post-read hooks only for guest-visible read side effects;
- remember that register reset can call write hooks in this framework, so callbacks must be reset-safe.

When the decision selects `RegisterInfo`, a separate custom handler is
permitted for a non-register data aperture such as a FIFO data port, streaming
window, or RAM/ROM window. Record the reason; control/status registers in or
beside that window still delegate to `RegisterInfo`.

## MMIO rules

- Implement every control/status register through the selected framework.
- Use constants/macros for offsets, masks, shifts, reset values, and IDs.
- Keep normal read/write callbacks allocation-free.
- Represent RO, W1C, reserved, clear-on-read, and unimplemented bits without
  duplicating their semantics across callbacks.
- With `RegisterInfo`, use `RegisterAccessInfo` and hooks when the current API
  supports the required behavior.
- Update status before raising/lowering IRQ.
- Keep long-running work out of MMIO callbacks; use timers, bottom halves, workers, or staged execution.
- Validate guest DMA addresses with QEMU address-space/DMA helpers.
- Never edit generated files under `builds/build-<target>/`; fix register
  definitions or source inputs instead.

## qtest expectations

Every material peripheral change should have narrow qtest coverage for:

- reset values;
- read/write masks and reserved bits;
- unsupported access widths when guest-visible;
- W1C/status clear behavior;
- IRQ assert/deassert paths;
- virtual clock behavior for timers;
- DMA memory effects when applicable.
- selected-framework reset and side-effect callback behavior.

## Accelerator addendum

For command-stream or accelerator blocks:

- separate descriptor parsing from execution;
- record command ranges, DMA windows, and output buffers;
- validate skipped/unknown operation counts;
- correlate trace milestones with guest-visible output;
- record image hashes under `.oh-my-qemu/<task-slug>/audit.md`.

## Anti-patterns

- Generic scratch register banks for real devices.
- Selecting a register framework without recording the decision gate evidence.
- Manual MMIO callbacks with no target-workspace, user, or nearby-subsystem
  justification.
- Copying stale `RegisterInfo` function signatures from memory when that
  framework is selected.
- Register definitions, field macros, backing storage, access tables, or
  register hooks in a header instead of the device `.c` file.
- Fake success paths that only make firmware boot.
- Board-specific behavior hidden in MMIO callbacks.
- Trace-count-only success claims.
- Logging or allocation on every normal MMIO access.

## Upstream references

- QEMU code provenance and AI policy: `docs/devel/code-provenance.rst`.
- QOM and qdev conventions: QEMU `docs/devel/` and nearby `hw/*` devices.
- RegisterInfo API: `include/hw/core/register.h`.
- Register field macros: `include/hw/core/registerfields.h`.
- Tracing: `docs/devel/tracing.rst`.
