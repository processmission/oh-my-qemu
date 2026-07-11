---
title: "Getting started"
description: "Install Oh My QEMU skills, initialize a task workspace, and run the complete modeling workflow from a QEMU checkout."
order: 1
category: "Start"
---

Oh My QEMU is a plugin and skill collection for local QEMU research, modeling, boot, debug, qtest, and documentation workflows.

## Install paths

Use the path that matches your agent runtime:

- **Oh My Pi plugin**: install the `oh-my-qemu` plugin from the marketplace.
- **Claude Code plugin**: install the same plugin through the Claude Code marketplace.
- **Portable skills**: install `.agents/skills/` with the portable `npx skills` flow.
- **Codex development**: validate and register local skill symlinks from this checkout.

## Start a task

From a QEMU source tree:

```text
/qemu-init-task k230-uart-model
```

Then ask the agent to use the relevant QEMU workflow skill for the task. The
workflow writes artifacts under:

```text
.oh-my-qemu/<task-slug>/
```

This keeps source roots free of root-level scratch notes, copied command lines, decoder dumps, logs, probes, and temporary scripts.
