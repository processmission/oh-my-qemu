# Handoff template

Use this block in the final message and in the `audit.md` handoff section. The next
agent must be able to resume from files alone; run the workflow handoff and git-status
gates before sending it.

```text
Status: <PASS | FAIL | INCONCLUSIVE>
Goal and acceptance criteria: <AC ids and status>
Task dir: .oh-my-qemu/<task-slug>
Build dir: builds/build-<target> (or "not applicable")
Source changes: <changed and created paths, or "none">
Pre-existing changes: <pre-existing dirty paths, or "none">
Evidence paths: <logs/... and output/... with hashes>
Commands: <decisive commands, cwd, result> (full log in commands.md)
Policy limits: <upstream boundary, read-only scope, or other limits>
Unresolved gaps: <gaps, or "none">
Next blocker: <concrete blocker, or "none">
Do-not-touch: <paths owned by others or pre-existing dirty paths>
```

Append new handoff entries; never rewrite an earlier result. If an earlier result was
wrong, add a correction entry that cites the new evidence.
