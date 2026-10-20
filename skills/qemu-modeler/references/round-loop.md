# Round loop

One round is one coherent objective, one verification gate, one independent
review, and one recorded decision. The loop repeats until the **goal** is
complete, not until a round count is reached.

Goal mode and round mode:

- **goal mode (default)**: after the decision, call `loop-state.sh loop`; if it
  prints CONTINUE, start the next round against the next pending AC/milestone.
  Do not pause for permission between rounds.
- **round mode**: only when the user explicitly asks for exactly one round and a
  handoff; state that limitation in the round result. After the requested round,
  `loop` prints ROUND COMPLETE and returns 0; hand off instead of starting
  another round.
- Resolve a fixed BLOCKER with `loop-state.sh finding resolve <task> <id>`;
  open blockers continue to block the goal check.

## Round anatomy

1. **Objective**: the smallest change/probe that advances an acceptance criterion
   or eliminates a failure class. Write it in `audit.md` before editing.
2. **Inputs**: the relevant contract/RS-IR rules, source paths, exact inputs and
   hashes, and the build directory.
3. **Change**: source edits, tests, or a diagnostic probe only; keep audit
   artifacts out of the source diff.
4. **Gate**: the narrowest command that can disprove the objective; capture the
   command, exit/process status, marker status, and decisive log.
5. **Review**: independent qemu-model-review on the packet; findings classified
   BLOCKER/MAJOR/MINOR/NOTE.
6. **Decision**: PASS advances; FAIL/INCONCLUSIVE stays in the round with a named
   next blocker; a multi-blocker round triggers a replan.
7. **Record**: append the round result and update `output/task-state.md`; keep
   previous results and commands.

## Round result

Write `output/round-result.md` (replace the current round, append history in
`output/rounds.tsv`):

```text
Round: <n>
Objective: <one sentence>
Verdict: PASS | FAIL | INCONCLUSIVE
Gate: <marker/test/command and expected value>
Evidence: logs/..., output/..., tests/...
Changed paths: <task-owned paths>
Commands: <exact effective commands>
Findings: <review IDs or none>
Next blocker: <concrete next action or none>
```

Rules:

- PASS requires a configured marker or a falsifiable qtest; a timeout, an empty
  serial log, or "no crash" is INCONCLUSIVE.
- A logging sink, placeholder access, or boot banner is not modeled behavior.
- Evidence paths must exist; hash inputs when the result depends on them.
- A failed gate stays in the round, but the round must not grow across
  independent stages or subsystems.

## Review request

Use [the review request template](../assets/review-request-template.md). Give
the reviewer:

- the plan and acceptance criteria;
- the exact diff scope (not the whole repository);
- the contract, RS-IR, and translation worklist;
- commands, logs, tests, and hashes;
- the round result and the current failure classification.

Ask for concrete failure modes and missing verification, not a restatement of
the round summary. If a subagent/independent context is available, use it;
otherwise run the review as a separate read-only pass and state that it was not
an independent agent.

## Findings handling

- **BLOCKER**: correctness, policy, missing acceptance criterion, failed gate,
  unjustified framework/placeholder, or untraceable evidence. Stop and fix.
- **MAJOR**: maintainability/coverage risk; fix or record a user-accepted
  deferral.
- **MINOR**: bounded cleanup that does not invalidate evidence.
- **NOTE**: observation/follow-up; no current action.

Record why a non-blocking finding is deferred. After fixes, re-review the
changed scope; if the fix could alter behavior, rerun the full gate, not only
the failing assertion.

## Next-round decision

| Situation | Next action |
| --- | --- |
| AC met with evidence | advance to the next AC; if all ACs/milestones are done, run `loop-state.sh loop` for the goal-level check |
| Objective met but goal not yet | plan the next narrow objective against a pending AC; keep the same phase |
| Gate failed with a single blocker | keep the round, fix the blocker, rerun the gate |
| Gate failed because the evidence is insufficient | narrow the probe or add a qtest/trace; do not change model behavior yet |
| Two independent blockers or a new stage | replan: split rounds, update the plan and state |
| External input/authority missing | stop as blocked and state exactly what is needed |
| Round budget/checkpoint reached | summarize proven/open work, replan the next 1-3 rounds, continue; do not call the goal complete |
| User explicitly stops | hand off the current state and mark it as user-stopped, not goal-complete |

## Guardrails

- One objective per round; no unrelated cleanups.
- One round is not the goal: do not stop after Round 0/1/2 or at a budget.
  Run `loop-state.sh loop` and keep going while it prints CONTINUE.
- No self-approval: the review is independent from implementation.
- No hidden PASS: every verdict maps to a named gate and evidence path.
- No AC marked `pass` without evidence; `loop-state.sh` rejects it.
- No stale placeholder or logging sink counted as modeled behavior.
- No commits or pushes unless the user requests that separate action.
- Preserve the previous state; state and rounds are append-only.
