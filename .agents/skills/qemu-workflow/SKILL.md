---
# SPDX-FileCopyrightText: Copyright (c) 2026 Process Mission
# SPDX-License-Identifier: MIT
name: qemu-workflow
description: Optional, self-contained workflow for non-trivial multi-step QEMU research, debugging, local-only implementation, modeling, boot, build, and verification tasks. Use when the task benefits from auditable planning, source and artifact provenance, small reviewed rounds, evidence-backed verification, and a clear handoff; skip it for trivial read-only questions or a single targeted command.
---

# QEMU Workflow

Use this optional workflow to structure a multi-step QEMU task without depending
on any other skill. Apply installed domain skills when useful, but treat their
absence as no blocker.

## Audit workflow

For every non-trivial task that writes to the workspace, choose a stable task
slug and keep agent-only records under:

```text
.oh-my-qemu/<task-slug>/
├── audit.md        # Baseline, plan, decisions, evidence, verification, and gaps
├── commands.md     # Redacted commands, working directories, and results
├── logs/           # Decisive build, test, runtime, or diagnostic logs
├── scripts/        # Intermediate documents, scripts, traces, and harnesses
└── output/         # Generated deliverables, dependencies, and non-QEMU binaries
```

Put every agent-generated intermediate document, script, and harness under
`scripts/`; keep decisive logs under `logs/`. Put third-party dependency
generated deliverables, third-party dependencies, and non-QEMU build binaries
under `output/`. QEMU's own builds must use
`builds/build-<target>/` at the QEMU source root. Record every effective path in
`audit.md`.

In a Git worktree, add `.agents/`, `.oh-my-qemu/`, and `builds/` to the
repository-local exclude file returned by
`git rev-parse --git-path info/exclude` before writing audit artifacts or
building QEMU. Preserve existing entries and avoid duplicates. Never stage or
commit `.agents/`, `.oh-my-qemu/`, or `builds/`. Stage or commit task-owned
source paths only when the user explicitly requests that separate action.

Before handoff, run `git status --short`, verify that it contains no
`.agents/`, `.oh-my-qemu/`, or `builds/` paths, and reconcile it with the
recorded baseline. Report the task directory, QEMU build directory, task-owned
source changes, pre-existing or unrelated changes, and all unresolved gaps.

## Policy boundary

Do not generate source, documentation, commit messages, or patches intended for
QEMU upstream submission. For upstream-facing work, limit assistance to
research, debugging, analysis, and verification guidance. Clearly label any
generated source experiment as local-only and keep it out of upstream-ready
artifacts.

## Run the workflow

1. **Plan.** Read [planning.md](references/planning.md) in full. Capture the
   baseline, goal, scope, acceptance criteria, risks, and verification gates in
   `audit.md`. Do not silently change acceptance criteria.
2. **Record provenance.** When the result depends on source revisions,
   toolchains, firmware, kernels, images, DTBs, root filesystems, or generated
   outputs, read [provenance.md](references/provenance.md) in full and record
   only the inputs that affect the claims being made.
3. **Work in small rounds.** For source changes, multi-hypothesis debugging, or
   substantial validation, read [iteration.md](references/iteration.md) in full.
   Advance one coherent objective at a time and update the audit record before
   starting another.
4. **Verify and review.** Run the narrowest relevant gate after each round.
   Preserve decisive logs, distinguish observation from inference, and use an
   independent review path when available. Fix blocking findings before
   claiming an acceptance criterion passed.
5. **Hand off.** Classify the result as `PASS`, `FAIL`, or `INCONCLUSIVE`.
   Summarize acceptance-criterion status, evidence paths, effective commands,
   source changes, policy limits, and unresolved gaps. Do not claim completion
   when evidence is missing.

If the task becomes blocked, preserve the last reproducible state and explain
what input, authority, or external change is required to continue.
