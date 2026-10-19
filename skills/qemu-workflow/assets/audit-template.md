# <Task title>

- Task: `<task-slug>`
- Task dir: `.oh-my-qemu/<task-slug>`
- Build dir: `builds/build-<target>` (or `not applicable`)
- Provenance intent: `<local-only | downstream/fork | upstream-intent>`

## Baseline

<Source tree, branch or detached state, revision or non-Git snapshot hash, initial
`git status --short`, and pre-existing changes.>

## Goal and non-goals

<One observable goal and the explicit non-goals.>

## Scope and constraints

<Permitted source paths, read-only references, policy limits, and user constraints.>

## Acceptance criteria

- AC-1: <observable outcome>
  - Evidence: <command, log, test, or inspection>

## Plan and verification gates

- <step>: <gate that proves it>

## Provenance

<Source, toolchain, firmware, kernel, image, DTB, and generated inputs with revisions and
hashes; see references/provenance.md.>

## Decisions and assumptions

- <decision or assumption>: <reason and evidence>

## Round record

- Round <n>: `<PASS | FAIL | INCONCLUSIVE>` - <objective>; see `output/round-result.md`

## Evidence and verification

- Evidence: `<logs/... or output/...>` (sha256: `<hash>`, also in
  `output/evidence-manifest.tsv` when the manifest gate runs)

## Unresolved gaps

- <gap, or "None.">

## Handoff

- Status: `<PASS | FAIL | INCONCLUSIVE>`
- Source changes: <paths, or none>
- Pre-existing changes: <paths, or none>
- Evidence paths: <logs/... and output/...>
- Policy limits: <upstream boundary or other limits>
- Unresolved gaps: <see above>
