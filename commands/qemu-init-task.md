---
description: Create a QEMU task workspace under build/agent/<task-slug>/ (plan, evidence, commands, register-extraction, source-inventory, conflicts, plus logs/reviews/scratch/rlcr dirs).
argument-hint: <task-name>
---

Initialize the QEMU task workspace for "$ARGUMENTS".

Run the init script from the project root:

```bash
node "${CLAUDE_PLUGIN_ROOT}/scripts/init-task.mjs" "$ARGUMENTS"
```

If no task name is given, the script uses the current directory name as the slug. After it runs, report the created workspace path and slug, then point the user to the `qemu-flow-plan` skill as the next step.

All task artifacts stay under `build/agent/<task-slug>/`. Do not create `.plan/`, `.humanize/`, or root-level scratch files — the artifact-policy hook will block them.
