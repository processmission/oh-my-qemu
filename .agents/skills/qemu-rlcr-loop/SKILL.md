---
name: qemu-rlcr-loop
description: Use for non-trivial QEMU implementation or debugging work after qemu-flow-plan. Provides a simplified RLCR loop for one round of work, verification, summary, independent review, and fixes until acceptance criteria pass.
type: flow
license: GPL-2.0-or-later
---

# QEMU RLCR Loop

Use this foundational flow after `qemu-flow-plan` when the task needs iterative implementation, debugging, or substantial validation. It adapts Humanize's RLCR idea to QEMU while keeping every agent-created artifact under `build/`.

RLCR here means: **Ralph Loop with Codex/Reviewer Review**.

## Hard policy boundary

Do not produce source code intended for QEMU upstream submission. QEMU currently declines contributions believed to include or derive from AI-generated content. You may help with local-only experiments, research, debugging, and verification. Do not add `Signed-off-by`, `Reviewed-by`, `Acked-by`, `Tested-by`, or similar contribution trailers.

## Required inputs

- A plan created by `qemu-flow-plan`.
- Its artifact root, usually `build/agent/<task-slug>/`.
- Frozen acceptance criteria.
- A chosen domain skill for the technical work.

If there is no plan, run `qemu-flow-plan` first.

## Artifact layout

Create or reuse:

```text
build/agent/<task-slug>/rlcr/
  goal-tracker.md
  round-001-summary.md
  round-001-review.md
  round-002-summary.md
  round-002-review.md
  final-summary.md
```

All logs referenced by summaries/reviews stay under `build/agent/<task-slug>/logs/` or `build/agent/<task-slug>/reviews/`.

## Goal tracker

Maintain `goal-tracker.md` with two sections:

```markdown
# Goal Tracker

## Immutable

- Goal:
- Acceptance Criteria:

## Mutable

- Active round:
- Completed:
- Remaining:
- Deferred with reason:
- Decision log:
```

The immutable section mirrors the plan. Do not alter it without explicit human approval.

## Round loop

Repeat until all acceptance criteria pass and review finds no blocking issue.

### 1. Select one round objective

Pick the smallest coherent slice that advances one or more ACs. Avoid mixing unrelated subsystems in one round.

### 2. Do the work

Use the domain skill for technical decisions. Keep scratch artifacts under the task artifact root. Make source changes only when they are the requested deliverable.

### 3. Verify the slice

Run the narrowest relevant gate:

- `qemu-build` for compile/configure gates;
- `qemu-qtest` for device/board behavior;
- `qemu-model-verification` for runtime, trace, and workload evidence;
- `qemu-debug` for failure reproduction and classification.

Record exact commands and log paths.

### 4. Write round summary

Write `build/agent/<task-slug>/rlcr/round-NNN-summary.md`:

```markdown
# Round N Summary

## Objective

## Changes

## Acceptance Criteria Advanced

## Verification Run

## Evidence Paths

## Known Gaps

## Questions for Reviewer
```

Do not claim an AC is complete unless the named evidence exists.

### 5. Independent review

Use an independent reviewer path:

- reviewer subagent if available;
- Codex review if available in the environment;
- a separate manual review pass only if no reviewer tool exists.

The reviewer gets: plan, goal tracker, round summary, relevant source paths, and evidence paths. The reviewer must classify findings as:

- `BLOCKER`: correctness, policy, missing AC, broken verification;
- `MAJOR`: maintainability or coverage risk that should be fixed before final;
- `MINOR`: cleanup that can be batched;
- `NOTE`: non-blocking observation.

Write the result to `round-NNN-review.md`.

### 6. Fix or continue

- Fix every `BLOCKER`.
- Fix `MAJOR` findings unless explicitly deferred in `goal-tracker.md` with a reason.
- Continue the loop until no blockers remain and all ACs are proven.

## Finalization

Before finishing, write `final-summary.md`:

```markdown
# Final Summary

## Acceptance Criteria Status

## Source Changes

## Verification Evidence

## Artifacts

## Known Non-goals

## Policy Check

- No agent-created artifacts outside build/agent/<task-slug>/.
- No DCO/review trailers added by the agent.
```

Do not report completion if any AC lacks evidence.

## When not to use RLCR

Skip this flow for trivial read-only questions, one-line documentation edits, or a single targeted command with no source changes. Still keep artifacts under `build/` if any are created.

## Upstream references

- QEMU code provenance and AI policy: `docs/devel/code-provenance.rst`.
- Humanize influence: implementation-summary-review loop, immutable goal tracker, acceptance criteria, final review, adapted without `.humanize/` artifacts.
- QEMU RFC agent skill layout: qemu-devel “AGENTS.md and associated skills” series.
