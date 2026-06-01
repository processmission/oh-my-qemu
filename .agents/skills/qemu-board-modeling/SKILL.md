---
name: qemu-board-modeling
description: Use when adding or changing a QEMU board, SoC, machine, memory map, boot path, or firmware-visible device topology. Focuses on clean board/device separation, reset-vector/FDT handling, IRQ topology, and boot verification under QEMU policy constraints.
license: GPL-2.0-or-later
---

# QEMU Board and Machine Modeling

Use this skill when the task touches a QEMU machine or SoC: RISC-V `virt`-style boards, K230-like SDK-compatible boards, LoongArch `virt`, CPU clusters, memory maps, reset vectors, FDT/ACPI, interrupt topology, or board-level device wiring.

## Hard policy boundary

Do not produce source code intended for QEMU upstream submission. QEMU currently declines contributions believed to include or derive from AI-generated content. You may help with design notes, research, debugging, and verification strategy. Do not add `Signed-off-by` or any DCO-style trailer.

## Core rule

A board model is topology and boot policy. A peripheral model is behavior. Do not mix them.

The board should answer:

- what CPUs exist;
- what memory regions exist;
- which devices are present;
- where MMIO windows are mapped;
- how IRQs/clocks/resets/buses connect;
- how firmware or a direct kernel starts.

The board should not emulate register semantics for a device.

## Workflow

### 1. Define the compatibility target

Before editing or reviewing code, write down:

- SoC/board name and revision.
- Firmware/SDK expectation: BIOS, SPL/U-Boot, OpenSBI, direct kernel, RTOS image, or Linux kernel.
- CPU model, hart/core count, privilege level expectations, and required extensions.
- Whether FDT/ACPI is generated, supplied, omitted, or passed as zero.
- Existing QEMU board that is the closest reference.

For SDK-compatible boards, prefer compatibility with the real SDK boot chain over cosmetic naming.

### 2. Build a memory-map table first

Use a static table/enum rather than scattered constants. Each entry should carry:

- symbolic name;
- base address;
- size;
- owning device or placeholder;
- IRQ source if fixed;
- whether the region is RAM, ROM, MMIO, alias, or unimplemented.

Use the table for mapping and tests so the map cannot drift.

### 3. Realize in dependency order

Typical order:

1. allocate machine/SoC state;
2. create CPU cluster/harts;
3. create root memory and RAM/ROM regions;
4. create interrupt controllers and timer blocks;
5. connect CPU interrupt inputs;
6. instantiate always-present devices;
7. map MMIO and connect IRQs/clocks/resets;
8. create optional user-configured devices;
9. load firmware/kernel/initrd/DTB;
10. install reset vector and reset hooks.

If a later device needs an IRQ sink from an interrupt controller, create and wire the controller first.

### 4. Reuse architecture boot helpers

Do not hand-roll reset-vector code when the architecture already has a helper.

For RISC-V boards, use existing helpers such as `riscv_setup_rom_reset_vec()` and direct-kernel setup paths unless the hardware demonstrably requires a custom ROM. If the target boot flow intentionally omits FDT, pass the documented zero/null value instead of generating a fake FDT.

For LoongArch-style virt machines, keep QEMU `virt` behavior as the reference for direct kernel boot ABI, firmware address layout, FDT nodes, interrupt controllers, PCI/virtio expectations, and CPU reset state.

### 5. Treat IRQ topology as a graph

Document and then wire:

- per-CPU local interrupts: software, timer, external;
- global interrupt controller contexts;
- device source numbers;
- cascaded controllers;
- MSI or PCI interrupt routing;
- level vs edge semantics.

Test at least one device interrupt through the full path when possible. Do not stop at “device raises an IRQ” if the CPU never observes it.

### 6. Use unimplemented devices deliberately

An unimplemented MMIO placeholder is acceptable only when it is explicit and bounded:

- it exists to let firmware probe past a block;
- it has the right base and size;
- it has a stable device name;
- it behaves consistently with nearby QEMU unimplemented devices;
- it is tracked as a known fidelity gap.

Do not use placeholders for blocks whose semantics the requested workload depends on.

### 7. Keep build-system and docs in the same cutover

A board is not complete until directly affected artifacts agree:

- `hw/*/meson.build` and `Kconfig` entries;
- machine type registration;
- headers/state structs;
- qtest entries;
- system docs if the board is user-visible;
- default CPU/RAM constraints;
- firmware path documentation if non-obvious.

### 8. Verify from narrow to broad

Minimum gates:

1. build the touched target binary;
2. qtest for machine creation and device map reads;
3. boot smoke with the intended firmware/kernel;
4. UART/console log capture;
5. trace or IRQ evidence for any newly wired device;
6. no lingering emulator/helper process after bounded runs.

If boot fails, classify the failure before changing model code: environment, stale image, boot ABI, memory map, missing interrupt/timer, or peripheral semantics gap.

## Anti-patterns

- Magic MMIO constants embedded directly in realize code.
- Device behavior in board files.
- Custom reset-vector assembly without checking existing helpers.
- Fake FDT nodes that do not match actual devices.
- A board that “boots” only because invalid accesses are ignored globally.
- Adding many devices before the interrupt and boot spine is proven.

## Upstream references

- QEMU code provenance and AI policy: `docs/devel/code-provenance.rst`.
- QEMU source layout: `docs/devel/codebase.rst`.
- QEMU gdbstub/debugging: `docs/system/gdb.rst`.
