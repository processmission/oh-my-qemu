# Round loop

One round is one coherent objective, one verification gate, one independent
review, and one recorded decision. The loop repeats until a stop condition.

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
| AC met with evidence | advance to the next AC or hand off |
| Objective met but AC not yet | plan the next narrow objective; keep the same phase |
| Gate failed with a single blocker | keep the round, fix the blocker, rerun the gate |
| Gate failed because the evidence is insufficient | narrow the probe or add a qtest/trace; do not change model behavior yet |
| Two independent blockers or a new stage | replan: split rounds, update the plan and state |
| External input/authority missing | stop as blocked and state exactly what is needed |
| Budget/stop signal reached | hand off the current state; do not silently continue |

## Guardrails

- One objective per round; no unrelated cleanups.
- No self-approval: the review is independent from implementation.
- No hidden PASS: every verdict maps to a named gate and evidence path.
- No stale placeholder or logging sink counted as modeled behavior.
- No commits or pushes unless the user requests that separate action.
- Preserve the previous state; state and rounds are append-only.
