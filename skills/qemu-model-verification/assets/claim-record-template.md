# Claim record: <claim-id>

One claim per record. Copy it into `.oh-my-qemu/<task-slug>/audit.md` or keep
one file per claim under `output/`. Fill every placeholder before reporting a
verdict and keep the record so later rounds can re-derive it.

## Claim and gate

- Claim: <one falsifiable sentence>
- Gate: <exact command or evidence-localization method>
- Acceptance criteria: <observable condition that makes the claim PASS>
- Disconfirming evidence: <what would make it FAIL>

## Expected values and provenance

| Expected value | Meaning | Source (file:line, manual page/section, test) | Revision/date |
|---|---|---|---|
| <marker or value> | <what it proves> | <source> | <revision> |

- Re-derived when the test, image, or model changed: <yes/no and how>
- Stale literals removed: <list or none>
- User-supplied premise verified against the manual: <yes/no, page/section>

## Inputs and hashes

| Input | Path | sha256 or build ID |
|---|---|---|
| QEMU binary | `builds/build-<target>/qemu-system-<arch>` | <sha256> |
| Build directory | `builds/build-<target>/` | <configure line> |
| Image / firmware | <path> | <sha256> |
| DTB, if any | <path> | <sha256> |
| Machine options | `-M <machine> ...` | n/a |

- Required device-tree properties verified: <msi-parent/ITS, controllers,
  clocks, none>
- Environment: <host, accelerator, tool versions that affect the verdict>

## Evidence

| Artifact | Path | Decisive lines or summary |
|---|---|---|
| Log | `.oh-my-qemu/<task-slug>/logs/<file>` | <lines> |
| Trace | <path> | <counts/summary> |
| Replay | <path> | <mode/icount> |

## Verdict

- Verdict: PASS | FAIL | INCONCLUSIVE
- Gate that produced the verdict: <gate id>
- Proves: <specific claim this evidence supports>
- Does not prove: <remaining gap>
- What evidence would change the verdict: <narrow next check>
- Next blocker (FAIL/INCONCLUSIVE only): <concrete blocker and owner>
