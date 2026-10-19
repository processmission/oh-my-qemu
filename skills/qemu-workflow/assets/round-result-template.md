# Round-result template

Copy the block below to `.oh-my-qemu/<task-slug>/output/round-result.md`, fill every
placeholder, and append only: read the prior file before a round and never rewrite earlier
entries. `PASS` needs a configured marker or test plus an evidence path; a timeout, a
quiet run, or an empty serial log is `INCONCLUSIVE`.

## Round <n> - <date>

- VERDICT: <PASS | FAIL | INCONCLUSIVE>
- Stage: <handoff stage, or "not applicable">
- Gate: <configured marker or test that decides the round, e.g. boot marker "<marker>">
- Evidence: <logs/<file> or output/<file>> (sha256: <hash>)
- Source of expected evidence: <checked-out doc, manual page/section, or test that defines
  the expected value>
- Changed paths: <paths, or none>
- Commands: <commands.md rows or exact commands>
- Next blocker: <"none" for PASS; a concrete blocker for FAIL or INCONCLUSIVE>
