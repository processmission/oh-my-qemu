---
# SPDX-FileCopyrightText: Copyright (c) 2026 Process Mission
# SPDX-License-Identifier: MIT
name: qemu-workflow
description: Optional, self-contained workflow for non-trivial multi-step QEMU research, debugging, local-only implementation, modeling, boot, build, and verification tasks. Use when the task benefits from auditable planning, source and artifact provenance, small reviewed rounds, evidence-backed verification, and a clear handoff; skip it for trivial read-only questions or a single targeted command.
---

# QEMU Workflow

## Audit workflow

For non-trivial workspace writes, use a stable
`.oh-my-qemu/<task-slug>/` directory and create only needed entries:

```text
.oh-my-qemu/<task-slug>/
├── audit.md        # Baseline, plan, decisions, evidence, verification, and gaps
├── commands.md     # Redacted commands, working directories, and results
├── logs/           # Decisive build, test, runtime, or diagnostic logs
├── scripts/        # Intermediate documents, scripts, traces, and harnesses
└── output/         # Generated deliverables, dependencies, and non-QEMU binaries
```

Keep intermediate documents, scripts, and harnesses in `scripts/`; decisive
logs in `logs/`; and generated deliverables, third-party dependencies, and
non-QEMU binaries in `output/`. Keep QEMU builds under source-root
`builds/build-<target>/`. Record effective paths in `audit.md`.

Before writing audit artifacts or configuring QEMU in a Git worktree, add
`.agents/`, `.oh-my-qemu/`, and `builds/` to the repository-local file from
`git rev-parse --git-path info/exclude`; preserve existing entries and avoid
duplicates. Never stage or commit those paths. Stage or commit source only when
the user explicitly requests it.

At handoff, reconcile `git status --short` with the baseline and verify the
excluded paths are absent. Report task and build directories, source changes,
pre-existing changes, and unresolved gaps.

## QEMU upstream boundary

QEMU's official GitLab and mailing lists are upstream project channels. A
patch becomes an upstream contribution when sent to the mailing-list recipients
selected through `MAINTAINERS`; do not prepare or send agent-generated patches
for that submission. Local branches, commits, patch files, pushes, and pull
requests are not by themselves QEMU upstream contributions. Perform those Git
actions only when requested and follow the workspace's Git policy.

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
