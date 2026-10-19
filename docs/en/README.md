# Oh My QEMU Architecture & Workflow Docs

> [中文](../zh/README.md) · **English**

This directory contains the architecture design, modeling workflow, RS-IR and
translation docs for Oh My QEMU. The installable skill definitions remain the
source of truth in `skills/<name>/SKILL.md`; these docs describe the
**cross-skill design and execution model** for human review, onboarding, and
future work.

## Index

| Document | Contents |
| --- | --- |
| [architecture.md](architecture.md) · [中文](../zh/architecture.md) | Architecture: layers, 19 skill responsibilities, data flow, audit workspace, gates, boundaries |
| [modeling-workflow.md](modeling-workflow.md) · [中文](../zh/modeling-workflow.md) | End-to-end workflow: P0-P8, round loop, independent review, stop conditions, commands |
| [rs-ir-and-translation.md](rs-ir-and-translation.md) · [中文](../zh/rs-ir-and-translation.md) | RS-IR design, vocabulary, observe/placeholder, RegisterInfo and Unimplemented Device translation |
| [assets/](assets/) | English workflow/architecture diagrams (PNG/SVG/Graphviz) |

## Design goals

1. **One top-level entry.** For "model X" or "continue the next round", load
   `qemu-modeler`; it chooses domain skills, phase order, review points, and
   stop conditions.
2. **Evidence before code.** Every behavior, reset value, register bit, and boot
   conclusion needs a source (code/manual/trace) and reproducible evidence.
3. **Auditable by default.** All intermediate artifacts live under
   `.oh-my-qemu/<task-slug>/`: audit, commands, logs, scripts, output. State and
   rounds are recoverable.
4. **Hard gates.** PASS needs a marker or a falsifiable qtest; a round does not
   advance before independent review. Scripts own deterministic checks; the
   agent owns judgment.
5. **Clear boundary.** RegisterInfo owns peripheral behavior; Unimplemented
   Device owns board-level placeholders. Local work never becomes an upstream
   submission.

## Quick start

```bash
# Full modeling task: start from the top-level entry
#   Tell the agent:
#   Use qemu-modeler to model <device/board> with acceptance criteria <...>

# Single-purpose tasks: load a domain skill directly, e.g.
#   qemu-register-extraction / qemu-peripheral-modeling / qemu-board-modeling

# Inspect an existing task state
bash skills/qemu-modeler/scripts/loop-state.sh show .oh-my-qemu/<task-slug>
bash skills/qemu-model-review/scripts/review-checks.sh --task-dir .oh-my-qemu/<task-slug>
```

## 19 skills by layer

| Layer | Skills |
| --- | --- |
| Orchestration & review | `qemu-modeler`, `qemu-model-review` |
| Cross-cutting rules | `qemu-workflow`, `qemu-agent-feedback` |
| Evidence & contract | `qemu-register-extraction`, `qemu-board-modeling` |
| Modeling | `qemu-peripheral-modeling`, `qemu-board-modeling`, `qemu-tcg-frontend`, `qemu-tcg-backend` |
| Build, image, boot | `qemu-build`, `qemu-kernel-build`, `qemu-uboot-build`, `qemu-image`, `qemu-boot-run`, `qemu-linux-boot` |
| Verification, debug, docs | `qemu-qtest`, `qemu-model-verification`, `qemu-debug`, `qemu-rst-documentation` |

## Maintaining the diagrams

- Sources are the Graphviz files in `assets/*.dot`:

```bash
cd docs/en/assets
dot -Tpng -Gdpi=150 modeling-flow.dot -o modeling-flow.png
dot -Tsvg modeling-flow.dot -o modeling-flow.svg
dot -Tpng -Gdpi=150 modeling-architecture.dot -o modeling-architecture.png
dot -Tsvg modeling-architecture.dot -o modeling-architecture.svg
```

- Update the matching `.md` file and diagram source when the architecture or
  workflow changes.
- Repository checks:

```bash
npm run codex:skills:validate
npm run test:skill-scripts
```

## Links

- Repository: [README.md](../../README.md)
- Rules: [AGENTS.md](../../AGENTS.md), [skills/](../../skills/)
- Site: [site/](../../site/)
