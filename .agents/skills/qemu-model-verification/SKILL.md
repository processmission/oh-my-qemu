---
name: qemu-model-verification
description: Use when validating QEMU device or board models with qtest, runtime traces, firmware boot smoke tests, replay, and workload evidence. Helps separate model bugs from stale images, boot ABI issues, or guest failures.
license: GPL-2.0-or-later
---

# QEMU Model Verification

Use this skill when a model “seems implemented” but must be proven: peripheral registers, IRQs, board boot, firmware compatibility, KPU/GNNE-like accelerators, or TCG/runtime behavior.

## Hard policy boundary

Do not produce source code intended for QEMU upstream submission. QEMU currently declines contributions believed to include or derive from AI-generated content. You may help with research, debugging, analysis, and verification plans. Do not add `Signed-off-by` or any DCO-style trailer.

## Principle

State the exact behavior claim, then choose the narrowest evidence that can prove it.

Build success, typecheck success, or a boot banner is not proof of a hardware model. They are prerequisite signals only.

## Evidence ladder

Use the lowest rung that proves the claim, then climb only when necessary:

1. **Unit/MMIO test**: register masks, reset values, side effects.
2. **IRQ/timer/DMA test**: interrupt level, timer expiry, DMA memory effects.
3. **Bus/lifecycle test**: attach, map, realize, read/write through address space, unrealize.
4. **Board creation test**: machine instantiation and stable memory map.
5. **Firmware boot smoke**: firmware reaches expected milestone.
6. **Runtime trace validation**: device-specific events match expected sequence/count and no skip/error path fires.
7. **Workload validation**: application-level output proves the guest consumed the modeled hardware correctly.

Do not skip directly to runtime trace or workload validation for a new register model.

## qtest contract checklist

For each device or board change, cover the branches that can break:

- reset state;
- writable masks and reserved-bit behavior;
- read-only/write-only registers;
- unsupported access widths;
- status clear and write-one-clear paths;
- IRQ raise and lower;
- timer expiration and restart;
- DMA bounds/error behavior;
- bus attach/map/realize/unrealize;
- board memory-map read at key bases.

## Runtime smoke workflow

For firmware or application validation:

1. Record exact binary/image paths.
2. Record hashes or build IDs for every image under test.
3. Capture UART/console, device trace, and emulator stderr/QEMU log into separate files.
4. Use a bounded run; kill or confirm no lingering emulator/helper processes afterwards.
5. Preserve the command line in a log or report.
6. Check the expected positive marker and expected negative markers.

Negative markers include fatal exceptions, page faults, repeated probe failures, old build timestamps after a claimed SDK rebuild, device trace skip paths, missing IRQ completion, and timeout with no UART progress.

## Trace validation rules

For accelerators and reverse-engineered devices:

- Count expected events, but also inspect semantic summaries.
- Check for skipped/unknown instructions or descriptors.
- Verify command ranges, DMA windows, and output buffers.
- Correlate trace milestones with UART/application milestones.
- If trace closes but the application crashes, check image packaging and guest userspace before blaming the model.

## Failure triage

Classify failures before changing model code:

- **Environment**: missing binary, wrong target build, missing accel/toolchain, stale build directory.
- **Image provenance**: old firmware, wrong ROMFS, wrong kernel/initrd, stale SDK output.
- **Boot ABI**: wrong reset vector, FDT pointer, entry address, CPU extension, or RAM size.
- **Board topology**: MMIO base/size mismatch, IRQ source mismatch, missing clock/reset.
- **Device semantics**: wrong register side effect, status bit, IRQ clear, timer behavior, DMA handling.
- **Guest bug**: application crash unrelated to modeled hardware.

Only topology and device-semantics failures usually justify model source changes.

## Reporting format

When reporting a gate, include:

- PASS/FAIL/INCONCLUSIVE;
- command or test name;
- exact artifact paths;
- image hashes or build IDs when relevant;
- one or two decisive log excerpts;
- what the result proves;
- what it does not prove.

Avoid broad claims. “qtest covers reset and IRQ clear” is better than “device works”.

## Upstream references

- QEMU testing docs: `docs/devel/testing/`.
- QEMU tracing docs: `docs/devel/tracing.rst`.
- QEMU record/replay docs: `docs/system/replay.rst`.
- QEMU code provenance and AI policy: `docs/devel/code-provenance.rst`.
