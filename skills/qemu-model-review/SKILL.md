---
# SPDX-FileCopyrightText: Copyright (c) 2026 Process Mission
# SPDX-License-Identifier: MIT
name: qemu-model-review
description: Use to independently review one QEMU modeling round or patch: verify the plan and acceptance criteria, RS-IR and translation consistency, error/trace/log coverage, qtest/boot evidence, and audit gates, then report BLOCKER/MAJOR/MINOR/NOTE findings and a PASS/FAIL/INCONCLUSIVE verdict.
---

# QEMU Model Review

This is the independent review leg of the modeling loop. Read only: do not edit
source, tests, or artifacts. The orchestrator applies fixes and requests a
re-review of the changed scope.

Read [the review checklist](references/review-checklist.md) in full and write the
report with [the report template](assets/review-report-template.md). Run
[review-checks.sh](scripts/review-checks.sh) for the deterministic checks; the
script does not replace judgment.

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

## Review packet

Request and inspect:

- the plan, scope, acceptance criteria, and current round objective;
- the exact diff or changed-path list (not the whole repository);
- the register/board contract, RS-IR, translation worklist, and placeholders;
- the round result, commands, decisive logs, qtests, boot evidence, and hashes;
- the previous review report and unresolved findings.

If a required input is missing, report it as a review blocker and state what
evidence would unblock the review.

## Procedure

1. **Scope check.** Match the diff to the requested scope and round objective.
   Flag unrelated changes, audit artifacts in the source diff, or unreviewed
   workspace paths.
2. **Evidence check.** For every claimed fact or gate, verify a source and a
   reproducible command/log. Distinguish PASS, FAIL, and INCONCLUSIVE; a boot
   banner or logging sink is not behavior evidence.
3. **RS-IR consistency.** If an RS-IR is present, validate it with the extraction
   skill's validator when available. Check that every rule maps to a mechanism
   and hook, that guest-visible rules have trace/log evidence, and that
   unimplemented addresses have board-level placeholders.
4. **Model check.** Inspect the implementation against the translation:
   register layout/storage in the device `.c`, framework decision, IRQ/timer/
   DMA/FIFO side effects, error paths (`LOG_GUEST_ERROR`, `LOG_UNIMP`,
   `error_report`/assert), VMState coverage, and no diagnostic sink counted as
   modeled behavior.
5. **Test check.** Verify that qtests exercise the real offsets and behavior,
   regression registration is present, and boot/workload evidence is
   hash-pinned and stage-appropriate. A test that reads the wrong address is a
   blocker, not a pass.
6. **Gate/audit check.** Confirm the audit sections, state file, round result,
   evidence manifest, and Git-exclude/handoff rules. A missing gate is a
   blocker when the round claims PASS.
7. **Independence check.** Confirm the review was not performed by the same
   agent pass that wrote the code when an independent context was available; if
   not, say so in the report.

## Verdict and findings

Classify findings:

- **BLOCKER**: correctness, policy, acceptance criteria, failed gate, missing
  evidence, unjustified framework/placeholder, or untraceable claim. Blocks
  advancement.
- **MAJOR**: coverage/maintainability risk; fix or record a user-accepted deferral.
- **MINOR**: bounded cleanup that does not invalidate evidence.
- **NOTE**: observation or follow-up with no current action.

Verdict:

- `PASS`: every acceptance criterion has evidence and no BLOCKER/MAJOR findings.
  State the evidence per criterion.
- `FAIL`: a claim is contradicted or a required gate fails. Name the blocking
  finding and the minimum fix.
- `INCONCLUSIVE`: evidence is insufficient or the packet cannot be verified. Name
  the missing evidence and the next narrow command.

Do not pass a round on the absence of findings alone; list what was actually
checked and what could not be checked.

## Re-review

After fixes, review the changed scope and rerun any gate affected by the fix.
A fix that could alter behavior requires the full gate, not only the failing
assertion. Preserve the previous report; append the new verdict and findings.

## Non-goals

- Do not edit source, tests, or audit artifacts.
- Do not stage, commit, push, or send upstream anything.
- Do not restate the implementer's summary as review evidence.
- Do not approve a placeholder, logging sink, or timeout as modeled behavior.

## Upstream references

- QEMU code provenance: `docs/devel/code-provenance.rst`.
- Testing and qtest: `docs/devel/testing/main.rst`, `docs/devel/testing/qtest.rst`.
- Tracing: `docs/devel/tracing.rst`.
- GDB and replay: `docs/system/gdb.rst`, `docs/system/replay.rst`.

Paths can differ between QEMU versions; locate them in the checked-out tree.
