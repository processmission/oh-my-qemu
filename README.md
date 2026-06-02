# oh-my-qemu

QEMU-focused agent skills for planning, debugging, building, qtest validation, peripheral modeling, board modeling, and TCG frontend/backend work.

These skills follow QEMU's agent/provenance constraints: agent-created artifacts should stay under `build/agent/<task-slug>/` in a QEMU source tree, and agents must not add DCO or review trailers on behalf of humans.

## Prerequisites

- Node.js with `npx` available.
- Network access to GitHub.
- An agent environment supported by the Skills CLI.

## Inspect available skills

Before installing, list the skills published by this repository:

```bash
npx skills add https://github.com/zevorn/oh-my-qemu -l
```

Expected skills:

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

## Install globally for all agents

Use this when you want every supported agent on the machine to see the QEMU skills:

```bash
npx skills add https://github.com/zevorn/oh-my-qemu -g --all
```

## Install into the current project for all agents

Run from the project directory:

```bash
npx skills add https://github.com/zevorn/oh-my-qemu --all
```

## Install for one agent

Example for Claude Code:

```bash
npx skills add https://github.com/zevorn/oh-my-qemu \
  -g \
  --agent claude-code \
  --skill '*' \
  -y
```

Use another agent name if your environment uses a different Skills CLI agent identifier.

## Install selected skills only

Example: install the shared flow skills plus peripheral modeling and qtest support:

```bash
npx skills add https://github.com/zevorn/oh-my-qemu \
  -g \
  --agent '*' \
  --skill qemu-flow-plan qemu-register-extraction qemu-rlcr-loop qemu-peripheral-modeling qemu-qtest \
  -y
```

## Install as an Oh My Pi plugin

The skill package above is the portable install path for many agents. Oh My Pi can also load this repository as a plugin, which adds OMP-only runtime helpers:

- a `qemu_init_task` tool for agents;
- a `/qemu-init-task` slash command for users;
- a light artifact-policy hook that redirects `.plan/`, `.humanize/`, and root-level scratch artifacts to `build/agent/<task-slug>/`;
- the same skills exposed through the plugin `skills/` layout.

### Install from the OMP marketplace interface

In Oh My Pi interactive mode:

```text
/marketplace add zevorn/oh-my-qemu
/marketplace install oh-my-qemu@oh-my-qemu
```

CLI equivalent:

```bash
omp plugin marketplace add zevorn/oh-my-qemu
omp plugin install oh-my-qemu@oh-my-qemu
```

### Local development link

From a local clone:

```bash
omp plugin link /path/to/oh-my-qemu
```

The plugin manifest is `package.json`; the OMP extension entry point is `src/extension.js`.

### Use the OMP helper

Inside a QEMU source tree:

```text
/qemu-init-task k230-uart-model
```

or let an agent call the `qemu_init_task` tool. It creates:

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

## Verify installation

List globally installed skills:

```bash
npx skills list -g
```

Filter by agent:

```bash
npx skills list -g --agent claude-code
```

## Update

Update globally installed skills:

```bash
npx skills update -g
```

Update project-installed skills from inside the project:

```bash
npx skills update -p
```

## Recommended usage flow

For non-trivial QEMU work:

1. Start with `qemu-flow-plan`.
2. If modeling from external drivers, datasheets, firmware filesystems, or regfiles, run `qemu-register-extraction` to produce `register-extraction.md` with register facts and cross-register feature dependencies.
3. Use `qemu-rlcr-loop` for iterative work and review.
4. Use the narrow domain skill:
   - `qemu-peripheral-modeling`
   - `qemu-board-modeling`
   - `qemu-tcg-frontend-instruction`
   - `qemu-tcg-backend-adaptation`
5. Use operational gates:
   - `qemu-build`
   - `qemu-qtest`
   - `qemu-debug`
   - `qemu-model-verification`

All generated plans, logs, traces, scratch files, and reviews for QEMU source-tree work should go under:

```text
build/agent/<task-slug>/
```
