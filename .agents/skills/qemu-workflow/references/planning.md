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

Use this compact `audit.md` shape and omit sections that are genuinely not
applicable:

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
