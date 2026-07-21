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

Do not start a new objective while the current gate is failing or its blocking
finding remains unresolved. A failed round is useful evidence: preserve its
reproducer and revise the hypothesis instead of hiding it.

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
