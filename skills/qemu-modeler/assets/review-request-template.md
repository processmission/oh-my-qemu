# Review request

## Task and round

- Task:
- Round:
- Provenance intent:
- Requested scope (diff paths):

## Goal, milestones, and acceptance criteria

- Review type: <round | final goal> (final goal uses review-checks.sh --final-goal)
- Overall goal:
- Goal mode: goal | round
- Milestones: <M1 status, M2 status, ...>
- AC status: <AC1 status + evidence, AC2 status + evidence, ...>
- Current round objective and the AC it advances:

Completion is goal-level: every AC evidence-backed PASS, every milestone done,
no unresolved BLOCKER. A round count is not completion.

## Evidence packet

- Framework decision: .oh-my-qemu/<task-slug>/output/framework-decision.md
- Contract: .oh-my-qemu/<task-slug>/output/register-contract.md
- RS-IR: .oh-my-qemu/<task-slug>/output/register-semantics.ir
- Translation worklist: <path or "not produced">
- Round result: .oh-my-qemu/<task-slug>/output/round-result.md
- Commands/logs/tests: <paths>
- Build/boot evidence: <paths and hashes>
- Review report (previous round, if any): <path>

## Failure classification (if any)

<first suspect and next narrow check>

## Questions for the reviewer

- Is the implementation consistent with the RS-IR rules and translation?
- Does every guest-visible rule have trace/log evidence?
- Are error paths and unimplemented placeholders handled and visible?
- Do the tests verify the real offsets/behavior, not a stand-in?
- Do source comments/header blocks cite only hardware/public references, with no
  task output/audit/evidence paths or host paths?
- Does every AC have evidence-backed PASS, and is every milestone actually done?
- Is a round count or a budget being mistaken for goal completion?
- What evidence is missing for the claimed goal/ACs, and what is the next round?

## Return format

Verdict: PASS | FAIL | INCONCLUSIVE
Findings: ID | severity (BLOCKER/MAJOR/MINOR/NOTE) | file:line or artifact | evidence | requested action
Checked: <what was inspected>
Not checked: <what remains unverified>
