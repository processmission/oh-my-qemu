---
name: qemu-rlcr-loop
description: Use for non-trivial local QEMU implementation or debugging after qemu-flow-plan. Runs coherent rounds of work, verification, summary, independent review, scoped local Git checkpoint commits, and fixes until acceptance criteria pass.
---

# QEMU RLCR Loop

Use this foundational flow after `qemu-flow-plan` when the task needs iterative implementation, debugging, or substantial validation. It adapts Humanize's RLCR idea to QEMU while keeping every agent-created artifact under `build/`.

RLCR here means: **Ralph Loop with Codex/Reviewer Review**.

## Hard policy boundary

Do not produce source code intended for QEMU upstream submission. QEMU currently declines contributions believed to include or derive from AI-generated content. You may help with local-only experiments, research, debugging, and verification. Round commits created by this flow are local checkpoints only. Never push, publish, export, or describe them as upstream-ready. Do not add `Signed-off-by`, `Reviewed-by`, `Acked-by`, `Tested-by`, or similar contribution trailers.

## Required inputs

- A plan created by `qemu-flow-plan`.
- Its artifact root, usually `build/agent/<task-slug>/`.
- Frozen acceptance criteria.
- A chosen domain skill for the technical work.
- A designated task source tree and dedicated local task branch.
- A baseline revision, initial dirty-path inventory, allowed round-commit
  pathspecs, and expected QEMU subsystem prefix recorded by
  `qemu-source-provenance`.

If there is no plan, run `qemu-flow-plan` first.

## Artifact layout

Create or reuse:

```text
build/agent/<task-slug>/rlcr/
  goal-tracker.md
  round-001-summary.md
  round-001-review.md
  round-001-source-state.md
  round-002-summary.md
  round-002-review.md
  round-002-source-state.md
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
- Round commit:
- Completed:
- Remaining:
- Deferred with reason:
- Decision log:
```

The immutable section mirrors the plan. Do not alter it without explicit human approval.

## Round loop

Repeat until all acceptance criteria pass and review finds no blocking issue.

### 1. Select one round objective

Pick the smallest coherent slice that advances one or more ACs and can stand as
one logical, verified QEMU commit. Avoid mixing unrelated subsystems in one
round. If a slice needs multiple independently meaningful commits, split it
into multiple rounds before implementation.

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

## Git Checkpoint

- Parent:
- Commit:
- Tree:
- Subject:
- Staged paths:
- Residual dirty state:

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
- If review requires a fix, remain in the current round, then repeat
  verification, summary, and independent review.
- Do not commit a round with a failed verification gate, `BLOCKER`, or
  unresolved `MAJOR` finding.
- Repeat the current round until its objective has passing evidence and no
  blocking review finding, then commit it. If overall ACs remain, start the
  next round from that commit.

### 7. Commit the verified round

For every round that changes task source, create exactly one local Git commit
after verification and independent review pass, and before starting the next
round. Do not create empty commits for research-only or artifact-only rounds;
record `No source commit` in the round summary instead.

Before staging:

- compare the current working tree with the baseline dirty-path inventory;
- select only paths changed for the current round and allowed by the plan;
- stop if a task change overlaps a pre-existing dirty path or cannot be
  separated safely;
- never stage `build/agent/` artifacts or unrelated user changes.

Stage exact pathspecs with `git add -- <path>...`. Never use `git add -A`,
`git add .`, or another repository-wide staging command. Inspect
`git diff --cached --name-status`, `git diff --cached --stat`, and the complete
staged diff. Run `git diff --cached --check` and confirm that the staged set is
non-empty, task-related, and limited to the approved pathspecs.

Write the message to
`build/agent/<task-slug>/scratch/round-NNN-commit-message.txt`, then commit with
`git commit -F <message-file>`. Follow QEMU commit-message style:

```text
<subsystem>: <single-line summary without a trailing period>

<standalone body explaining why the change is necessary and what it does>

This is a local-only workflow checkpoint. It is not intended for
upstream submission.
```

- derive `<subsystem>` from the affected area and nearby `git shortlog`, not
  from the task slug or round number;
- keep the subject and every body line at most 76 characters;
- keep the body meaningful when read independently from the subject;
- do not use `[WIP]`, `round N`, or the task slug as the subject;
- do not add contribution, DCO, or review trailers.

Do not bypass hooks with `--no-verify`. Do not amend, rebase, reset, stash, or
push as part of the round checkpoint. If staging, hooks, author configuration,
or commit creation fails, record the failure as a blocker and do not start the
next round.

After commit, write `round-NNN-source-state.md` and update the round summary,
`goal-tracker.md`, and `source-provenance.md` with:

- parent, commit, and `HEAD^{tree}` IDs;
- exact subject and committed path list;
- verification and review evidence paths;
- post-commit `git status --short`, which must contain only declared baseline
  changes or newly identified blockers.

The successful commit is the round boundary and the next round's source
baseline. Never rewrite a previous round commit; fix later findings in a new
round.

## Finalization

Before finishing, write `final-summary.md`:

```markdown
# Final Summary

## Acceptance Criteria Status

## Source Changes

## Round Commits

## Verification Evidence

## Artifacts

## Known Non-goals

## Policy Check

- No agent-created artifacts outside build/agent/<task-slug>/.
- No DCO/review trailers added by the agent.
- Round commits remained local and were not pushed or published.
```

Do not report completion if any AC lacks evidence.

## Methodology feedback phase

After final verification, pause, block, max-iteration exit, or completion of a multi-workflow composition, run the methodology feedback phase once for the whole task. Do not ask the user after every primitive or workflow step.

Read `references/methodology-feedback.md` for the full procedure. In short:

- write sanitized workflow lessons to `build/agent/<task-slug>/methodology-feedback.md`;
- if there are no reusable improvements, do not ask the user to file an issue;
- if there are reusable improvements, ask once whether the user wants to open an upstream issue;
- show the sanitized issue draft before filing;
- default issue target is `processmission/oh-my-qemu`, overridable with `QEMU_METHODOLOGY_ISSUE_REPO`.

## When not to use RLCR

Skip this flow for trivial read-only questions, one-line documentation edits, or a single targeted command with no source changes. Still keep artifacts under `build/` if any are created.

## Upstream references

- QEMU code provenance and AI policy: `docs/devel/code-provenance.rst`.
- Humanize influence: implementation-summary-review loop, immutable goal tracker, acceptance criteria, final review, adapted without `.humanize/` artifacts.
- QEMU RFC agent skill layout: qemu-devel “AGENTS.md and associated skills” series.
