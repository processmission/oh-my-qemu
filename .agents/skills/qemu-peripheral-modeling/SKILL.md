---
name: qemu-peripheral-modeling
description: Use for QEMU peripheral, accelerator, MMIO, qdev, or SysBusDevice modeling. Extends qemu-flow-plan and qemu-rlcr-loop; this skill only defines device-model decisions and verification expectations.
license: GPL-2.0-or-later
---

# QEMU Peripheral Modeling

Use this domain skill for QEMU hardware blocks: MMIO devices, SysBus/qdev peripherals, interrupt controllers, timers, DMA engines, GPIO/PWM/UART/watchdog blocks, and accelerator-like devices.

## Flow dependencies

1. Start with `qemu-flow-plan` for any non-trivial work.
2. Store all plans, traces, scratch scripts, logs, review notes, and decoded dumps under `build/agent/<task-slug>/`.
3. Use `qemu-rlcr-loop` for implementation/debugging rounds.
4. Use `qemu-build` and `qemu-qtest` for build and qtest gates.
5. Use `qemu-model-verification` for runtime/trace/workload evidence.

Do not create `.plan/`, `.humanize/`, root-level notes, or helper files inside QEMU source directories.

## Hard policy boundary

Do not produce source code intended for QEMU upstream submission. QEMU currently declines contributions believed to include or derive from AI-generated content. Do not add DCO or review trailers.

## Device modeling contract

A real hardware block should be a first-class device. Board code wires topology; device code owns behavior.

For each device, define in the plan:

- MMIO base(s), size(s), endianness, and accepted access widths;
- register reset values, masks, read/write behavior, W1C bits, aliases, and reserved-bit behavior;
- IRQ outputs and level/edge semantics;
- timer, clock, reset, DMA, and bus dependencies;
- migration-visible state vs local caches;
- existing stub/unimplemented boundary;
- reference evidence: datasheet, SDK driver, firmware trace, sibling QEMU device.

## QEMU object shape

Default shape unless nearby code uses a clearer convention:

- `SysBusDevice` or the subsystem's existing base class;
- one owned `MemoryRegion` per register window;
- explicit `qemu_irq` outputs;
- reset/realize hooks in the local style;
- `VMStateDescription` for guest-visible migratable state;
- named properties only for real board/SoC variation.

Do not put register side effects in board files.

## MMIO rules

- Use constants for offsets, masks, shifts, reset values, and IDs.
- Keep normal read/write callbacks allocation-free.
- Mask guest writes before storing them.
- Update status before raising/lowering IRQ.
- Keep long-running work out of MMIO callbacks; use timers, bottom halves, workers, or staged execution.
- Validate guest DMA addresses with QEMU address-space/DMA helpers.

## qtest expectations

Every material peripheral change should have narrow qtest coverage for:

- reset values;
- read/write masks and reserved bits;
- unsupported access widths when guest-visible;
- W1C/status clear behavior;
- IRQ assert/deassert paths;
- virtual clock behavior for timers;
- DMA memory effects when applicable.

## Accelerator addendum

For command-stream or accelerator blocks:

- separate descriptor parsing from execution;
- record command ranges, DMA windows, and output buffers;
- validate skipped/unknown operation counts;
- correlate trace milestones with guest-visible output;
- record image hashes under `build/agent/<task-slug>/evidence.md`.

## Anti-patterns

- Generic scratch register banks for real devices.
- Fake success paths that only make firmware boot.
- Board-specific behavior hidden in MMIO callbacks.
- Trace-count-only success claims.
- Logging or allocation on every normal MMIO access.

## Upstream references

- QEMU code provenance and AI policy: `docs/devel/code-provenance.rst`.
- QOM and qdev conventions: QEMU `docs/devel/` and nearby `hw/*` devices.
- Tracing: `docs/devel/tracing.rst`.
