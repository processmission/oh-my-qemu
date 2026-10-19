# Review request

## Task and round

- Task:
- Round:
- Provenance intent:
- Requested scope (diff paths):

## Plan and acceptance criteria

<AC list and the current round objective>

## Evidence packet

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
- What evidence is missing for the claimed acceptance criteria?

## Return format

Verdict: PASS | FAIL | INCONCLUSIVE
Findings: ID | severity (BLOCKER/MAJOR/MINOR/NOTE) | file:line or artifact | evidence | requested action
Checked: <what was inspected>
Not checked: <what remains unverified>
