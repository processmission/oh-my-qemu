# oh-my-qemu - QEMU Modeling Skills

A collection of AI agent **skills** for QEMU hardware modeling, source builds,
image packaging, boot testing, qtest coverage, debugging, RST documentation, and
TCG workflows.

The skills give an agent structured, evidence-driven workflows for turning a
hardware target into a runnable QEMU model. They are designed to be used inside a
QEMU source tree and keep all agent-created artifacts under:

```text
.oh-my-qemu/<task-slug>/
```

The runtime adds `.oh-my-qemu/` to the checkout's local `.git/info/exclude`
when the QEMU tree is a Git worktree. This keeps QEMU source trees free of
`.plan/`, `.humanize/`, root-level scratch notes, logs, temporary scripts, and
other agent working files.

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
| `hooks/` | Artifact-policy hooks that keep agent scratch files under `.oh-my-qemu/` |
| `src/` | Oh My Pi plugin runtime glue and shared hook logic |
| `.claude-plugin/` | Claude Code plugin and marketplace metadata |
| `skills` | Symlink to `.agents/skills/` for plugin-compatible discovery |

---

## Skills

### Flow primitives

Small building blocks used by larger QEMU workflows.

| Skill | Purpose |
|-------|---------|
| `qemu-plan` | Define task scope, acceptance criteria, artifact root, and verification gates |
| `qemu-source-provenance` | Record source trees, revisions, configs, toolchains, outputs, and hashes |
| `qemu-image-layout` | Describe and verify boot media formats, partitions, offsets, writes, and hashes |
| `qemu-boot-run` | Build reproducible QEMU run commands, logs, timeout markers, and result classification |
| `qemu-model-verification` | Produce PASS/FAIL/INCONCLUSIVE evidence for model, board, device, and runtime behavior |
| `qemu-agent-feedback` | Summarize sanitized agent workflow problems and file oh-my-qemu improvement issues with `gh` when approved |

### Modeling and debugging workflows

Skills for turning hardware facts into a QEMU model and proving it behaves.

| Skill | Purpose |
|-------|---------|
| `qemu-register-extraction` | Extract register maps, bitfields, side effects, IRQ/DMA behavior, and driver sequences |
| `qemu-workflow-peripheral-modeling` | Model MMIO, qdev, SysBus, IRQ, timer, DMA, and register-bank devices |
| `qemu-workflow-board-modeling` | Model boards, SoCs, memory maps, boot paths, firmware handoff, FDT, and IRQ topology |
| `qemu-qtest` | Design, register, run, and debug qtest coverage |
| `qemu-debug` | Use gdbstub, host debugger, QEMU logs, trace events, replay, and instruction-window analysis |
| `qemu-rlcr-loop` | Iterate implementation/debugging rounds with verification, review, local checkpoints, and final-series draft preparation |
| `qemu-rst-documentation` | Write QEMU RST docs, board pages, boot examples, Sphinx index updates, and docs validation |

### Build, image, and boot

Flow primitives compile/package artifacts; workflow skills run realistic boot
paths.

| Skill | Purpose |
|-------|---------|
| `qemu-build` | Configure, build, reuse, and diagnose QEMU build directories |
| `qemu-kernel-build` | Build Linux kernel artifacts for QEMU boot tests |
| `qemu-uboot-build` | Build U-Boot, SPL/TPL, FIT/ITB, and firmware-chain artifacts |
| `qemu-image-packaging` | Package kernels, firmware, DTBs, rootfs, modules, and boot media images |
| `qemu-workflow-direct-linux-boot` | Boot Linux directly with QEMU `-kernel`, DTB, initrd, console, and rootfs options |
| `qemu-workflow-firmware-linux-boot` | Boot Linux through firmware or bootloader stages and preserve handoff evidence |

### TCG workflows

Skills for guest instruction frontend work and host backend adaptation.

| Skill | Purpose |
|-------|---------|
| `qemu-workflow-tcg-frontend-instruction` | Add, review, or debug guest ISA decode and TCG translation |
| `qemu-workflow-tcg-backend-adaptation` | Adapt TCG host backend ops, constraints, register allocation, emission, atomics, and vectors |

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
  `.oh-my-qemu/<task-slug>/`.

Install from the self-hosted marketplace:

```bash
omp plugin marketplace add processmission/oh-my-qemu
omp plugin install oh-my-qemu@processmission
```

Local development link:

```bash
omp plugin link /path/to/oh-my-qemu
```

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
`oh-my-qemu:qemu-plan`.

---

## Recommended workflow in a QEMU tree

Initialize a task workspace:

```text
/qemu-init-task k230-uart-model
```

This creates:

```text
.oh-my-qemu/k230-uart-model/
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

For a complete modeling run, keep the request in the task workspace and compose
the workflow skills from there. In a QEMU tree, create
`.oh-my-qemu/k230-uart-model/task.md`:

```bash
mkdir -p .oh-my-qemu/k230-uart-model
cat > .oh-my-qemu/k230-uart-model/task.md <<'EOF'
---
slug: k230-uart-model
workstream: peripheral-modeling
---

Model the K230 UART and prove it with qtest.
EOF
```

Then ask the agent to use the appropriate QEMU workflow skill from that QEMU
tree. The workflow creates the task root, records a provenance snapshot, plans
the work, runs implementation/verification/review loops, prepares human-owned
final-series drafts, and writes
`.oh-my-qemu/k230-uart-model/rlcr/final-summary.md`.

Typical composition:

1. `qemu-plan` - define goal, scope, acceptance criteria, and evidence.
2. `qemu-source-provenance`, `qemu-image-layout`, and `qemu-boot-run` - record
   sources, artifacts, media layout, and run commands.
3. `qemu-register-extraction`, `qemu-workflow-peripheral-modeling`, or
   `qemu-workflow-board-modeling` - build the model from verified hardware facts.
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
- agents do not add DCO/review trailers to repository commits or sign on behalf of humans;
- final-series DCO trailers are drafted only for human review and ownership;
- QEMU DCO is the standard `Signed-off-by: Name <email>` trailer; the tool-user
  git identity normally satisfies it unless a distinct second signer is recorded;
- `AI-used-for:` is only a proposed qemu-devel scope-disclosure trailer for
  human-enabled final-series drafts; it is not an AI-agent DCO sign-off;
- local research, debugging, verification, and workflow guidance are allowed.

The workflow design is based on
[PolyArch/humanize](https://github.com/PolyArch/humanize): plan with explicit
acceptance criteria, iterate in reviewed rounds, and keep evidence attached to
the work.

---

## Methodology feedback

At final completion, pause, blocked state, or max-iteration exit of an RLCR or
composed workflow, the agent can write a one-time methodology feedback record.
It summarizes reusable workflow problems or improvements into:

```text
.oh-my-qemu/<task-slug>/methodology-feedback.md
```

The report must be sanitized before it is shown or filed: no private paths,
branch names, commit hashes, proprietary logs, code snippets, project-specific
URLs, image paths, or board/customer/product identifiers unless explicitly
approved.

If reusable improvements exist, use `qemu-agent-feedback` to draft the
public issue from the sanitized report and file it with the local GitHub CLI
when approved. The default target is `processmission/oh-my-qemu`,
overrideable with `QEMU_METHODOLOGY_ISSUE_REPO=owner/repo`.

Draft an improvement issue from a sanitized report:

```bash
npm run methodology:issue -- .oh-my-qemu/<task-slug>
```

This writes:

```text
.oh-my-qemu/<task-slug>/scratch/methodology-issue-title.txt
.oh-my-qemu/<task-slug>/scratch/methodology-issue.md
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
