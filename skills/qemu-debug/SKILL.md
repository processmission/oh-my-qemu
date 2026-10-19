---
# SPDX-FileCopyrightText: Copyright (c) 2026 Process Mission
# SPDX-License-Identifier: MIT
name: qemu-debug
description: Use when QEMU crashes, asserts, or hangs, when a guest stalls before a boot marker, or when device, board, TCG, or replay behavior is suspected; debug with host gdb/lldb, the gdbstub, logs, traces, and replay.
---

# QEMU Debug

## Audit workflow

For a non-trivial task that writes to the workspace, use only the needed entries under
`.oh-my-qemu/<task-slug>/`: `audit.md` (baseline, plan, decisions, evidence, verification, and
gaps), `commands.md` (redacted commands, working directories, and results), `logs/` (decisive
build, test, and runtime output), `scripts/` (probes, parsers, and harnesses), and `output/`
(generated deliverables, third-party dependencies, and non-QEMU binaries). Keep QEMU's own build
tree at source-root `builds/build-<target>/`, never an unqualified `build/`. In a Git worktree,
add `.agents/`, `.oh-my-qemu/`, and `builds/` to the file from
`git rev-parse --git-path info/exclude` before writing artifacts or configuring QEMU; preserve
existing entries and avoid duplicates. Never stage or commit these paths; stage source only when
the user explicitly requests that separate action. At handoff, reconcile `git status --short`
with the baseline and report the task directory, build directory, source changes, pre-existing
changes, and unresolved gaps.

## QEMU upstream boundary

QEMU's official GitLab and mailing lists are upstream channels. A patch becomes an upstream
contribution when it is sent to the maintainers selected through `MAINTAINERS`. Do not prepare or
send agent-generated code, documentation, commit messages, or patches for upstream submission; see
the checked-out tree's `docs/devel/code-provenance.rst`. Research, debugging, analysis, local
experiments, verification, and workflow guidance remain allowed. Local branches, commits, patch
files, pushes, and pull requests are not by themselves upstream contributions; perform those Git
actions only when requested.

## Classify the failure first

Map the symptom to a target before choosing a tool:

- QEMU crash, assert, or abort: host process.
- Hang with no progress: host event loop or guest execution.
- Guest stall before a boot marker: image, boot ABI, board, or device model.
- Wrong device or guest instruction behavior: device, board, or TCG.
- Intermittent failure: record/replay or timing. Confirm command line, image
  provenance, and host environment before assuming a model bug.

## Crash intake

For a QEMU process failure, capture in order: exact command line and working
directory in `commands.md`; QEMU binary, build directory, and build ID; the
abort/assert message with `file:line`; all-thread backtrace under gdb/lldb; core
dump path and signal; an ASAN/TSan build for memory corruption (`--enable-asan`,
`--enable-tsan`; confirm in the checked-out configure help); and a minimized
reproducer. Record whether the debugger target is host QEMU or guest CPU state.

## Environment preflight

Record absolute paths and versions for gdb/lldb, objdump/llvm-objdump, ninja,
meson, python3, and the QEMU binary. macOS notes:

- no `timeout`/`gtimeout`; use a bounded foreground command and record it;
- a long `TMPDIR` breaks qtest sockets; use a short temporary directory;
- an x86_64 cross objdump can fail with exec-format errors; use native
  `llvm-objdump`/`readelf` or a container, which also covers missing
  `llvm-nm`, `llvm-readelf`, `pdftotext`, and host libraries; record the fallback.

## Host debugging of the QEMU process

Host GDB/LLDB controls the emulator; the gdbstub controls guest CPU. Use it for
crashes, assertions, hangs, migration, TCG backend, and qtest-spawned failures.

```bash
gdb --args builds/build-<target>/qemu-system-<arch> <qemu-options>
gdb -p <qemu-pid>
```

Check all-thread backtraces, the asserting frame, breakpoints in MMIO
callbacks/reset/realize/translation, watchpoints on device state, and event-loop
state for hangs. For qtest-spawned QEMU, recover the command from verbose test
output and set `QTEST_STOP=1` to attach early.

## Guest debugging with the gdbstub

- `-s` listens on TCP port 1234; `-S` starts paused; `-gdb dev` selects
  another backend such as `tcp::3117`, a unix socket, or stdio.
- Multi-cluster machines: `target extended-remote`, `add-inferior`,
  `inferior N`, `attach N`, `set schedule-multiple on`.
- Check registers, disassembly at PC, virtual memory, gdbstub physical-memory
  mode, and the single-step mask when IRQ/timer stepping matters.

## Logs, traces, and serial

Use `-d item,...` with `-D .oh-my-qemu/<task-slug>/logs/qemu.log`; list items
with `-d help`. Common items: `unimp`, `guest_errors`, `int`, `cpu`,
`in_asm`, `exec`, `mmu`. Use `-dfilter` for a known PC area and
`-accel tcg,one-insn-per-tb=on` to isolate instruction boundaries.

Trace syntax is `--trace [[enable=]pattern][,events=<file>][,file=<file>]`:
`events=` names a file listing events to enable, `file=` is the trace output;
the monitor `trace-event` command changes events at runtime.

Serial output and QEMU diagnostics are different channels: `-serial` carries
guest serial, while `-d`, trace, and `error_report` output goes to stderr or
`-D`. Never read a boot marker from a QEMU diagnostic line as guest serial.

## Measure unimplemented access

Before shrinking or discussing an unimplemented map, measure guest access:

```bash
builds/build-<target>/qemu-system-<arch> -M <machine> ... \
  -d unimp,guest_errors -D .oh-my-qemu/<task-slug>/logs/unimp.log
```

Group logged addresses by window, compare with the declared map and with
`info mtree`/`info qtree` in the monitor, and record counts. Logged access is
not modeled behavior; a diagnostic sink is not modeled success.

## Replay and reverse debugging

Record with `-icount shift=auto,rr=record,rrfile=...` and replay with
`rr=replay`. Use QEMU's replay path, not a host record/replay tool: with a
loaded replay and the gdbstub attached, GDB's `reverse-stepi` and
`reverse-continue` replay backwards from snapshots because QEMU cannot execute
in reverse, using the replay snapshots. The monitor `info replay` reports mode
and icount; verify the commands in this QEMU version (`docs/system/replay.rst`).

## Ladders

Crash, device/board, unimplemented-map, TCG frontend/backend, KVM, CPU/GIC, and
replay playbooks are in [debug playbooks](references/playbooks.md);
qemu-tcg-frontend and qemu-tcg-backend are optional context for TCG work.

## Report

Write the report in `.oh-my-qemu/<task-slug>/audit.md` from the
[crash report template](assets/crash-report-template.md); capture the first
pass with the skill's `scripts/collect-context.sh --output <file> --qemu <binary>`.
Keep the command, build directory and binary, debugger target, image hashes,
failure marker, decisive log/trace paths, classification, next narrow check,
and cleanup of only the processes started for this task.

## Upstream references

- QEMU code provenance and AI policy: `docs/devel/code-provenance.rst`.
- GDB usage: `docs/system/gdb.rst`.
- Tracing: `docs/devel/tracing.rst`.
- Replay: `docs/system/replay.rst`.
- CLI debug options: `qemu-options.hx`.

Paths can differ between QEMU versions; locate them in the checked-out tree.
