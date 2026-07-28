---
# SPDX-FileCopyrightText: Copyright (c) 2026 Process Mission
# SPDX-License-Identifier: MIT
name: qemu-boot-run
description: Use when the QEMU binary and boot inputs are selected and one reproducible QEMU run must be constructed, logged, timed out, and classified by explicit success or failure markers.
---

# QEMU Boot Run

## Audit workflow

For non-trivial workspace writes, use a stable
`.oh-my-qemu/<task-slug>/` directory and create only needed entries:

```text
.oh-my-qemu/<task-slug>/
├── audit.md      # Baseline, scope, decisions, evidence, verification, and gaps
├── commands.md   # Redacted commands, working directories, and results
├── logs/         # Decisive build, test, runtime, or diagnostic logs
├── scripts/      # Temporary scripts, probes, parsers, and harnesses
└── output/       # Generated deliverables, dependencies, and non-QEMU binaries
```

Before changing source or mutable artifacts, record the workspace root,
revision, `git status --short`, pre-existing changes, goal, scope, and
acceptance checks in `audit.md`. Log exact redacted commands and results in
`commands.md`; record revisions, configurations, tool versions, and hashes when
they affect reproducibility. Separate observations from inferences and edit
source only when requested.

Keep QEMU builds under source-root `builds/build-<target>/`; put third-party
dependencies and non-QEMU binaries in task `output/`. Before writing audit
artifacts or configuring QEMU in a Git worktree, add `.agents/`,
`.oh-my-qemu/`, and `builds/` to the repository-local file from
`git rev-parse --git-path info/exclude`; preserve existing entries and avoid
duplicates. Never stage or commit those directories. At handoff, verify them
absent from `git status --short`. Report the task directory and unresolved gaps.

## Command Record

If a required binary or image identity is missing, record the gap instead of
choosing a substitute. Otherwise record:

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
- Bound smoke tests with the bundled runner's timeout; use the `timeout`
  utility only when process status alone is sufficient.
- Preserve exact output in a log file and summarize only decisive lines in
  `audit.md`.
- If a run hangs, capture the last meaningful marker before adding debug flags.

## Marker-aware runner

For a file-backed serial console, prefer the bundled
`scripts/run-and-classify.py` over a shell loop that watches the live file.
Resolve the script relative to this skill's directory so it remains usable
when the skill is installed alone.

The runner truncates the selected log, launches the command in a new process
group, watches for markers, terminates the process group after a marker or
timeout, waits for backend shutdown, and then rescans the finalized log. This
last scan is mandatory because a file-backed chardev may flush its terminal
marker only during QEMU shutdown.

```shell
SKILL_DIR=/path/to/qemu-boot-run
TASK=.oh-my-qemu/firmware-smoke
LOG="$TASK/logs/uart1.log"

python3 "$SKILL_DIR/scripts/run-and-classify.py" \
    --timeout 120 \
    --log "$LOG" \
    --report "$TASK/logs/result.json" \
    --success-marker 'BOOT READY' \
    --failure-marker 'Kernel panic' \
    -- \
    qemu-system-aarch64 ... -serial "file:$LOG"
```

Repeat `--success-marker` for milestones that must all be present. Repeat
`--failure-marker` for decisive failures; any failure marker overrides success.
The JSON report records process status and semantic marker status separately.
Classify results from the finalized semantic status:

- semantic success returns 0 even when the process reached its timeout before
  the buffered marker became visible;
- a failure marker returns 1;
- a timeout with no terminal marker returns 124; and
- a clean process exit without the required success markers is inconclusive
  and returns nonzero.

Do not classify guest failure from the process exit or timeout status alone.
Record both statuses and cite the finalized log in `audit.md`.

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
