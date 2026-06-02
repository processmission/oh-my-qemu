---
name: qemu-flow-plan
description: Use as the first step for any non-trivial QEMU task. Produces a small implementation/debugging plan under build/agent/<task>/ with immutable acceptance criteria, scope boundaries, artifact policy, and verification gates.
type: flow
license: GPL-2.0-or-later
---

# QEMU Flow Plan

Use this foundational flow before any non-trivial QEMU modeling, TCG, qtest, debug, or build task. Domain skills extend this flow; they should not duplicate planning mechanics.

## Hard policy boundary

Do not produce source code intended for QEMU upstream submission. QEMU currently declines contributions believed to include or derive from AI-generated content. You may help with research, debugging, analysis, local-only experiments, and verification guidance. Do not add `Signed-off-by`, `Reviewed-by`, `Acked-by`, `Tested-by`, or similar contribution trailers.

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
- build/test commands allowed;
- expected verification gates.

### 5. Record evidence as it is discovered

Use `evidence.md` as a ledger:

- source files read;
- docs consulted;
- commands run;
- relevant logs/traces with paths;
- assumptions and whether they were validated.

Keep evidence short. Link to artifacts in `build/agent/<task-slug>/logs/` instead of pasting large logs into the plan.

### 6. Hand off to domain skill

After the plan is stable, choose the narrow domain skill:

- `qemu-register-extraction`
- `qemu-peripheral-modeling`
- `qemu-board-modeling`
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
- No DCO or review trailers are added by the agent.

## Scope

### In scope

### Out of scope

### Allowed source changes

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
