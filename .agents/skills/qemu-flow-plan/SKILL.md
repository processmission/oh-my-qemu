---
name: qemu-flow-plan
description: Use as the first step for any non-trivial QEMU task. Produces a small implementation or debugging plan under a build/agent task workspace with acceptance criteria, scope boundaries, artifact policy, and verification gates.
---

# QEMU Flow Plan

Use this foundational flow before any non-trivial QEMU modeling, TCG, qtest, debug, build, image packaging, or boot task. Domain and workflow skills extend this flow; they should not duplicate planning mechanics.

For reusable primitive composition rules, read `references/flow-primitives.md` when a task combines source builds, image packaging, boot runs, verification, or debug windows.

## Hard policy boundary

Do not produce source code intended for QEMU upstream submission. QEMU currently declines contributions believed to include or derive from AI-generated content. You may help with research, debugging, analysis, local-only experiments, and verification guidance. Round checkpoint commits are local workflow artifacts and must not carry `Signed-off-by`, `Reviewed-by`, `Acked-by`, `Tested-by`, or similar contribution trailers. A human-owned final-series phase may draft QEMU-style commit messages and suggested DCO trailers under `build/agent/<task-slug>/`, but the human performs any final history rewrite, signing, format-patch, or sending step.

## Artifact root rule

All agent-created artifacts MUST live under the QEMU build directory:

```text
build/agent/<task-slug>/
```

This includes plans, notes, logs, traces, decoded dumps, review ledgers, temporary scripts, generated reports, copied command lines, and scratch data.

Never create `.plan/`, `.humanize/`, `tmp/`, root-level notes, or helper files inside source directories. Source files should change only when they are the requested deliverable. If `build/` does not exist, create only the needed `build/agent/<task-slug>/` subtree.

## Minimal plan flow

### 1. Create task workspace

Choose a stable lowercase slug from the task, then create this logical layout:

```text
build/agent/<task-slug>/
  plan.md
  evidence.md
  commands.md
  source-provenance.md
  image-layout.md
  boot-run.md
  logs/
  reviews/
  scratch/
```

Keep command output, traces, and one-off scripts inside this tree.

### 2. State the goal

Write a concise goal in `plan.md`:

- what behavior must change or be understood;
- which QEMU subsystem is in scope;
- whether the work is research-only, local-only implementation, or upstream-adjacent analysis;
- the exact non-goals.

### 3. Freeze acceptance criteria

Use short AC items. Each criterion must be testable or inspectable.

Template:

```markdown
## Acceptance Criteria

- AC-1: <observable outcome>
  - Evidence: <test/log/inspection that proves it>
- AC-2: <observable outcome>
  - Evidence: <test/log/inspection that proves it>
```

Do not silently shrink ACs. If a criterion is wrong or impossible, record the reason in the plan and ask the human before changing it.

### 4. Record path boundaries

Include:

- files/subsystems allowed to change;
- files/subsystems that are read-only references;
- source-generated artifacts that must not be committed;
- the task source tree, dedicated local task branch, baseline revision, and
  initial dirty paths;
- exact source pathspecs allowed in round commits and the expected QEMU
  subsystem prefix;
- build/test commands allowed;
- expected verification gates.

If a task must modify a path that was already dirty at baseline, stop and ask
the human to resolve or explicitly include that pre-existing change before
implementation. Never infer that an existing modification belongs to the task.

### 5. Prepare local Git checkpoints and final-series contract

For implementation work, use a dedicated local task branch and record its name,
HEAD, and initial `git status --short` in `source-provenance.md` before changing
source. State that RLCR round commits are local workflow checkpoints: never push,
publish, format, or describe them as QEMU-upstream-ready output.

Derive the expected checkpoint subject prefix from the affected subsystem and
nearby QEMU history. Keep agent artifacts under `build/agent/<task-slug>/`;
they are evidence for the commits, not commit content.

If the task asks for upstream-adjacent finalization, record that the terminal
final-series phase is human-owned: the workflow may draft an atomic split and
commit messages under the artifact root, but it must not apply DCO trailers or
rewrite history on behalf of the human. Record the source for the Oh My QEMU
user/QEMU DCO sign-off identity, whether a distinct second signer is required,
and whether the qemu-devel proposed `AI-used-for:` disclosure trailer is
enabled for the final-series drafts.

### 6. Record evidence as it is discovered

Use `evidence.md` as a ledger:

- source files read;
- docs consulted;
- commands run;
- relevant logs/traces with paths;
- assumptions and whether they were validated.

Keep evidence short. Link to artifacts in `build/agent/<task-slug>/logs/` instead of pasting large logs into the plan.

### 7. Hand off to domain skill

After the plan is stable, choose the narrow domain skill:

- `qemu-register-extraction`
- `qemu-peripheral-modeling`
- `qemu-board-modeling`
- `qemu-rst-documentation`
- `qemu-tcg-frontend-instruction`
- `qemu-tcg-backend-adaptation`
- `qemu-qtest`
- `qemu-debug`
- `qemu-build`

For implementation work, run the `qemu-rlcr-loop` flow over this plan.

## Plan template

```markdown
# <Task Title>

## Goal

## Policy

- QEMU upstream provenance policy applies.
- Agent-created artifacts stay under build/agent/<task-slug>/.
- Round checkpoints are local workflow commits and carry no DCO/review trailers.
- Final-series drafts, if requested, are human-owned and not upstream-ready until a human rewrites and certifies them.
- `AI-used-for:` drafts, if requested, are scope disclosures based on an accepted policy or maintainer exception, not AI-agent DCO sign-offs.

## Scope

### In scope

### Out of scope

### Allowed source changes

### Local Git Checkpoint Contract

- Task source tree:
- Dedicated local branch:
- Baseline revision:
- Initial dirty paths:
- Round-commit pathspecs:
- QEMU subject prefix:
- Remote publication: forbidden
- Final-series preparation:
- Oh My QEMU / QEMU DCO sign-off source:
- Distinct second sign-off source, if required:
- AI-used-for proposal/exception source:
- Final history rewrite/publication: human-only

### Artifact root

`build/agent/<task-slug>/`

## Acceptance Criteria

- AC-1:
  - Evidence:

## Verification Gates

## Evidence Ledger

## Open Questions

## Decision Log
```

## Upstream references

- QEMU code provenance and AI policy: `docs/devel/code-provenance.rst`.
- QEMU RFC agent skill layout: qemu-devel “AGENTS.md and associated skills” series.
- Humanize influence: immutable goals, acceptance criteria, evidence ledgers, and review loops, adapted to keep all artifacts under `build/`.
