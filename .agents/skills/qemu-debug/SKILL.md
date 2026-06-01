---
name: qemu-debug
description: Use when debugging QEMU itself or a guest running under QEMU. Covers gdbstub, QEMU logs, trace events, replay, one-insn-per-tb, device/TCG instrumentation, and bounded evidence collection.
license: GPL-2.0-or-later
---

# QEMU Debug

Use this skill for QEMU failures involving guest boot hangs, crashes, wrong device behavior, TCG translation bugs, migration/runtime assertions, or hard-to-reproduce execution paths.

## Hard policy boundary

Do not produce source code intended for QEMU upstream submission. QEMU currently declines contributions believed to include or derive from AI-generated content. You may help with debugging, reproduction, analysis, and verification. Do not add `Signed-off-by` or any DCO-style trailer.

## First classify the debug target

Before choosing tools, identify what is being debugged:

- **Guest code**: kernel, firmware, bootloader, RTOS, or user workload.
- **QEMU device model**: MMIO, IRQ, DMA, reset, migration, timers.
- **QEMU core/runtime**: main loop, block, chardev, memory API, QOM lifecycle.
- **TCG frontend**: guest instruction decode/translation.
- **TCG backend**: host code emission, constraints, register allocation, optional op support.
- **Environment/image**: stale firmware, wrong build directory, wrong binary, wrong command line.

Do not assume a model bug until image provenance and command line are known.

## Guest debugging with gdbstub

Use QEMU's gdbstub for guest state:

- `-s` opens TCP port 1234.
- `-S` starts QEMU paused until GDB continues.
- `-gdb dev` selects a different backend, e.g. `-gdb tcp::3117` or a chardev/unix socket.
- For multi-cluster systems use GDB `target extended-remote`, `add-inferior`, `inferior N`, `attach N`, and `set schedule-multiple on`.
- For system emulation, decide whether symbols correspond to firmware, kernel, module, or userspace. Relocated code needs relocated symbols or disabled ASLR.

Useful GDB checks:

- `info reg`
- disassemble at PC (`x/10i $pc`, architecture-specific aliases as needed)
- memory at virtual address
- gdbstub physical memory mode via `maintenance packet qqemu.PhyMemMode` and `Qqemu.PhyMemMode:1`
- single-step mask via `maintenance packet qqemu.sstepbits`, `qqemu.sstep`, and `Qqemu.sstep=...`

## QEMU logging

Use QEMU `-d item1,...` for built-in debug logs. Always pair it with `-D logfile` for non-trivial runs. Use `-d help` on the target binary to discover supported log items.

For TCG issues, common log classes include instruction disassembly, translated ops, generated host code, execution, CPU state, and MMU activity. Scope noisy logs with `-dfilter` when a target address range is known.

Use `-accel tcg,one-insn-per-tb=on` when you need each translation block to contain one guest instruction. This is slow but useful for isolating the instruction that changes state.

## Trace events

Prefer trace events for structured evidence:

- Use `--trace "pattern"` for quick checks.
- Repeat `--trace` for multiple patterns.
- Use `--trace events=/path/to/events` for reproducible runs.
- Source trace definitions live in local `trace-events` files.
- Generated trace headers/sources live under the build directory, commonly `build/trace/`.

For device debugging, trace MMIO read/write, IRQ changes, reset, DMA descriptors, and completion paths. Avoid permanent noisy tracepoints in hot paths unless they are narrowly useful.

## Record/replay and determinism

If the bug is intermittent or depends on execution timing, consider QEMU record/replay:

- record with `-icount shift=auto,rr=record,rrfile=...`;
- replay with `-icount shift=auto,rr=replay,rrfile=...`;
- use replay for reverse debugging where supported.

Record exact QEMU binary, image hashes, machine options, and replay file path. Replay evidence is only meaningful if the same inputs are used.

## Device-model debug ladder

1. Confirm the exact MMIO/IRQ path with qtest or a minimized guest.
2. Add or enable tracepoints around register side effects.
3. Capture the guest access sequence.
4. Verify reset state and image provenance.
5. Check interrupt controller source number and level/edge assumptions.
6. Only then inspect broader boot logs.

## TCG debug ladder

1. Reproduce under `-accel tcg`; disable KVM/HVF when debugging translation.
2. Use `-accel tcg,one-insn-per-tb=on` to isolate instruction boundaries.
3. Use TCG logs to compare guest instruction, TCG ops, and generated host code.
4. Check `DisasContext`, feature flags, TB flags, and PC update behavior in the frontend.
5. Check backend optional-op feature flags, constraints, and `tcg_out_op` emission.
6. Add a focused TCG test for the guest instruction or backend op.

## Reporting checklist

A debug report should include:

- QEMU binary path and build directory;
- command line;
- image paths and hashes/build IDs;
- accelerator and machine type;
- exact failure marker;
- logs/traces/replay artifact paths;
- classification of the failure;
- next narrow check.

## Upstream references

- GDB usage: `docs/system/gdb.rst`.
- `-gdb`, `-s`, `-d`, `-D`, `-dfilter`: `qemu-options.hx`.
- Tracing: `docs/devel/tracing.rst`.
- Record/replay: `docs/system/replay.rst`.
- TCG internals: `docs/devel/tcg.rst` and `docs/devel/tcg-ops.rst`.
