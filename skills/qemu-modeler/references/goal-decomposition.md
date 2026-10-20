# Goal, milestones, and acceptance criteria

The orchestrator optimizes for the **goal**, not for a round count. A round is a
progress unit; finishing Round 0, 1, or 2 is not completion unless every
acceptance criterion has evidence-backed PASS and every milestone is done.

Read this before writing the plan. Keep the goal contract in
`output/task-state.md` and the machine-readable lists in
`output/milestones.tsv` and `output/acceptance.tsv` (created by
`loop-state.sh`).

## The four levels

| Level | Question it answers | Must be |
| --- | --- | --- |
| Goal | What end state makes the user successful? | outcome, not an activity; measurable |
| Milestone | Which checkpoint unlocks the next stage? | 2-5 checkpoints; a gate, not a task list |
| Acceptance criterion (AC) | What observable fact proves a goal promise? | falsifiable, evidence-bound, testable |
| Round | What is the smallest coherent step now? | one objective; advances a named AC |

The chain is:

```text
goal
  -> milestone M1, M2, ...       (checkpoints, not completion)
      -> AC1, AC2, ...           (falsifiable outcomes with evidence)
          -> round objective     (smallest step that advances one AC)
              -> gate + evidence -> review -> decision
```

## Goal

A goal is the real end state the user asked for. Write it once in
`task-state.md` and keep it stable.

Good:

- "A Linux guest boots to a shell on the demo board and the timer interrupt
  fires periodically, with qtest and serial evidence."
- "The peripheral's CTRL/STATUS/IRQ behavior matches the contract for the
  documented modes, with trace evidence and error handling."

Bad:

- "Finish three rounds." (activity, not outcome)
- "Build QEMU." (means, not modeling result)
- "Make it work." (not falsifiable)

If the user gives only an activity, restate it as an observable outcome and ask
only when the ambiguity changes scope or risk.

## Milestones

Milestones are checkpoints that unlock the next stage. They prevent a long task
from becoming an unbounded blob, but a milestone is **not** a completion
condition by itself and not a round count.

Typical milestones for a device model:

1. **M1 Evidence complete** - contract and RS-IR reviewed, unknowns listed.
2. **M2 Model implemented** - RegisterInfo/manual-MMIO path, hooks, IRQ/timer,
   error/trace policy in source.
3. **M3 Verification complete** - qtest and boot/workload evidence satisfy the
   ACs.
4. **M4 Review and handoff** - independent review passed, gaps and next work
   recorded.

Use 2-5 milestones. Each milestone should have an exit condition (a gate or an
artifact), not just "do the work". Mark it `done` only with evidence: the
milestone status command requires the exit gate/artifact evidence and counts
only evidence-backed `done` rows.

## Acceptance criteria

An AC is the falsifiable bridge between a goal promise and evidence. It must
name an observable action/state and the evidence that proves it.

Good:

- "Writing CTRL.EN=1 in MODE=periodic schedules the timer; qtest observes the
  timer expiry and IRQ assert."
- "Guest write to a read-only field is ignored and emits LOG_GUEST_ERROR; the
  log line is captured."
- "Unimplemented window at 0x1000 is visible as a board placeholder and returns
  no fabricated ready state."

Bad:

- "Registers work." (not falsifiable)
- "Tests pass." (does not say which behavior)
- "Code looks correct." (not evidence)

Rules:

- Each AC must be mapped to at least one gate, test, trace, marker, or log.
- `pass` requires non-empty evidence; `pass` without evidence is rejected by
  `loop-state.sh ac status`.
- A round objective must name the AC it advances.
- An AC may stay `pending`, `fail`, or `inconclusive`; only `pass` counts
  toward goal completion.
- If an AC cannot be made falsifiable, split it until it can.

## Completion and continuation

`loop-state.sh check` returns PASS only when:

1. the goal is set;
2. at least one milestone and one AC exist;
3. every milestone is evidence-backed `done`;
4. every AC is `pass` with fresh non-empty evidence;
5. there are no unresolved `BLOCKER` findings;
6. the current review status is `PASS`;
7. the latest round verdict belongs to the current round and is `PASS`.
   Starting a new round resets `review status`, so an older PASS cannot complete
   the new round.

Until then it prints `CONTINUE` and returns nonzero. `loop-state.sh loop` is
the agent-facing form: call it after each round and keep going while it says
CONTINUE. Do not stop after a fixed number of rounds.

A BLOCKER is open until fixed and marked resolved:

```bash
loop-state.sh finding resolve .oh-my-qemu/<task> F-01
```

Only open blockers count against completion. In **round mode**, `loop` records a round baseline when the mode is
selected; it prints `ROUND COMPLETE` and returns 0 only after the newly
requested round has its own matching `Round: <n>` result with a valid verdict,
gate, and evidence, plus a recorded review verdict for that round. A historical
round-result from a resumed task does not complete the requested round.

## Round budget is not a stop condition

A round budget is a design checkpoint, not a completion signal. When it is
reached:

- summarize what is proven and what remains;
- replan the next 1-3 rounds against the pending ACs/milestones;
- continue the goal loop unless a real stop condition applies.

Real stop conditions: all ACs evidence-backed PASS and all milestones done; the
user's requested scope is complete; a concrete external input/authority is
missing; the user explicitly stops; or continuing would violate the provenance
boundary. A budget, a failing round, or a long log does not by itself complete
the goal.

## Loop commands

```bash
bash <skill-dir>/scripts/loop-state.sh init .oh-my-qemu/<task>
bash <skill-dir>/scripts/loop-state.sh goal .oh-my-qemu/<task> "<goal>" goal
bash <skill-dir>/scripts/loop-state.sh milestone add .oh-my-qemu/<task> M1 "<checkpoint>"
bash <skill-dir>/scripts/loop-state.sh ac add .oh-my-qemu/<task> AC1 "<observable outcome>"
bash <skill-dir>/scripts/loop-state.sh start-round .oh-my-qemu/<task> "<objective>"
bash <skill-dir>/scripts/loop-state.sh ac status .oh-my-qemu/<task> AC1 pass "<evidence>"
bash <skill-dir>/scripts/loop-state.sh milestone status .oh-my-qemu/<task> M1 done "<exit-gate-evidence>"
bash <skill-dir>/scripts/loop-state.sh loop .oh-my-qemu/<task>
```

Use goal mode by default. Use `round` mode only when the user explicitly asks
for exactly one round and wants a handoff after it.
