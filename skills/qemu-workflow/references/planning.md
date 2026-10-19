# Planning

Use this reference to establish the task contract before substantial work.
Keep the plan proportional to risk and place it in
`.oh-my-qemu/<task-slug>/audit.md`.

## Establish the baseline

Record:

- the task source tree, current branch or detached state, and `HEAD` revision;
- initial `git status --short`, including pre-existing dirty paths;
- expected behavior, observed behavior, and the narrowest reproducer;
- user constraints, permitted source paths, read-only references, and non-goals;
- whether the task is read-only, diagnosis-only, or permits local-only changes;
- the QEMU build target and its source-root path,
  `builds/build-<target>/`, when QEMU must be built.

A dirty worktree is not automatically a blocker. Preserve unrelated changes.
If a requested edit overlaps an unresolved pre-existing change and cannot be
separated safely, stop and ask the user before writing that path.

## Define the goal and evidence

Write testable acceptance criteria. Give each criterion a verification method
or inspection target:

```markdown
## Acceptance criteria

- AC-1: <observable outcome>
  - Evidence: <command, log, test, or inspection>
```

Select the cheapest gate that can disprove each claim, then add broader gates
only when the risk requires them. Typical gates include a targeted build,
qtest, focused runtime marker, trace, unit test, static check, documentation
build, or source inspection.

Do not silently shrink or rewrite a criterion. Record a changed assumption or
impossible criterion in the decision log and obtain user direction when it
would materially change the requested outcome.

## Plan the work

Split the work into coherent steps with explicit dependencies. Prefer a small
number of reversible steps, each tied to one or more acceptance criteria. Before
editing QEMU model code, exclude wrong revisions, stale builds, toolchain or
configuration mismatches, malformed images, command-line errors, boot handoff
problems, and guest failures when they could explain the symptom.

Start from [audit-template.md](../assets/audit-template.md) and omit sections that are
genuinely not applicable; the compact shape is:

```markdown
# <Task title>

## Baseline

## Goal and non-goals

## Scope and constraints

## Acceptance criteria

## Plan and verification gates

## Provenance

## Decisions and assumptions

## Round record

## Evidence and verification

## Unresolved gaps

## Handoff
```

Record exact or safely redacted commands, their working directories, results,
and log paths in `commands.md`; keep large output out of `audit.md`. Put
third-party dependency outputs and non-QEMU build binaries in `output/`, never
in the QEMU source tree. Keep QEMU's own build artifacts in the recorded
`builds/build-<target>/` directory.

## Handle a non-Git source snapshot

Vendor tarballs, release archives, and exported trees have no Git metadata. Record
`provenance: non-Git snapshot` as the baseline form, with the archive path, the extraction
root, the snapshot date, and SHA-256 values for the touched sources and configuration. Do
not add a `.git` directory to a vendor tree and do not report the tree as clean. If the
archive came from an unverified download, hash it before the first edit so later claims
can still be tied to the input.

## Keep planning proportional

Scale the plan and its gates to the risk:

- a trivial read-only question needs no task directory and no acceptance criteria;
- diagnosis or research needs a baseline, a reproducer, and falsifiable gates;
- a local source change needs acceptance criteria, rounds, and a review;
- multi-stage boot, upstream-intent analysis, or a patch series needs the full template,
  provenance, and stage milestones.

Do not manufacture gates for read-only work, and do not skip a review gate when source
changes are the deliverable. Record the chosen depth in `audit.md` so a later agent does
not inflate or shrink it silently.

## Keep state compaction-safe

Long sessions are compacted, and the next agent may start with no conversation context.
Keep a compact live state in `audit.md` so work resumes from files alone:

```markdown
## Live state

- Baseline: <tree, revision or snapshot hash>
- Goal: <one sentence>
- Acceptance criteria: <AC ids and status>
- Plan: <remaining steps, one line each>
- Rounds done: <round ids and PASS/FAIL/INCONCLUSIVE>
- Current blocker: <none or concrete blocker>
- Next action: <one command or inspection>
- Files touched: <paths>
- Evidence paths: <logs/ and output/ paths>
```

Update it at the end of every round and before a handoff or context reset. Keep prior
rounds append-only; update current state without rewriting earlier evidence.

## Record the audit language

Write audit prose in the language the user requests. Keep headings, status tokens
(`PASS`/`FAIL`/`INCONCLUSIVE`), artifact paths, commands, and JSON keys in English so the
record stays greppable and machine-readable. Add a preferred-language note only when the
user asks for one. Do not translate quoted command output; summarize it and keep the raw
log under `logs/`.
