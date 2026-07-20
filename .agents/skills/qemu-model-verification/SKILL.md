---
name: qemu-model-verification
description: Use when existing qtest, trace, log, replay, boot, or workload evidence must be evaluated against one falsifiable QEMU device, board, TCG, or runtime claim as PASS, FAIL, or INCONCLUSIVE.
---

# QEMU Model Verification

Use this skill when a QEMU model, board, TCG change, or debug hypothesis must be proven rather than merely built.

Turn the result of a build, image package, boot run, trace, or debugger session
into a clear PASS, FAIL, or INCONCLUSIVE claim.

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

This skill owns evidence interpretation and reporting. Given a falsifiable
behavior claim plus paths to existing commands, hashes, traces, or logs, report
`PASS`, `FAIL`, or `INCONCLUSIVE` without inventing missing evidence.

## Hard policy boundary

Do not produce source code intended for QEMU upstream submission. Do not add DCO or review trailers.

## Evidence ladder

Use the lowest rung that proves the claim:

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
