---
# SPDX-FileCopyrightText: Copyright (c) 2026 Process Mission
# SPDX-License-Identifier: MIT
name: qemu-debug
description: Use for debugging QEMU itself or guests under QEMU with host-side gdb/lldb, guest gdbstub, QEMU log flags, trace events, replay, one-insn-per-tb, and structured .oh-my-qemu artifacts.
---

# QEMU Debug

Use this skill to reproduce, classify, and narrow QEMU failures: QEMU process crashes/assertions, guest boot hangs, wrong device behavior, TCG bugs, migration/runtime assertions, or intermittent behavior.

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

## Scope

This skill owns failure reproduction and narrowing: host debugger, guest
gdbstub, QEMU logs, trace events, replay, and instruction-window data.

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

- ensure the relevant binary is built with debug info;
- record the exact QEMU command in `.oh-my-qemu/<task-slug>/commands.md`;
- put debugger transcripts and notes under `.oh-my-qemu/<task-slug>/logs/`;
- keep guest logs/traces separate from host debugger notes.

Common launch patterns:

```bash
gdb --args builds/build-riscv64/qemu-system-riscv64 <qemu-options>
gdb -ex 'run' --args builds/build-riscv64/qemu-system-riscv64 <qemu-options>
lldb -- builds/build-riscv64/qemu-system-riscv64 <qemu-options>
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

Use `-d item1,...` with `-D .oh-my-qemu/<task-slug>/logs/qemu.log`. Use `-d help` on the target binary to discover log items.

Use `-dfilter` when a target PC range is known. Use `-accel tcg,one-insn-per-tb=on` to isolate guest-instruction boundaries.

Use trace events for structured evidence:

- `--trace "pattern"` for quick checks;
- `--trace events=.oh-my-qemu/<task-slug>/scripts/trace-events.txt` for repeatable runs;
- local `trace-events` files for source-side event definitions.

## Replay and determinism

For intermittent bugs, use record/replay when applicable:

- record: `-icount shift=auto,rr=record,rrfile=.oh-my-qemu/<task-slug>/logs/replay.bin`;
- replay: `-icount shift=auto,rr=replay,rrfile=.oh-my-qemu/<task-slug>/logs/replay.bin`.

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

Write the report in `.oh-my-qemu/<task-slug>/audit.md` and include:

- command;
- build directory and QEMU binary;
- whether debugger target is host QEMU process or guest CPU state;
- image hashes;
- failure marker;
- decisive log/trace paths;
- classification;
- next narrow check.

Stop only QEMU processes, debugger servers, and terminal sessions started for
this task. Record cleanup and any target-state-changing operation.

## Upstream references

- QEMU code provenance and AI policy: `docs/devel/code-provenance.rst`.
- GDB usage: `docs/system/gdb.rst`.
- CLI debug options: `qemu-options.hx`.
- Tracing: `docs/devel/tracing.rst`.
- Replay: `docs/system/replay.rst`.
- TCG internals: `docs/devel/tcg.rst` and `docs/devel/tcg-ops.rst`.
