---
name: qemu-workflow-peripheral-modeling
description: Use for QEMU peripheral, accelerator, MMIO, qdev, or SysBusDevice modeling. Extends qemu-plan and qemu-rlcr-loop; register-bank modeling must use QEMU's registerinfo framework and qtest verification.
---

# QEMU Peripheral Modeling

Use this domain skill for QEMU hardware blocks: MMIO devices, SysBus/qdev peripherals, interrupt controllers, timers, DMA engines, GPIO/PWM/UART/watchdog blocks, and accelerator-like devices.

## Flow dependencies

1. Start with `qemu-plan` for any non-trivial work.
2. If register facts come from drivers, datasheets, firmware filesystems, or regfiles, run `qemu-register-extraction` first and use its `register-extraction.md` as the source contract.
3. Store all plans, traces, scratch scripts, logs, review notes, and decoded dumps under `.oh-my-qemu/<task-slug>/`.
4. Before the first source mutation, MUST use `qemu-rlcr-loop` and keep
   implementation/debugging inside RLCR rounds.
5. Use `qemu-build` and `qemu-qtest` for build and qtest gates.
6. Use `qemu-model-verification` for runtime/trace/workload evidence.

Do not create `.plan/`, `.humanize/`, root-level notes, or helper files inside QEMU source directories.

## Hard policy boundary

Do not produce source code intended for QEMU upstream submission. QEMU currently declines contributions believed to include or derive from AI-generated content. Do not add DCO or review trailers.

## Device modeling contract

A real hardware block should be a first-class device. Board code wires topology; device code owns behavior.

For each device, define in the plan:

- MMIO base(s), size(s), endianness, and accepted access widths;
- register reset values, masks, read/write behavior, W1C bits, aliases, and reserved-bit behavior;
- cross-register dependencies, feature flows, and register-bit combinations needed to enable or observe a function;
- IRQ outputs and level/edge semantics;
- timer, clock, reset, DMA, and bus dependencies;
- migration-visible state vs local caches;
- existing stub/unimplemented boundary;
- reference evidence: datasheet, SDK driver, firmware trace, sibling QEMU device.

When the source of truth is external to QEMU, do not begin modeling from memory or from a partial driver skim. Require a completed `qemu-register-extraction` markdown handoff with register facts, cross-register dependencies, behavioral sequences, conflicts, confidence levels, and qtest candidates.

## QEMU object shape

Default shape unless nearby code uses a clearer convention:

- `SysBusDevice` or the subsystem's existing base class;
- one owned `MemoryRegion` per register window;
- explicit `qemu_irq` outputs;
- reset/realize hooks in the local style;
- `VMStateDescription` for guest-visible migratable state;
- named properties only for real board/SoC variation.

Do not put register side effects in board files.

## RegisterInfo framework requirement

For any peripheral with a guest-visible register bank, the model must be built around QEMU's registerinfo framework from the checked-out QEMU tree. Manual offset-switch MMIO callbacks are not acceptable for normal register banks.

Use the current tree, not remembered API signatures. QEMU versions can differ, so before designing code, inspect the local implementation:

- read `include/hw/core/register.h` for the current `RegisterAccessInfo`, `RegisterInfo`, `RegisterInfoArray`, and `register_init_block*` API;
- read `include/hw/core/registerfields.h` for the current register/field macros;
- search the checked-out tree for `RegisterAccessInfo`, `register_init_block8`, `register_init_block32`, `register_init_block64`, `register_read_memory`, `register_write_memory`, `register_reset`, and `register_array_get_owner`;
- prefer examples in the same subsystem or nearby architecture before using generic examples;
- if a named reference path is absent in another QEMU version, re-search by symbol instead of assuming the old path.

Current-tree reference families to inspect first:

- simple register bank with callbacks and VMState: `hw/dma/xlnx-zynq-devcfg.c` plus `include/hw/dma/xlnx-zynq-devcfg.h`;
- IRQ/status register side effects: `hw/intc/xlnx-zynqmp-ipi.c`;
- wrapped read/write handlers that still delegate to registerinfo: `hw/misc/xlnx-versal-trng.c`;
- broader Xilinx-style banks: search `hw/misc`, `hw/dma`, `hw/intc`, `hw/nvram`, and `hw/rtc` for `register_init_block32`.

The model should normally have:

- register offset and field definitions from the registerfields macros;
- register storage sized from the register map;
- a matching `RegisterInfo` array;
- a `RegisterAccessInfo` table describing name, address, reset value, read-only bits, write-one-clear bits, reserved bits, unimplemented bits, and register hooks;
- `MemoryRegionOps` using `register_read_memory` and `register_write_memory`, or thin wrappers that normalize version/SoC quirks and then delegate to registerinfo;
- reset logic that resets the registerinfo entries according to the current tree's convention;
- VMState for guest-visible register storage and other migratable state.

Use registerinfo hooks deliberately:

- use pre-write hooks to filter or transform a write before storage;
- use post-write hooks for IRQ/status/timer/DMA side effects after storage;
- use post-read hooks only for guest-visible read side effects;
- remember that register reset can call write hooks in this framework, so callbacks must be reset-safe.

If a device cannot use registerinfo for a particular window, record the technical reason in `.oh-my-qemu/<task-slug>/plan.md`. The exception must be narrow, and any custom handler should still delegate to registerinfo for ordinary registers.

## MMIO rules

- Use registerinfo for ordinary register-bank reads/writes.
- Use constants/macros for offsets, masks, shifts, reset values, and IDs.
- Keep normal read/write callbacks allocation-free.
- Represent RO, W1C, reserved, clear-on-read, and unimplemented bits in `RegisterAccessInfo` whenever the current API supports them.
- Mask or transform guest writes through registerinfo hooks, not duplicated ad hoc logic.
- Update status before raising/lowering IRQ.
- Keep long-running work out of MMIO callbacks; use timers, bottom halves, workers, or staged execution.
- Validate guest DMA addresses with QEMU address-space/DMA helpers.
- Never edit generated files under `build/`; fix register definitions or source inputs instead.

## qtest expectations

Every material peripheral change should have narrow qtest coverage for:

- reset values;
- read/write masks and reserved bits;
- unsupported access widths when guest-visible;
- W1C/status clear behavior;
- IRQ assert/deassert paths;
- virtual clock behavior for timers;
- DMA memory effects when applicable.
- registerinfo reset/hook behavior for registers with side effects;

## Accelerator addendum

For command-stream or accelerator blocks:

- separate descriptor parsing from execution;
- record command ranges, DMA windows, and output buffers;
- validate skipped/unknown operation counts;
- correlate trace milestones with guest-visible output;
- record image hashes under `.oh-my-qemu/<task-slug>/evidence.md`.

## Anti-patterns

- Generic scratch register banks for real devices.
- Manual offset-switch MMIO handlers for ordinary register banks instead of registerinfo.
- Copying stale registerinfo function signatures from memory instead of inspecting the checked-out tree.
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
