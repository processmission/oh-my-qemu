---
# SPDX-FileCopyrightText: Copyright (c) 2026 Process Mission
# SPDX-License-Identifier: MIT
name: qemu-boot-run
description: Use when the QEMU binary and boot inputs are selected and one reproducible QEMU run must be constructed, logged, timed out, and classified by explicit success or failure markers.
---

# QEMU Boot Run

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

## Command record

If a required binary or image identity is missing, record the gap instead of choosing a
substitute. Otherwise record: QEMU binary path and build directory; machine, CPU, accelerator,
SMP, memory, and machine properties; kernel, firmware, DTB, initrd, disk, pflash, or block device
inputs; serial, monitor, display, networking, and storage options; kernel command line or
firmware environment assumptions; timeout, expected success markers, and known failure markers;
and the console log path under task `logs/`. Copy `assets/run-record-template.md` and fill it
from the finalized log.

## Run rules

- Prefer a single copy-pasteable command.
- Use `-nographic` or explicit chardev routing for deterministic console capture, and state
  which chardev carries guest serial and which carries QEMU diagnostics.
- QEMU's own stderr, trace, and `-d` log output is not guest serial. Do not classify boot from a
  diagnostic line or from a machine-specific debug message.
- Bound smoke tests with the bundled runner's timeout; use the `timeout` utility only when
  process status alone is sufficient.
- Preserve exact output in a log file and summarize only decisive lines in `audit.md`.
- If a run hangs, capture the last meaningful marker before adding debug flags.

## Marker-aware runner

For a file-backed serial console, prefer `scripts/run-and-classify.py` over a shell loop that
watches the live file. Resolve the script relative to this skill's directory so it remains usable
when the skill is installed alone. The runner truncates the log, starts the command in a new
process group, watches markers, terminates the group after a marker or timeout, waits for
shutdown, and rescans the finalized log because a file-backed chardev may flush its terminal
marker only during QEMU shutdown.

Repeat `--success-marker` for milestones that must all be present. Repeat `--failure-marker` for
decisive failures; any failure marker overrides success. The full invocation contract, JSON
schema, and buffered-log rule are in `references/runner.md`.

## Classification

Classify from the finalized semantic status, then record both statuses:

| Runner result | Semantic status | Verdict |
| --- | --- | --- |
| exit 0 | passed | PASS for the named markers |
| exit 1 | failed | FAIL, cite the matched failure marker |
| exit 124 | inconclusive | INCONCLUSIVE: timeout, no terminal marker |
| other nonzero | inconclusive | INCONCLUSIVE: process exited without required markers |

A boot timeout, empty serial log, clean process exit, or absence of a crash is not PASS. A
firmware or kernel banner alone does not prove device or board behavior.

## Boot marker taxonomy

Choose markers from the expected chain, not from generic words: ROM or reset entry, first
firmware console line, SPL or early loader milestone, trusted firmware or monitor handoff
(TF-A/BL31, OpenSBI), bootloader prompt or autoboot line, boot medium access, kernel entry
(`Starting kernel`), Linux version and init lines, login or shell prompt, and any configured
workload marker. Add decisive failure markers such as panic, abort, or a firmware error line.
Record which markers are required versus optional.

## Image corpus boot gate

When a boot must be validated against a released image corpus:

- record the image tarball URL or path, SHA-256, and the boot paths it supports;
- run every supported boot path, for example direct kernel and firmware boot, unless the task
  scopes one path;
- include a login, reboot, and poweroff cycle when the asset supports an interactive workload;
- keep the functional-test asset hash in sync with the shipped image and record both hashes;
- a local HTTP server may serve the asset; record URL, port, and document root.

## Monitor and extra chardevs

Record the monitor backend and how to reach it (stdio, socket, or none), and whether firmware,
bootloader, and Linux share one chardev. When several consoles exist, capture each to its own log
and name it. Do not merge diagnostic output into the guest serial log.

## Failure handoff

Classify the first suspect before editing source: wrong or stale artifact; image layout mismatch;
QEMU command mismatch; boot ABI or firmware handoff mismatch; missing device behavior; guest OS or
rootfs issue. Record the classification, command, and log path in `audit.md` and report
PASS/FAIL/INCONCLUSIVE with the reached marker and the unresolved gaps.

## Upstream references

- `docs/system/invocation.rst`
- `docs/system/linuxboot.rst`
- `docs/devel/testing/main.rst`
- `docs/devel/code-provenance.rst`

Paths can differ between QEMU versions; locate them in the checked-out tree.
