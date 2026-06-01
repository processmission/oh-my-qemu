---
name: qemu-debug
description: Use for debugging QEMU or guests under QEMU with gdbstub, -d logs, trace events, replay, one-insn-per-tb, and structured artifacts under build/agent/<task>.
license: GPL-2.0-or-later
---

# QEMU Debug

Use this skill to reproduce, classify, and narrow QEMU failures: guest boot hangs, crashes, wrong device behavior, TCG bugs, migration/runtime assertions, or intermittent behavior.

## Flow dependencies

- Use `qemu-flow-plan` for non-trivial debugging.
- Store reproducer commands, logs, traces, replay files, gdb notes, and scratch scripts under `build/agent/<task-slug>/`.
- Use `qemu-rlcr-loop` if debugging leads to iterative source changes.
- Use `qemu-model-verification` to state what the evidence proves.

## Hard policy boundary

Do not produce source code intended for QEMU upstream submission. Do not add DCO or review trailers.

## Classify first

Identify the debug target:

- guest code;
- QEMU device model;
- board topology/boot ABI;
- QEMU core runtime;
- TCG frontend;
- TCG backend;
- stale image/build/environment.

Do not assume a model bug before command line and image provenance are known.

## Guest debugging with gdbstub

Use:

- `-s`: listen on TCP port 1234;
- `-S`: start paused;
- `-gdb dev`: choose another backend, such as `tcp::3117`, unix socket, chardev, or stdio.

For multi-cluster machines, use GDB `target extended-remote`, `add-inferior`, `inferior N`, `attach N`, and `set schedule-multiple on`.

Useful GDB checks:

- registers;
- disassembly at PC;
- virtual memory;
- gdbstub physical memory mode;
- QEMU single-step mask when IRQ/timer stepping matters.

## QEMU logs and traces

Use `-d item1,...` with `-D build/agent/<task-slug>/logs/qemu.log`. Use `-d help` on the target binary to discover log items.

Use `-dfilter` when a target PC range is known. Use `-accel tcg,one-insn-per-tb=on` to isolate guest-instruction boundaries.

Use trace events for structured evidence:

- `--trace "pattern"` for quick checks;
- `--trace events=build/agent/<task-slug>/trace-events.txt` for repeatable runs;
- local `trace-events` files for source-side event definitions.

## Replay and determinism

For intermittent bugs, use record/replay when applicable:

- record: `-icount shift=auto,rr=record,rrfile=build/agent/<task-slug>/replay.bin`;
- replay: `-icount shift=auto,rr=replay,rrfile=build/agent/<task-slug>/replay.bin`.

Record QEMU binary, image hashes, machine options, and replay file path.

## Debug ladders

### Device/board

1. Confirm image and command line.
2. qtest the MMIO/IRQ path if possible.
3. Enable targeted traces.
4. Check reset state and interrupt-controller route.
5. Only then interpret full boot logs.

### TCG

1. Reproduce under `-accel tcg`.
2. Use `one-insn-per-tb` for instruction boundary issues.
3. Compare guest instruction, TCG IR, and host code logs.
4. Check frontend feature gates and PC/TB state.
5. Check backend constraints, optional flags, and emitted code.

## Debug report

Write reports under `build/agent/<task-slug>/` and include:

- command;
- build directory and QEMU binary;
- image hashes;
- failure marker;
- decisive log/trace paths;
- classification;
- next narrow check.

## Upstream references

- QEMU code provenance and AI policy: `docs/devel/code-provenance.rst`.
- GDB usage: `docs/system/gdb.rst`.
- CLI debug options: `qemu-options.hx`.
- Tracing: `docs/devel/tracing.rst`.
- Replay: `docs/system/replay.rst`.
- TCG internals: `docs/devel/tcg.rst` and `docs/devel/tcg-ops.rst`.
