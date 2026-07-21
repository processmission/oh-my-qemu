---
# SPDX-FileCopyrightText: Copyright (c) 2026 Process Mission
# SPDX-License-Identifier: MIT
name: qemu-boot-run
description: Use when the QEMU binary and boot inputs are selected and one reproducible QEMU run must be constructed, logged, timed out, and classified by explicit success or failure markers.
---

# QEMU Boot Run

Use this skill whenever the task is to run QEMU and observe a boot milestone, whether the boot path is direct kernel boot, firmware boot, a guest OS shell, a test appliance, or a boot hang reproducer.

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

Own the QEMU command, run log, timeout behavior, marker matching, and immediate
result classification. If a required binary or image identity is missing,
record the gap instead of silently choosing a substitute.

## Command Record

Record:

- QEMU binary path and build directory;
- machine, CPU, accelerator, SMP, memory, and machine properties;
- kernel, firmware, DTB, initrd, disk, pflash, or block device inputs;
- serial, monitor, display, networking, and storage options;
- kernel command line or firmware environment assumptions;
- timeout, expected success marker, and known failure markers;
- console log path under `.oh-my-qemu/<task-slug>/logs/`.

## Run Rules

- Prefer a single copy-pasteable command.
- Use `-nographic` or explicit chardev routing for deterministic console capture.
- Keep QEMU monitor and guest serial behavior clear; do not hide which console carries Linux logs.
- Use `timeout` for smoke tests unless an interactive shell is the requested deliverable.
- Preserve exact output in a log file and summarize only decisive lines in
  `audit.md`.
- If a run hangs, capture the last meaningful marker before adding debug flags.

## Failure Handoff

When a run fails or times out, classify the first suspect before editing source:

- wrong or stale artifact;
- image layout mismatch;
- QEMU command mismatch;
- boot ABI or firmware handoff mismatch;
- missing device behavior;
- guest OS or rootfs issue.

Expose the classification, command, and log path so an outer workflow can
choose the next step.
