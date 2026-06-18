# oh-my-qemu - QEMU Modeling Skills

A collection of AI agent **skills** for QEMU hardware modeling, source builds,
image packaging, boot testing, qtest coverage, debugging, RST documentation, and
TCG workflows.

The skills give an agent structured, evidence-driven workflows for turning a
hardware target into a runnable QEMU model. They are designed to be used inside a
QEMU source tree and keep all agent-created artifacts under:

```text
build/agent/<task-slug>/
```

This keeps QEMU source trees free of `.plan/`, `.humanize/`, scratch notes, logs,
temporary scripts, and other agent working files.

---

## Example prompts

Once installed, start Codex from a QEMU checkout and give the agent a concrete
target and workload. For example:

```bash
git clone https://github.com/processmission/qemu.git
cd qemu
codex
```

**Model a board or peripheral until a workload runs**
> /goal Help me model the xxx hardware model in QEMU. Proactively collect
> relevant datasheets, technical blogs, and driver source code. Follow the
> oh-my-qemu workflow end to end, including source provenance, register
> extraction, peripheral or board modeling, qtest/model verification, build,
> boot/run evidence, and RST documentation where appropriate. Continue until
> the xxx workload can run under QEMU, such as a bare-metal program, firmware
> payload, RTOS image, or Linux boot.

**Extract a register contract before modeling**
> Use the oh-my-qemu workflow to research this UART/SPI/PCIe block. Compare the
> datasheet, Linux driver, U-Boot driver, device tree bindings, and firmware
> initialization sequence, then produce a register-extraction handoff for QEMU
> modeling.

**Debug a stuck firmware boot**
> The firmware boot hangs after early MMIO setup. Use QEMU logs, trace events,
> gdbstub, and instruction-window analysis to identify the blocking device or
> missing register behavior.

**Create QEMU board documentation**
> Write the QEMU RST documentation for this board model. Include supported
> devices, direct Linux boot, firmware boot, test commands, and known
> limitations, and update the relevant toctree.

Replace `xxx` with the SoC, board, peripheral, ISA feature, or test program you
want to model and run.

---

## Contents

| Directory | Purpose |
|-----------|---------|
| `.agents/skills/` | Agent skills, one `SKILL.md` per QEMU workflow |
| `scripts/` | Skill validation, Codex registration, portable install, task initialization, and methodology issue helpers |
| `commands/` | Slash command definitions such as `/qemu-init-task` |
| `workflows/` | OMP `.omhflow` artifacts for complete QEMU modeling loops and deterministic bootstrapping |
| `hooks/` | Artifact-policy hooks that keep agent scratch files under `build/agent/` |
| `src/` | Oh My Pi plugin runtime glue and shared hook logic |
| `.claude-plugin/` | Claude Code plugin and marketplace metadata |
| `skills` | Symlink to `.agents/skills/` for plugin-compatible discovery |

---

## Skills

### Flow primitives

Small building blocks used by larger QEMU workflows.

| Skill | Purpose |
|-------|---------|
| `qemu-flow-plan` | Define task scope, acceptance criteria, artifact root, and verification gates |
| `qemu-source-provenance` | Record source trees, revisions, configs, toolchains, outputs, and hashes |
| `qemu-image-layout` | Describe and verify boot media formats, partitions, offsets, writes, and hashes |
| `qemu-boot-run` | Build reproducible QEMU run commands, logs, timeout markers, and result classification |
| `qemu-model-verification` | Produce PASS/FAIL/INCONCLUSIVE evidence for model, board, device, and runtime behavior |

### Modeling and debugging workflows

Skills for turning hardware facts into a QEMU model and proving it behaves.

| Skill | Purpose |
|-------|---------|
| `qemu-register-extraction` | Extract register maps, bitfields, side effects, IRQ/DMA behavior, and driver sequences |
| `qemu-peripheral-modeling` | Model MMIO, qdev, SysBus, IRQ, timer, DMA, and register-bank devices |
| `qemu-board-modeling` | Model boards, SoCs, memory maps, boot paths, firmware handoff, FDT, and IRQ topology |
| `qemu-qtest` | Design, register, run, and debug qtest coverage |
| `qemu-debug` | Use gdbstub, host debugger, QEMU logs, trace events, replay, and instruction-window analysis |
| `qemu-rlcr-loop` | Iterate implementation/debugging rounds with verification, review, and final evidence |
| `qemu-rst-documentation` | Write QEMU RST docs, board pages, boot examples, Sphinx index updates, and docs validation |

