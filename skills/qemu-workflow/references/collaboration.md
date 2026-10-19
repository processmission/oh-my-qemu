# Collaboration and handoff

Use this reference for multi-agent work, research subagents, or a handoff that another
agent must resume. Keep the shared task record in `.oh-my-qemu/<task-slug>/audit.md`.

## Task board

- Give each unit of work a board entry with subject, owner, write scope (files or
  directories), dependencies, and done criteria.
- Claim a task before editing and do not edit outside its write scope. When two scopes
  overlap, report the overlap to the owner or Lead and wait for a split instead of racing.
- Mark a task complete only when its done criteria have evidence paths and no next
  blocker.
- Keep one owner per build directory. A second agent that needs the build waits, or
  creates a separately named `builds/build-<target>-<role>/` when the Lead agrees.

## Roles

- Read-only agents may inspect files, run existing builds and tests, and report findings;
  they do not edit source, audit records, or build configuration.
- Edit agents own a disjoint write scope and record every edited path in the shared state.
- Do not revert, reformat, or clean up another agent's edits, even when they look wrong.
  Report the finding with file and line and let the owner decide.
- Do not promise work you cannot start in the same turn. If blocked, state the concrete
  blocker: missing file, failed command, absent authority, or a dependency that did not
  finish.
- Honor the explicit stop signal from the Lead or user: stop selecting new work and hand
  off.

## Research subagents

- Timebox the research task and ask for a report-first message at the timebox even when
  the work is incomplete.
- Give the subagent the exact paths, the question, the deliverable shape, and the write
  scope, which is normally none.
- The subagent reports evidence paths; the Lead verifies the claims before merging them.

## Keep records append-only

Read the latest round-result and handoff before starting. Append new evidence and handoff
entries; never rewrite earlier results to match the current claim. If an earlier result
was wrong, add a correction entry that cites the new evidence.

## Handoff format

Start from [handoff-template.md](../assets/handoff-template.md), state the following in
the final message and in the `audit.md` handoff section, and run
`gates.sh handoff <audit.md>` when the gate library is available:

```text
Status: PASS | FAIL | INCONCLUSIVE
Goal and acceptance criteria: <ids and status>
Files: <changed and created paths; mark read-only work>
Commands: <decisive commands, working directory, result> (full log in commands.md)
Evidence paths: <logs/ and output/ artifacts, with hashes>
Next blocker: <none or concrete blocker>
Do-not-touch: <paths owned by others or pre-existing dirty paths>
```

The next agent must be able to resume from files alone after compaction or a restart.

## Optional agent-result.json

An outer loop can consume a machine-readable result under `output/`:

```json
{
  "status": "PASS | FAIL | INCONCLUSIVE",
  "returncode": 0,
  "first_blocker": "<first failing gate or null>",
  "evidence": [{"path": "logs/...", "sha256": "..."}],
  "register_contract_path": "output/register-contract.md"
}
```

Write it only when an outer loop consumes it; `audit.md` remains the authoritative prose
record.
