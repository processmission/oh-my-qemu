---
# SPDX-FileCopyrightText: Copyright (c) 2026 Process Mission
# SPDX-License-Identifier: MIT
name: qemu-model-verification
description: Use when existing qtest, trace, log, replay, boot, or workload evidence must be evaluated against one falsifiable QEMU device, board, TCG, or runtime claim as PASS, FAIL, or INCONCLUSIVE.
---

# QEMU Model Verification

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

## Evidence ladder

Given one falsifiable claim and existing evidence, report PASS, FAIL, or
INCONCLUSIVE without inventing evidence. Use the lowest rung that proves the
claim; a boot banner alone does not prove device correctness:

1. **Static inspection**: source/docs establish a fact.
2. **Build**: the touched target compiles.
3. **Unit/qtest**: register, IRQ, timer, memory, or board contract holds.
4. **Trace/log**: the expected runtime path executes and the bad path does not.
5. **Boot smoke**: firmware/kernel reaches a named milestone.
6. **Workload**: guest output proves the modeled hardware was consumed.
7. **Replay/reproduction**: the failure is deterministic or captured.

## Evidence provenance

Derive every expected marker, status value, count, or numeric bound from the
same evidence class as the artifact under test: register contract, model
source, or a checked-in test. Record the source and re-derive it when the test,
image, or model changes. A stale literal is a known false-negative source (an
old SHUTDOWN status, a DTB without required properties); do not edit an
expected literal to force a pass until its provenance is restored.

Record and compare hashes of the QEMU binary/build directory, images, DTB, and
machine options. Verify the device-tree properties the claim depends on (MSI:
`msi-parent` and an ITS node; timers/interrupts: controller and clock
properties) and decode the DTB when in doubt; a stale DTB is a known false
negative, not model evidence.

## Claim and acceptance criteria

Record one claim per gate in the
[claim record template](assets/claim-record-template.md): claim, gate, expected
values with provenance, inputs and hashes, evidence paths, verdict, proves and
does-not-prove, next blocker.

## INCONCLUSIVE sufficiency

A verdict is sufficient only when it names the evidence that would change it.
INCONCLUSIVE must state the gate, evidence collected, missing evidence, and
the next narrow command that could obtain it.

## Reviewer claims

Treat external review findings, human or agent, as hypotheses. Verify each
against the checked-out code and QOM semantics with `file:line`, classify it as
pre-existing or introduced by the change set, and reject unsupported debug
surfaces (for example a `-global` override unreachable from normal machine or
guest paths) as proof. Record the classification and evidence:
[claim review](references/claim-review.md).

## First divergence

For numeric mismatches, localize the first diverging slice: compare slice by
slice against a reference model or expected trace, capture trace/GDB state at
the first difference, and check whether banked or multiple address spaces hide
the difference.

## Failure classification

Classify before changing model code: environment/toolchain/build directory;
stale image; boot ABI; board topology; device register/IRQ/timer/DMA semantics;
TCG frontend/backend; guest/application. Usually only topology,
model-semantics, and TCG categories justify source changes.

## Register model structure check

Reconstruct the register-framework decision from current evidence (workspace
policy, compatible explicit user direction, maintained nearby convention, with
`RegisterInfo` as the fallback default) and verify the implementation matches
it. Register offsets, field macros, backing storage, framework tables, and
register-local callbacks must live in the device `.c` file, not a header or
board file. Report FAIL when current evidence does not justify the
implementation or a record contradicts it; do not fail only because no
historical record exists. Record the decision in `audit.md`; a successful
build, boot, or probe does not override this check.

## Device and board checklist

Use the qemu-peripheral-modeling and qemu-board-modeling checklists when
installed; otherwise verify directly: reset state, read/write masks and
reserved bits, W1C/status clear, IRQ raise/clear route, virtual-clock timer,
DMA guest-memory effect, machine creation, memory-map probes, reset after
dirty state.

## Trace validation

- count events and inspect semantic summaries; check skipped or unknown
  descriptor counts;
- verify command-memory and DMA ranges, and that the running image is the one
  intended;
- correlate trace milestones with UART or workload output.

## Reporting format

```text
PASS|FAIL|INCONCLUSIVE: <gate>
Command: <exact command>
Artifacts: <paths under .oh-my-qemu/<task-slug>/>
Evidence: <decisive lines or summary>
Proves / does not prove: <claim> / <remaining gap>
```

## Upstream references

- QEMU code provenance and AI policy: `docs/devel/code-provenance.rst`.
- Testing overview: `docs/devel/testing/main.rst`.
- QTest docs: `docs/devel/testing/qtest.rst`.
- Tracing: `docs/devel/tracing.rst`.
- Replay: `docs/system/replay.rst`.

Paths can differ between QEMU versions; locate them in the checked-out tree.
