---
description: Seed .oh-my-qemu/<task-slug>/task.md and start the complete Oh My QEMU modeling workflow from the current QEMU tree.
argument-hint: <request text, optionally starting with slug:... workstream:...>
---

Start the Oh My QEMU workflow for this request:

$ARGUMENTS

Procedure:

1. Ensure the current working directory is the QEMU source tree the user wants to work in.
2. Infer a stable lowercase task slug and the narrowest workstream from the request.
3. Ensure `.oh-my-qemu/` is listed in the local Git exclude file when the QEMU tree is a Git worktree:

   ```bash
   git_exclude="$(git rev-parse --git-path info/exclude 2>/dev/null || true)"
   if [ -n "$git_exclude" ]; then
     mkdir -p "$(dirname "$git_exclude")"
     grep -qxF ".oh-my-qemu/" "$git_exclude" 2>/dev/null || printf "%s\n" ".oh-my-qemu/" >> "$git_exclude"
   fi
   ```

4. Create or replace `.oh-my-qemu/<task-slug>/task.md`. Use this shape:

   ```markdown
   ---
   slug: <task-slug>
   workstream: <one of register-extraction | peripheral-modeling | board-modeling | build | kernel-build | uboot-build | image-packaging | direct-linux-boot | firmware-linux-boot | debug | qtest | documentation | tcg-frontend | tcg-backend | general>
   ---

   <the user's full request text>
   ```

5. Start the complete modeling workflow by explicit artifact path, without requiring installation:

   ```bash
   QEMU_TASK="<task-slug>" \
   QEMU_TASK_FILE=".oh-my-qemu/<task-slug>/task.md" \
   omp workflow start "${CLAUDE_PLUGIN_ROOT}/workflows/qemu-modeling.omhflow" --cwd "$PWD" --json
   ```

6. Report the workflow status, run id, task root, and `workflow-handoff.md` path. The workflow owns planning, implementation, verification, review looping, scoped local round commits, and final evidence.

Rules:

- Preserve the user's request exactly enough for later planning; do not compress away hardware names, paths, logs, acceptance criteria, or constraints.
- If the request already names a workstream, use it. Otherwise infer the narrowest workstream from the request.
- All artifacts must stay under `.oh-my-qemu/<task-slug>/`.
