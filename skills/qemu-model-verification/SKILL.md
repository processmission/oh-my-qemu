---
# SPDX-FileCopyrightText: Copyright (c) 2026 Process Mission
# SPDX-License-Identifier: MIT
name: qemu-model-verification
description: Use when existing qtest, trace, log, replay, boot, or workload evidence must be evaluated against one falsifiable QEMU device, board, TCG, or runtime claim as PASS, FAIL, or INCONCLUSIVE.
---

# QEMU Model Verification

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

## QEMU upstream boundary

QEMU's official GitLab and mailing lists are upstream project channels. A
patch becomes an upstream contribution when sent to the mailing-list recipients
selected through `MAINTAINERS`; do not prepare or send agent-generated patches
for that submission. Local branches, commits, patch files, pushes, and pull
requests are not by themselves QEMU upstream contributions. Perform those Git
actions only when requested and follow the workspace's Git policy.

## Evidence ladder

Given a falsifiable claim and existing evidence, report `PASS`, `FAIL`, or
`INCONCLUSIVE` without inventing missing evidence. Use the lowest rung that
proves the claim:

1. **Static inspection**: source/docs establish a fact.
2. **Build**: touched target compiles.
3. **Unit/qtest**: register, IRQ, timer, memory, or board contract holds.
4. **Trace/log**: the expected runtime path executes and the bad path does not.
5. **Boot smoke**: firmware/kernel reaches a named milestone.
6. **Workload**: guest output proves the modeled hardware was consumed correctly.
7. **Replay/reproduction**: failure is deterministic or captured for later analysis.

Do not claim device correctness from a boot banner alone.

## Required artifact discipline

Record in `.oh-my-qemu/<task-slug>/audit.md`:

- exact command line;
- QEMU binary and build directory;
- image paths and hashes/build IDs;
- accelerator and machine type;
- positive marker expected;
- negative markers checked;
- log/trace/replay paths;
- what the evidence proves;
- what remains unproven.

## Failure classification

Classify before changing model code:

- environment/toolchain/build directory;
- stale or wrong image;
- boot ABI mismatch;
- board topology mismatch;
- device register/IRQ/timer/DMA semantics;
- TCG frontend/backend bug;
- guest/application bug unrelated to the model.

Only topology, model-semantics, and TCG categories usually justify source changes.

## Register model structure gate

For every guest-visible control/status register bank, statically verify:

- the framework decision records policy present in the target QEMU workspace,
  explicit user direction, nearby subsystem conventions, and its rationale;
- the decision applies those inputs in that order and stops at the first
  decisive one;
- the selected `RegisterInfo` or manual MMIO implementation matches that
  decision;
- register offsets, field macros, backing storage, framework tables, and
  register-local callbacks live in the device `.c` file;
- no header or board file owns register layout or semantics;
- a `RegisterInfo` implementation uses the checked-out tree's current API;
- a manual MMIO implementation is selected by target-workspace policy, or,
  when that policy does not decide, by compatible explicit user direction, or,
  when neither decides, by a clear nearby subsystem convention.

Report `FAIL` for a missing, contradicted, or unjustified decision and for a
source-layout violation. Do not fail merely because the justified choice is
manual MMIO. A successful build, boot, or qtest run does not override this
structure gate.

## Device/board verification checklist

- reset state;
- read/write masks and reserved bits;
- W1C/status clear;
- IRQ raise/lower and interrupt-controller route;
- virtual clock/timer behavior;
- DMA guest-memory effect;
- machine creation;
- key memory-map probes;
- reset after dirty state.

## Trace validation rules

For accelerators or reverse-engineered paths:

- count events and inspect semantic summaries;
- check skipped/unknown descriptor counts;
- verify command-memory and DMA ranges;
- correlate trace milestones with UART or workload output;
- verify the running image is the image you intended.

## Reporting format

Use:

```text
PASS|FAIL|INCONCLUSIVE: <gate>
Command: <exact command>
Artifacts: <paths under .oh-my-qemu/<task-slug>/>
Evidence: <decisive lines or summary>
Proves: <specific claim>
Does not prove: <remaining gap>
```

## Upstream references

- QEMU code provenance and AI policy: `docs/devel/code-provenance.rst`.
- Testing overview: `docs/devel/testing/main.rst`.
- qtest docs: `docs/devel/testing/qtest.rst`.
- Tracing: `docs/devel/tracing.rst`.
- Replay: `docs/system/replay.rst`.
