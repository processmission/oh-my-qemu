---
name: qemu-peripheral-modeling
description: Use when implementing, refactoring, or debugging a QEMU peripheral, accelerator, or MMIO device model. Focuses on qdev/SysBusDevice structure, register semantics, IRQ/timer/DMA behavior, qtest contracts, and QEMU's AI/DCO policy boundaries.
license: GPL-2.0-or-later
---

# QEMU Peripheral Modeling

Use this skill when adding or changing a QEMU hardware block: UART/GPIO/PWM/timer/watchdog/DMA/accelerator/KPU-like engines, register banks, interrupt controllers, or any `hw/*` MMIO device.

## Hard policy boundary

Do not produce source code intended for QEMU upstream submission. QEMU currently declines contributions believed to include or derive from AI-generated content. You may help with research, debugging, analysis, test strategy, and review notes. Do not add `Signed-off-by` or any DCO-style trailer.

## Core rule

A real hardware block should be a first-class device, not ad hoc board glue or a generic scratch register bank. Board code wires topology; device code owns guest-visible behavior.

## Workflow

### 1. Bound the hardware block

Collect only the facts needed for this device:

- MMIO base(s), window size(s), endianness, and accepted access widths.
- Register reset values, read-only/write-only bits, write-one-clear bits, masks, aliases, and reserved behavior.
- IRQ outputs, DMA initiator behavior, clock/reset inputs, timers, and sideband buses.
- Existing stub boundary: which registers already exist, which reads are fake, and which guest behavior currently depends on them.
- Reference sources: datasheet, SDK driver, guest firmware, existing QEMU sibling devices, runtime traces.

If the current implementation is a placeholder, name the placeholder precisely in the plan.

### 2. Pick the QEMU object shape

Default to the boring QEMU pattern:

- `typedef struct FooState { SysBusDevice parent_obj; ... } FooState;`
- `OBJECT_DECLARE_SIMPLE_TYPE()` or nearby target/subsystem convention.
- `MemoryRegion mmio;` owned by the device.
- `qemu_irq irq;` or an array of IRQ outputs if hardware exposes multiple lines.
- `QEMUTimer *timer`, `Clock *clock`, DMA address-space references, or child buses only when the hardware needs them.
- Realize/reset hooks in the same style as nearby devices.
- `VMStateDescription` for migratable guest-visible state. Do not migrate pure caches.

### 3. Implement MMIO as a strict register contract

For every register, write down:

- width and unsupported-width behavior;
- reset value;
- read behavior;
- write behavior;
- side effects;
- guest-visible error behavior.

Implementation rules:

- Use constants for offsets, masks, shifts, reset values, and ID values.
- Keep the hot read/write path allocation-free: no formatting, dynamic strings, heap containers, or heavyweight lookups.
- Mask guest writes before storing them.
- Preserve reserved bits according to the reference; if unknown, prefer stable zero reads and ignored writes, with logging only when useful.
- Make status/IRQ transitions explicit: update status first, then raise/lower IRQ exactly once.
- Keep long-running work out of MMIO callbacks; use timers, bottom halves, worker state, or staged execution when needed.

### 4. Wire side effects deliberately

- IRQ: expose named output(s); board connects them to PLIC/GIC/etc.; device raises/lowers from status and enable bits.
- Timer: derive ticks from a QEMU clock/timer; reset stops timers and clears pending IRQ unless hardware says otherwise.
- DMA: use QEMU DMA/address-space helpers; validate guest addresses; never trust guest-provided pointers.
- Reset: reset all guest-visible registers and runtime state. Do not reset board-level wiring.

### 5. Keep board integration thin

Board/SoC code should only instantiate, set properties, map MMIO, connect IRQs/clocks/resets/buses, and expose firmware-visible nodes if the board owns FDT/ACPI.

If you need a board-specific quirk inside the device, make it an explicit property with a narrow name.

### 6. Verify in layers

Minimum gates for a new or materially changed peripheral:

1. qtest for register reset/read/write/mask behavior.
2. qtest for IRQ assertion/deassertion and reset behavior.
3. qtest or unit-style test for timer/DMA edge cases if present.
4. focused machine boot or firmware smoke only after qtest passes.
5. trace-driven runtime check for accelerators or undocumented command streams.

A boot log proves integration, not register correctness.

## Accelerator-specific checklist

- Identify command stream boundaries and command-memory ownership.
- Decode descriptors into typed internal operations before executing them.
- Separate frontend parsing from arithmetic/backend execution.
- Validate event counts, skipped operations, summaries, and guest-visible output.
- Compare SDK driver assumptions against runtime traces.
- Record binary/image hashes when validating patched SDK or firmware images.

## Anti-patterns

- Hiding a real device behind a generic register bank forever.
- Implementing device behavior in board files.
- Adding fake success paths so firmware boots while registers stay wrong.
- Treating matching trace count as end-to-end success.
- Adding broad abstractions before two concrete devices need them.
- Allocating or logging on every normal MMIO access.

## Upstream references

- QEMU code provenance and AI policy: `docs/devel/code-provenance.rst`.
- QEMU Object Model: `docs/devel/qom.rst` and `include/qom/object.h`.
- QEMU tracing infrastructure: `docs/devel/tracing.rst`.
