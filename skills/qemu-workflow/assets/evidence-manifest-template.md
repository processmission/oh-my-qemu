# Evidence manifest template

Two optional records keep evidence reproducible. Write them under
`.oh-my-qemu/<task-slug>/output/` and link them from `audit.md`. They are generated only
when an outer loop or a handoff needs machine-readable evidence.

## Hash manifest (generated)

Run the workflow gate from the skill directory:

```bash
bash <skill-dir>/scripts/gates.sh evidence-manifest .oh-my-qemu/<task-slug> \
  <evidence-file> [<evidence-file> ...]
```

It writes `output/evidence-manifest.tsv` with a header and one row per file, sorted and
stable, and fails on a missing or empty input:

```text
sha256	path
<sha256>	<logs/file>
<sha256>	<output/file>
```

## Status record (optional JSON)

When a bridge or outer loop consumes per-artifact status, record:

```json
{
  "task": "<task-slug>",
  "complete": false,
  "artifacts": [
    {
      "path": "<logs/... or output/...>",
      "sha256": "<sha256>",
      "status": "<PASS | FAIL | INCONCLUSIVE>",
      "first_blocker": "<first failing gate, or null>"
    }
  ],
  "register_contract_path": "<output/register-contract.md, or null>"
}
```

`complete` is true only when every artifact has a PASS status and no first blocker.
`first_blocker` names the first failing gate in the projected order, never a summary of
all failures. Re-run the hash gate after regenerating any artifact; a changed hash
invalidates evidence produced with the earlier input.
