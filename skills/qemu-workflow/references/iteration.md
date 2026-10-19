# Small-round iteration

Use this reference for local-only source changes, multi-hypothesis debugging,
or substantial validation. Keep the frozen goal and acceptance criteria in
`audit.md`; only the active objective, evidence, and next step are mutable.

## Run one coherent round

1. Select the smallest objective that advances an acceptance criterion or
   eliminates a plausible failure class. Record it before changing source.
2. Inspect the relevant source, tests, generated interfaces, and local history.
   Change source only when it is an explicitly requested deliverable.
3. Make the smallest reversible change or diagnostic probe. Keep temporary
   documents, scripts, traces, and harnesses in `scripts/`; put third-party
   dependency outputs and non-QEMU build binaries in `output/`.
4. Run the narrowest verification gate that can test the objective. Record the
   exact command, result, evidence path, and any environment limitation.
5. Review the source delta and evidence. Use an independent reviewer or
   subagent when available; otherwise perform a separate review pass.
6. Update the round record with changes, acceptance criteria advanced,
   verification, findings, decisions, and gaps before selecting another round.

Do not start an unrelated new objective while the current gate is failing or its
blocking finding remains unresolved; use the replanning triggers below when the
failure invalidates the plan. A failed round is useful evidence: preserve its
reproducer and revise the hypothesis instead of hiding it.

## Run the hard gates

Before advancing a round and before handoff, run the optional gate library when `bash` is
available (see [gates.sh](../scripts/gates.sh)):

```bash
bash <skill-dir>/scripts/gates.sh workspace .oh-my-qemu/<task-slug>
bash <skill-dir>/scripts/gates.sh audit-sections .oh-my-qemu/<task-slug>/audit.md
bash <skill-dir>/scripts/gates.sh round-result .oh-my-qemu/<task-slug>/output/round-result.md
bash <skill-dir>/scripts/gates.sh evidence-manifest .oh-my-qemu/<task-slug> <files...>
```

A failing gate blocks the round until the evidence is fixed or the failure is recorded as a
gap. Use [round-result-template.md](../assets/round-result-template.md) when appending the
round result.

## Review findings

Classify actionable findings consistently:

- `BLOCKER`: correctness, safety, policy, missing acceptance criterion, or
  failed verification that prevents completion;
- `MAJOR`: maintainability or coverage risk that should be resolved before
  handoff unless the user accepts a documented deferral;
- `MINOR`: bounded cleanup that does not invalidate the current evidence;
- `NOTE`: observation or follow-up with no current corrective action.

Give the reviewer the plan, raw delta, relevant source paths, commands, and
evidence paths. Ask for concrete failure modes and missing verification, not a
restatement of the round summary. Record why any non-blocking finding is
deferred.

## Finish without implicit Git actions

Iteration does not require a branch, staging, a commit, history rewrite, patch
export, or publication. Do not stage or commit changes unless the user
explicitly requests that separate action. Preserve unrelated worktree changes
and never include audit artifacts in a source change by default.

Before handoff, rerun the final gates required by the plan, inspect the complete
task-owned delta, and reconcile `git status --short` with the baseline. Mark an
acceptance criterion complete only when its named evidence exists. Report
residual risks, skipped gates, environment limitations, and unresolved review
findings as gaps.

Run every QEMU build from the source-root `builds/build-<target>/` directory
selected by the plan. Do not use an in-tree or ad hoc QEMU build directory.

## Track stages and round milestones

For firmware or boot work, map each stage to a round milestone in `audit.md`:

1. reset or ROM entry and early memory setup;
2. early firmware services, such as console, clocks, and timers;
3. trusted-firmware handoff, for example BL31 or OpenSBI to BL33;
4. bootloader and boot media;
5. kernel entry;
6. Linux shell and userspace;
7. documentation, when the task includes a docs deliverable.

One handoff stage per round unless the round states a written justification. A round that
spans several stages hides which boundary failed and usually grows past reviewable size.

## Separate final acceptance from the round gate

Final acceptance criteria are frozen in `audit.md`. A round gate is the narrowest
falsifiable check for the current stage, such as a configured boot marker or a focused
qtest. A passing round gate does not complete the final acceptance criteria; record stage
status and final status separately. A timeout, a quiet run, or the absence of a crash is
`INCONCLUSIVE`, not `PASS`.

## Replan mid-round when evidence changes

Stop the current objective and replan when:

- several independent blockers appear and the current objective fixes only one;
- evidence shows a new stage or boundary that the plan did not anticipate;
- the active hypothesis is invalidated by the latest evidence.

Record the old hypothesis, the evidence that disproved it, the revised plan and gates, and
then select one new objective. Do not keep a failing objective alive to preserve the
original plan.

## Guard an oversized round

If a round cannot name one stage boundary and one falsifiable gate, it is too large. Split
the work and record the split. Do not merge unrelated fixes to finish the round; a smaller
round that fails is cheaper than a large round that hides the failure boundary.

## Append the round result

Write each round result to `.oh-my-qemu/<task-slug>/output/round-result.md`. Read the
prior round-result before starting a round, preserve earlier entries unchanged, and append
the new one:

```markdown
## Round <n> - <date>

- Status: `PASS` | `FAIL` | `INCONCLUSIVE`
- Stage: <handoff stage>
- Changed paths: <paths>
- Commands: <pointer to commands.md rows>
- Evidence: <logs/ and output/ paths>
- Next blocker: <none or concrete blocker>
```

`PASS` requires a configured marker or a falsifiable qtest. Report the next blocker for
`FAIL` and `INCONCLUSIVE` runs instead of starting an unplanned objective.

## Snapshot evidence without commits

When the user did not ask for commits, record an evidence snapshot under `output/`: a
digest of the task-owned delta, the verification commands, and their results. In a Git
worktree, `git diff | sha256sum` is one digest form; in a non-Git snapshot, hash the
touched files. This preserves the intent of a verified checkpoint without requiring
commits; a digest is not a commit and does not authorize one.

## Multi-agent safety

Do not revert, reformat, or clean up another agent's edits. Work only in the write scope
assigned to the task; if a required edit overlaps another owner's scope, report the
overlap instead of editing. Run one build per build directory at a time. See
[collaboration.md](collaboration.md) for the task board and handoff format.
