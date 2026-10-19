---
# SPDX-FileCopyrightText: Copyright (c) 2026 Process Mission
# SPDX-License-Identifier: MIT
name: qemu-workflow
description: Use for non-trivial multi-step QEMU research, debugging, local-only implementation, modeling, boot, build, and verification tasks that benefit from auditable planning, source and artifact provenance, small reviewed rounds, evidence-backed verification, and a clear handoff; skip it for trivial read-only questions or a single targeted command.
---

# QEMU Workflow

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

## Run the workflow

0. **Route.** Read [skill-routing.md](references/skill-routing.md) when the task spans
   several QEMU areas. For an end-to-end device/board modeling task, start with
   `qemu-modeler` when installed and let it load the domain skills;
   use this workflow for the cross-cutting rules. Use only the skills the task
   needs; if the user names a skill that is not installed, record the gap in
   `audit.md` instead of improvising its rules.
1. **Plan.** Read [planning.md](references/planning.md) in full. Capture the baseline,
   goal, scope, acceptance criteria, risks, and verification gates in `audit.md`. Do
   not silently change acceptance criteria.
2. **Record provenance.** When the result depends on source revisions, toolchains,
   firmware, kernels, images, DTBs, root filesystems, or generated outputs, read
   [provenance.md](references/provenance.md) in full. Classify the intent as
   upstream-intent, local-only, or downstream/fork before writing source.
3. **Work in small rounds.** For source changes, multi-hypothesis debugging, or
   substantial validation, read [iteration.md](references/iteration.md) in full.
   Advance one coherent objective at a time and update the audit record before
   starting another.
4. **Verify and review.** Run the narrowest gate that can disprove each claim after
   each round. Preserve decisive logs, separate observation from inference, and use
   an independent review path when available. Fix blocking findings before claiming
   an acceptance criterion passed.
5. **Hand off.** Classify the result as `PASS`, `FAIL`, or `INCONCLUSIVE`. Summarize
   acceptance-criterion status, evidence paths, effective commands, source changes,
   policy limits, and unresolved gaps. Do not claim completion when evidence is
   missing.

## Optional steps

Use these only when the task needs them; they are not part of the default flow.

- **Patch series.** When the user explicitly asks for commits or a patch series, read
  [patch-series.md](references/patch-series.md). Committing is a separate requested
  action and never turns local-only work into an upstream contribution.
- **Round record, multi-agent work, and handoff.** For long-running or multi-agent
  work, read [collaboration.md](references/collaboration.md) for the append-only round
  record, write scopes, and handoff format.
- **Evidence mining.** When prior agent sessions, remote audit dirs, or review
  comments can supply modeling requirements, read
  [evidence-mining.md](references/evidence-mining.md) for the corpus map, search
  strategy, review-comment extraction, and sanitization limits.

If the task becomes blocked, preserve the last reproducible state and state the
concrete input, authority, or external change required to continue.

## Hard gates

[gates.sh](scripts/gates.sh) is an optional, self-contained gate library and CLI; run e.g.
`bash <skill-dir>/scripts/gates.sh all .oh-my-qemu/<task-slug>` from the skill directory.

Run `workspace` and `audit-sections` after planning, `round-result` and `marker` after a
round, and `handoff`, `git-status`, and `evidence-manifest` before handoff. Copy the
[audit](assets/audit-template.md), [round-result](assets/round-result-template.md),
[evidence-manifest](assets/evidence-manifest-template.md), and
[handoff](assets/handoff-template.md) templates when those records are due. Each gate
prints `GATE PASS|FAIL|SKIP` and returns 0/1/2 (2 is also INCONCLUSIVE for `marker`);
record a skipped gate as a gap.

## Upstream references

- docs/devel/code-provenance.rst
- docs/devel/submitting-a-patch.rst
- docs/devel/build-system.rst
- docs/devel/testing/main.rst
- docs/devel/testing/qtest.rst

Paths can differ between QEMU versions; locate them in the checked-out tree.
