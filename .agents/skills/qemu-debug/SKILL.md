---
name: qemu-debug
description: Use for debugging QEMU itself or guests under QEMU with host-side gdb/lldb, guest gdbstub, QEMU log flags, trace events, replay, one-insn-per-tb, and structured build/agent artifacts.
---

# QEMU Debug

Use this skill to reproduce, classify, and narrow QEMU failures: QEMU process crashes/assertions, guest boot hangs, wrong device behavior, TCG bugs, migration/runtime assertions, or intermittent behavior.

As a flow primitive, use this skill from boot workflows after `qemu-boot-run` has captured the exact command, failure marker, and log path.

## Flow dependencies

- Use `qemu-flow-plan` for non-trivial debugging.
- Store reproducer commands, logs, traces, replay files, host/guest gdb notes, and scratch scripts under `build/agent/<task-slug>/`.
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

## Host-side debugging of the QEMU process

Use host-side GDB or LLDB when debugging QEMU itself: crashes, assertions, hangs in device code, main-loop issues, migration bugs, TCG backend emission, or qtest-spawned QEMU failures. This is separate from the guest gdbstub: host GDB controls the emulator process; guest gdbstub controls guest CPU state.

Before attaching:

- ensure the relevant binary is built with debug info; use `qemu-build` if needed;
- record the exact QEMU command in `build/agent/<task-slug>/commands.md`;
- put debugger transcripts and notes under `build/agent/<task-slug>/logs/` or `build/agent/<task-slug>/debugger.md`;
- keep guest logs/traces separate from host debugger notes.

Common launch patterns:

```bash
gdb --args build/qemu-system-riscv64 <qemu-options>
gdb -ex 'run' --args build/qemu-system-riscv64 <qemu-options>
lldb -- build/qemu-system-riscv64 <qemu-options>
```

Common attach patterns:

```bash
gdb -p <qemu-pid>
lldb -p <qemu-pid>
```

For qtest-spawned QEMU, use verbose qtest output to recover the exact command/environment. `QTEST_STOP=1` can stop the spawned QEMU early so a host debugger can attach before the test continues.

Useful host-debugger checks:

- backtrace of all threads;
- current thread and frame around QEMU assertions;
- breakpoints in device MMIO callbacks, reset hooks, realize paths, TCG translation, or qemu_ld/st helpers;
- watchpoints on device state when corruption is suspected;
- `handle SIGPIPE nostop noprint` and similar signal policy only after confirming it matches the failure;
- thread names and event-loop state for hangs.

If guest execution must be paused while host debugging, combine host GDB with QEMU `-S` or an early qtest stop. Do not confuse a guest breakpoint with a host breakpoint.

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

### QEMU process

1. Reproduce with the same QEMU binary and command line.
2. Build with debug info if symbols are missing.
3. Launch under host GDB/LLDB for startup failures, or attach to the running PID for hangs.
4. Capture all-thread backtrace and the crashing/asserting frame.
5. Set source breakpoints at the suspected QEMU path and rerun.
6. Add traces or qtest reproduction only after the host-side failure location is known.

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
- whether debugger target is host QEMU process or guest CPU state;
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
