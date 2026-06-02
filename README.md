# oh-my-qemu

QEMU-focused agent skills and an optional Oh My Pi plugin for hardware modeling work: register extraction, peripheral modeling, board modeling, qtest, debugging, build, and TCG frontend/backend workflows.

The flow design is based on [PolyArch/humanize](https://github.com/PolyArch/humanize): plan with explicit acceptance criteria, iterate in reviewed rounds, and keep evidence attached to the work. `oh-my-qemu` adapts that idea for QEMU by putting all agent-created artifacts under:

```text
build/agent/<task-slug>/
```

This avoids polluting a QEMU source tree with `.plan/`, `.humanize/`, scratch notes, logs, or temporary scripts.

## QEMU policy

These skills follow QEMU provenance constraints:

- agents do not generate code intended for QEMU upstream submission;
- agents do not add DCO/review trailers on behalf of humans;
- local research, debugging, verification, and workflow guidance are allowed.

## Practice demo

A practice/demo branch using these ideas for K230-related QEMU modeling work:

- https://github.com/zevorn/qemu/tree/chao-k230-dev

## Skills

```text
qemu-flow-plan
qemu-register-extraction
qemu-rlcr-loop
qemu-build
qemu-qtest
qemu-debug
qemu-model-verification
qemu-peripheral-modeling
qemu-board-modeling
qemu-tcg-frontend-instruction
qemu-tcg-backend-adaptation
```

## Install as portable skills

List available skills:

```bash
npx skills add https://github.com/zevorn/oh-my-qemu -l
```

Install globally for supported agents:

```bash
npx skills add https://github.com/zevorn/oh-my-qemu -g --all
```

Install into the current project:

```bash
npx skills add https://github.com/zevorn/oh-my-qemu --all
```

## Install as an Oh My Pi plugin

The plugin adds OMP-only helpers:

- `qemu_init_task` tool;
- `/qemu-init-task` slash command;
- artifact-policy hook that redirects root-level scratch artifacts to `build/agent/<task-slug>/`;
- the same skills exposed through the plugin `skills/` layout.

Install from this self-hosted marketplace repo:

```bash
omp plugin marketplace add zevorn/oh-my-qemu
omp plugin install oh-my-qemu@oh-my-qemu
```

Local development link:

```bash
omp plugin link /path/to/oh-my-qemu
```

## Use in a QEMU source tree

Initialize a task workspace:

```text
/qemu-init-task k230-uart-model
```

This creates:

```text
build/agent/k230-uart-model/
  plan.md
  evidence.md
  commands.md
  register-extraction.md
  source-inventory.md
  conflicts.md
  logs/
  reviews/
  scratch/
  rlcr/
```

Recommended flow:

1. `qemu-flow-plan` — define goal, scope, acceptance criteria, and evidence.
2. `qemu-register-extraction` — extract registers, bitfields, cross-register dependencies, IRQ/DMA/timer behavior from drivers, datasheets, firmware filesystems, or regfiles.
3. `qemu-peripheral-modeling` or `qemu-board-modeling` — model the hardware using the extracted contract.
4. `qemu-rlcr-loop` — iterate with verification and independent review.
5. `qemu-build`, `qemu-qtest`, `qemu-debug`, and `qemu-model-verification` — prove the result.

## Update

Portable skills:

```bash
npx skills update -g
```

OMP plugin:

```bash
omp plugin upgrade oh-my-qemu@oh-my-qemu
```
