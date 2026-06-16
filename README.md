# oh-my-qemu

QEMU-focused agent skills packaged as an Oh My Pi plugin, a Claude Code plugin, portable skills, and Codex-registerable local skills for hardware modeling, source builds, image packaging, boot testing, debugging, qtest, and TCG workflows.

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

Practice/demo branch using these ideas for downstream QEMU modeling work:

- RK3588/RK3588S Rockchip machines and shared IP models: https://github.com/processmission/qemu/tree/devel

## Skills

Primitive flow skills:

- `qemu-flow-plan`: task scope, acceptance criteria, artifact root, and verification gates.
- `qemu-source-provenance`: source trees, revisions, configs, toolchains, outputs, and hashes.
- `qemu-image-layout`: image formats, partitions, offsets, writes, mutation policy, and hashes.
- `qemu-boot-run`: reproducible QEMU boot commands, logs, timeouts, markers, and result classification.
- `qemu-model-verification`: evidence ladder and PASS/FAIL/INCONCLUSIVE reports.

Workflow skills compose the primitives:

- `qemu-register-extraction`: extract register maps, bitfields, side effects, IRQ/DMA behavior, and driver sequences.
- `qemu-rlcr-loop`: iterate implementation/debugging rounds with verification and review.
- `qemu-build`: configure, build, and diagnose QEMU build directories.
- `qemu-qtest`: design, register, run, and debug qtest coverage.
- `qemu-debug`: use gdbstub, host debugger, QEMU logs, trace events, replay, and instruction-window analysis.
- `qemu-peripheral-modeling`: model MMIO, qdev, SysBus, IRQ, timer, DMA, and register-bank devices.
- `qemu-board-modeling`: model boards, SoCs, memory maps, boot paths, firmware handoff, FDT, and IRQ topology.
- `qemu-kernel-build`: build Linux kernel artifacts for QEMU boot tests.
- `qemu-uboot-build`: build U-Boot/SPL/TPL/FIT artifacts for firmware boot tests.
- `qemu-image-packaging`: package boot media from kernels, firmware, DTBs, rootfs, and modules.
- `qemu-direct-linux-boot`: boot Linux directly with QEMU kernel options.
- `qemu-firmware-linux-boot`: boot Linux through firmware or bootloader stages.
- `qemu-tcg-frontend-instruction`: add or debug guest ISA decode and TCG translation.
- `qemu-tcg-backend-adaptation`: adapt TCG host backend ops, constraints, emission, atomics, and vectors.

## Install as portable skills

List available skills:

```bash
npx skills add https://github.com/processmission/oh-my-qemu -l
```

Install globally for supported agents:

```bash
npx skills add https://github.com/processmission/oh-my-qemu -g --all
```

Install into the current project:

```bash
npx skills add https://github.com/processmission/oh-my-qemu --all
```

## Register as Codex skills

From a local checkout:

```bash
cd /path/to/oh-my-qemu
```

Validate the skill metadata:

```bash
npm run codex:skills:validate
```

Preview registration:

```bash
npm run codex:skills:register:dry-run
```

Register into `${CODEX_HOME:-$HOME/.codex}/skills` using symlinks:

```bash
npm run codex:skills:register
```

Use a copy instead of symlinks, or target another directory:

```bash
node scripts/register-codex-skills.mjs --copy --target /path/to/codex/skills
```

Registration writes into `${CODEX_HOME:-$HOME/.codex}/skills`. The default symlink mode keeps Codex pointed at this checkout, so future edits to `~/oh-my-qemu/.agents/skills` are picked up without copying files again. Start a new Codex session after registering so the new skill metadata is loaded.

## Install as an Oh My Pi plugin

The plugin adds OMP-only helpers:

- `qemu_init_task` tool;
- `/qemu-init-task` slash command;
- artifact-policy hook that redirects root-level scratch artifacts to `build/agent/<task-slug>/`;
- the same skills exposed through the plugin `skills/` layout.

Install from this self-hosted marketplace repo:

```bash
omp plugin marketplace add processmission/oh-my-qemu
omp plugin install oh-my-qemu@processmission
```

Local development link:

```bash
omp plugin link /path/to/oh-my-qemu
```

## Install as a Claude Code plugin

The repository is also a Claude Code plugin (`.claude-plugin/plugin.json`). Installing it exposes the skills, a `/qemu-init-task` slash command, and an artifact-policy `PreToolUse` hook that keeps agent artifacts under `build/agent/<task-slug>/`.

Add this repo as a marketplace and install:

```bash
claude plugin marketplace add processmission/oh-my-qemu
claude plugin install processmission@oh-my-qemu
```

Install into the current project only (committed for the team) with `--scope project`, or keep it local with `--scope local`.

Local development against a checkout:

```bash
claude plugin marketplace add /path/to/oh-my-qemu
claude plugin install processmission@oh-my-qemu
```

Or load the directory directly without a marketplace (good for iterating):

```bash
claude --plugin-dir /path/to/oh-my-qemu
```

Verify the plugin and its skills are loaded:

```bash
claude plugin list
claude plugin details processmission@oh-my-qemu
```

Installed skills are namespaced as `oh-my-qemu:<skill>` (for example `oh-my-qemu:qemu-flow-plan`) and are auto-discovered like any other skill. The `skills/` directory is a symlink to `.agents/skills`, so the same SKILL.md content backs the Claude Code plugin, the OMP plugin, and the portable `npx skills` install.

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
  source-provenance.md
  image-layout.md
  boot-run.md
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
2. Choose primitives:
   - `qemu-source-provenance` for source/build artifacts.
   - `qemu-image-layout` for boot media and firmware images.
   - `qemu-boot-run` for QEMU command execution.
3. Choose workflow or domain skills:
   - `qemu-kernel-build`, `qemu-uboot-build`, `qemu-image-packaging`, `qemu-direct-linux-boot`, or `qemu-firmware-linux-boot` for quick run/test loops.
   - `qemu-register-extraction`, `qemu-peripheral-modeling`, or `qemu-board-modeling` for modeling work.
4. `qemu-rlcr-loop` — iterate with verification and independent review.
5. `qemu-build`, `qemu-qtest`, `qemu-debug`, and `qemu-model-verification` — prove the result.

Common compositions:

```text
kernel build -> direct linux boot -> verification
uboot build -> image packaging -> firmware linux boot -> debug if needed -> verification
image packaging -> boot run -> verification
```

## Update

Portable skills:

```bash
npx skills update -g
```

OMP plugin:

```bash
omp plugin upgrade oh-my-qemu@processmission
```

Claude Code plugin:

```bash
claude plugin install processmission@oh-my-qemu
```

Re-add the marketplace to pick up new commits, or manage versions through the interactive `/plugin` menu.

## License

MIT. Copyright (c) 2026 Process Mission. See [LICENSE](LICENSE).