### Build, image, and boot workflows

Skills for compiling artifacts and running realistic boot paths.

| Skill | Purpose |
|-------|---------|
| `qemu-build` | Configure, build, reuse, and diagnose QEMU build directories |
| `qemu-kernel-build` | Build Linux kernel artifacts for QEMU boot tests |
| `qemu-uboot-build` | Build U-Boot, SPL/TPL, FIT/ITB, and firmware-chain artifacts |
| `qemu-image-packaging` | Package kernels, firmware, DTBs, rootfs, modules, and boot media images |
| `qemu-direct-linux-boot` | Boot Linux directly with QEMU `-kernel`, DTB, initrd, console, and rootfs options |
| `qemu-firmware-linux-boot` | Boot Linux through firmware or bootloader stages and preserve handoff evidence |

### TCG workflows

Skills for guest instruction frontend work and host backend adaptation.

| Skill | Purpose |
|-------|---------|
| `qemu-tcg-frontend-instruction` | Add, review, or debug guest ISA decode and TCG translation |
| `qemu-tcg-backend-adaptation` | Adapt TCG host backend ops, constraints, register allocation, emission, atomics, and vectors |

---

## Installation

This repository follows the open [Agent Skills standard](https://agentskills.io).
Each skill directory contains a `SKILL.md` file that compatible agents can load
on demand. The same skill content is exposed through portable skills, Codex
local registration, Oh My Pi, and Claude Code plugin packaging.

| Agent/runtime | Project-level path | User-level path |
|---|---|---|
| OpenAI Codex | `.agents/skills/` | `${CODEX_HOME:-$HOME/.codex}/skills` |
| Portable `npx skills` canonical install | `.agents/skills/` | `~/.agents/skills/` |
| Claude Code plugin | plugin marketplace/cache | plugin marketplace/cache |
| Oh My Pi plugin | plugin marketplace/cache | plugin marketplace/cache |

### Portable skills

List available skills:

```bash
npx skills add https://github.com/processmission/oh-my-qemu -l
```

From a local checkout, install globally for agents that support global skill
paths:

```bash
git clone https://github.com/processmission/oh-my-qemu.git
cd oh-my-qemu
npm run portable:skills:install-global
```

The install script wraps `npx skills add` with an explicit list of global-capable
agents. It intentionally excludes PromptScript because PromptScript is
project-only in current `skills` CLI releases. The script also refreshes Codex
links under `${CODEX_HOME:-$HOME/.codex}/skills` from this checkout.

Verify the completed install:

```bash
npx skills list -g
```

Install into the current project instead:

```bash
npx skills add https://github.com/processmission/oh-my-qemu --all
```

### OpenAI Codex

For Codex development against this checkout, validate and register symlinks into
`${CODEX_HOME:-$HOME/.codex}/skills`:

```bash
cd /path/to/oh-my-qemu
npm run codex:skills:validate
npm run codex:skills:register:dry-run
npm run codex:skills:register
```

Use a copy instead of symlinks, or target another directory:

```bash
node scripts/register-codex-skills.mjs --copy --target /path/to/codex/skills
```

Start a new Codex session after registering so the new skill metadata is loaded.

### Oh My Pi plugin

The Oh My Pi plugin exposes the same skills plus OMP-specific helpers:

- `qemu_init_task` tool;
- `/qemu-init-task` slash command;
- artifact-policy hook that redirects root-level scratch artifacts to
  `build/agent/<task-slug>/`.

Install from the self-hosted marketplace:

```bash
omp plugin marketplace add processmission/oh-my-qemu
omp plugin install oh-my-qemu@processmission
```

Local development link:

```bash
omp plugin link /path/to/oh-my-qemu
```

### OMP workflows with Oh My Humanize

The `.omhflow` runner and workflow registry are provided by
[Oh My Humanize](https://github.com/PolyArch/oh-my-humanize). The bundled
`qemu-modeling` flow runs the full local QEMU modeling loop: workspace bootstrap,
planning, source provenance, implementation/debugging, targeted verification,
review, fix rounds, and final evidence.

#### Install into the active OMP registry

Use this when you want `qemu-modeling` available by name in every OMP
session that uses the same registry:

```bash
cd /path/to/oh-my-qemu
npm run omp:workflows:validate
npm run omp:workflows:install
```

Then start it from a QEMU source tree:

```bash
cd /path/to/qemu
omp workflow start qemu-modeling --json
```

Or from the OMP TUI:

```text
/workflow start qemu-modeling --json
```

#### Install with a local Oh My Humanize checkout

When developing against a local Oh My Humanize checkout, point the installer at
that checkout's `omp` binary:

```bash
cd /path/to/oh-my-qemu
OMP_BIN=/path/to/oh-my-humanize/packages/coding-agent/dist/omp npm run omp:workflows:install
```

#### Run once without installing

Use an explicit artifact path when you do not want to copy anything into the
workflow registry:

```bash
cd /path/to/qemu
omp workflow start /path/to/oh-my-qemu/workflows/qemu-modeling.omhflow --json
```

From the OMP TUI launched in the QEMU tree:

```text
/workflow start /path/to/oh-my-qemu/workflows/qemu-modeling.omhflow --json
```

If OMP was launched elsewhere, add `--cwd /path/to/qemu`.

#### Discover by name without copying

Point `OMHFLOW_DIR` at this checkout's workflow directory before starting OMP:

```bash
OMHFLOW_DIR=/path/to/oh-my-qemu/workflows omp
```

Then use the short name:

```text
/workflow start qemu-modeling --json
```

#### Supplying the QEMU task request

The workflow reads `qemu-task.md` from the QEMU tree:

```markdown
---
slug: k230-uart-model
workstream: peripheral-modeling
---

Model the K230 UART and prove it with qtest.
```

Equivalent environment variables are also supported:

```bash
QEMU_TASK=k230-uart-model \
QEMU_TASK_BRIEF="Model the K230 UART and prove it with qtest" \
QEMU_WORKSTREAM=peripheral-modeling \
omp workflow start qemu-modeling --cwd /path/to/qemu --json
```

If the Oh My QEMU plugin is linked or installed, the shortcut command can seed
`qemu-task.md` and start the explicit-path workflow:

```text
/qemu-workflow Model the K230 UART and prove it with qtest.
```

After a successful run, `build/agent/<task-slug>/workflow-handoff.md` contains
the selected skill chain, and `build/agent/<task-slug>/rlcr/final-summary.md`
contains the final review/evidence summary. The narrower `qemu-task-bootstrap`
flow remains available when you only need deterministic workspace setup and a
handoff file.

### Claude Code plugin

The Claude Code plugin exposes the same skills, `/qemu-init-task`, and the
artifact-policy `PreToolUse` hook.

Install from the self-hosted marketplace:

```bash
claude plugin marketplace add processmission/oh-my-qemu
claude plugin install oh-my-qemu@processmission
```

Install into the current project only with `--scope project`, or keep it local
with `--scope local`.

Local development against a checkout:

```bash
claude plugin marketplace add /path/to/oh-my-qemu
claude plugin install oh-my-qemu@processmission
```

Verify the plugin and its skills:

```bash
claude plugin list
claude plugin details oh-my-qemu@processmission
```

Installed plugin skills are namespaced as `oh-my-qemu:<skill>`, for example
`oh-my-qemu:qemu-flow-plan`.

---

## Recommended workflow in a QEMU tree

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
  source-provenance.md
  image-layout.md
  boot-run.md
  methodology-feedback.md
  register-extraction.md
  source-inventory.md
  conflicts.md
  logs/
  reviews/
  scratch/
  rlcr/
```

Alternatively, run the same workspace through the complete OMP modeling
workflow. In a QEMU tree, create `qemu-task.md`:

```markdown
---
slug: k230-uart-model
workstream: peripheral-modeling
---

Model the K230 UART and prove it with qtest.
```

Then start OMH/OMP from that QEMU tree and run:

```text
/workflow start /path/to/oh-my-qemu/workflows/qemu-modeling.omhflow --json
```

If the flow has been installed, or `OMHFLOW_DIR=/path/to/oh-my-qemu/workflows`
was set before launching OMH/OMP, the shorter named form also works:

```text
/workflow start qemu-modeling --json
```

For the fastest interactive path, use the bundled prompt command:

```text
/qemu-workflow Model the K230 UART and prove it with qtest.
```

This writes `qemu-task.md`, starts the workflow by explicit path, creates the
task root, records a provenance snapshot, plans the modeling work, runs
implementation/verification/review loops, and writes
`build/agent/k230-uart-model/rlcr/final-summary.md`.

Typical composition:

1. `qemu-flow-plan` - define goal, scope, acceptance criteria, and evidence.
2. `qemu-source-provenance`, `qemu-image-layout`, and `qemu-boot-run` - record
   sources, artifacts, media layout, and run commands.
3. `qemu-register-extraction`, `qemu-peripheral-modeling`, or
   `qemu-board-modeling` - build the model from verified hardware facts.
4. `qemu-build`, `qemu-qtest`, `qemu-debug`, and `qemu-model-verification` -
   prove the model with build, tests, traces, and boot evidence.
5. `qemu-rst-documentation` - document supported hardware, boot commands, tests,
   and known limitations.
6. `qemu-rlcr-loop` - iterate until the acceptance criteria pass.

Common workflows:

```text
kernel build -> direct linux boot -> verification
uboot build -> image packaging -> firmware linux boot -> debug if needed -> verification
register extraction -> peripheral modeling -> qtest -> model verification
board modeling -> qtest -> direct linux boot -> RST documentation
```

---

## Policy and provenance

These skills follow QEMU provenance constraints:

- agents do not generate code intended for QEMU upstream submission;
- agents do not add DCO/review trailers on behalf of humans;
- local research, debugging, verification, and workflow guidance are allowed.

The workflow design is based on
[PolyArch/humanize](https://github.com/PolyArch/humanize): plan with explicit
acceptance criteria, iterate in reviewed rounds, and keep evidence attached to
the work.

---

## Methodology feedback

At final completion, pause, blocked state, or max-iteration exit of an RLCR or
composed workflow, `qemu-rlcr-loop` can run a one-time methodology feedback
phase. It summarizes reusable workflow problems or improvements into:

```text
build/agent/<task-slug>/methodology-feedback.md
```

The report must be sanitized before it is shown or filed: no private paths,
branch names, commit hashes, proprietary logs, code snippets, project-specific
URLs, image paths, or board/customer/product identifiers unless explicitly
approved.

If reusable improvements exist, the agent asks once whether to create an
upstream issue. The default target is `processmission/oh-my-qemu`, overrideable
with `QEMU_METHODOLOGY_ISSUE_REPO=owner/repo`.

Draft an issue from a sanitized report:

```bash
npm run methodology:issue -- build/agent/<task-slug>
```

This writes:

```text
build/agent/<task-slug>/scratch/methodology-issue-title.txt
build/agent/<task-slug>/scratch/methodology-issue.md
```

---

## Practice demo

Practice/demo branch using these ideas for downstream QEMU modeling work:

- RK3588/RK3588S Rockchip machines and shared IP models:
  https://github.com/processmission/qemu/tree/devel

---

## Update

Portable skills:

```bash
npx skills update -g
```

Oh My Pi plugin:

```bash
omp plugin upgrade oh-my-qemu@processmission
```

Claude Code plugin:

```bash
claude plugin install oh-my-qemu@processmission
```

Re-add the marketplace to pick up new commits, or manage versions through the
interactive plugin menu.

---

## License

MIT. Copyright (c) 2026 Process Mission. See [LICENSE](LICENSE).
