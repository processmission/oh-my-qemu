---
description: Seed qemu-task.md and start the complete Oh My QEMU modeling workflow from the current QEMU tree.
argument-hint: <request text, optionally starting with slug:... workstream:...>
---

Start the Oh My QEMU workflow for this request:

$ARGUMENTS

Procedure:

1. Ensure the current working directory is the QEMU source tree the user wants to work in.
2. Create or replace `qemu-task.md` in the current working directory. Use this shape:

   ```markdown
   ---
   slug: <stable lowercase task slug inferred from the request>
   workstream: <one of register-extraction | peripheral-modeling | board-modeling | build | kernel-build | uboot-build | image-packaging | direct-linux-boot | firmware-linux-boot | debug | qtest | documentation | tcg-frontend | tcg-backend | general>
   ---

   <the user's full request text>
   ```

3. Start the complete modeling workflow by explicit artifact path, without requiring installation:

   ```bash
   omp workflow start "${CLAUDE_PLUGIN_ROOT}/workflows/qemu-modeling.omhflow" --cwd "$PWD" --json
   ```

4. Report the workflow status, run id, task root, and `workflow-handoff.md` path. The workflow owns planning, implementation, verification, review looping, scoped local round commits, and final evidence.

Rules:

- Preserve the user's request exactly enough for later planning; do not compress away hardware names, paths, logs, acceptance criteria, or constraints.
- If the request already names a workstream, use it. Otherwise infer the narrowest workstream from the request.
- All artifacts must stay under `build/agent/<task-slug>/`.
