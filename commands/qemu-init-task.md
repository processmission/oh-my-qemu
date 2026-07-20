---
description: Create a minimal auditable QEMU task workspace and source-root builds/ directory.
argument-hint: <task-name>
---

Initialize the QEMU task workspace for "$ARGUMENTS".

Run the init script from the QEMU source root:

```bash
node "${CLAUDE_PLUGIN_ROOT}/scripts/init-task.mjs" "$ARGUMENTS"
```

If no task name is given, the script uses the current directory name as the
slug. It creates `audit.md`, `commands.md`, `logs/`, `scripts/`, `output/`, and
the QEMU source-root `builds/` directory. It also adds `.agents/`,
`.oh-my-qemu/`, and `builds/` to the repository-local Git exclude file. After it
runs, report the task path, build root, and slug; suggest `qemu-workflow` only
for a non-trivial multi-step task.

All task artifacts stay under `.oh-my-qemu/<task-slug>/`. Temporary scripts go
under `scripts/`; generated deliverables, third-party dependencies, and
non-QEMU binaries go under `output/`; QEMU builds go only under a named
`builds/build-<target>/`. Do not create `.plan/`, `.humanize/`, root-level
scratch files, or an unqualified `build/` directory—the artifact-policy hook
will block identifiable writes to them when it runs from the QEMU source root.
