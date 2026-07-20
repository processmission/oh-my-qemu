# Oh My QEMU

Focused, auditable agent skills for QEMU modeling, builds, images, boot,
debugging, tests, documentation, and TCG work.

Use these skills inside the project where the work will happen. For a QEMU
checkout, that normally means installing them from the QEMU source-tree root.

## Recommended installation

Run this command from the QEMU repository root. No Oh My QEMU repository clone
or global skill installation is needed:

```bash
curl -fsSL https://raw.githubusercontent.com/processmission/oh-my-qemu/main/install.sh | bash
```

The installer immediately installs all 17 skills for both Codex and Claude Code
in the current project. There is no skill-selection prompt and no global
installation.

After a successful install, the script idempotently adds `.agents/`,
`.claude/skills/`, `.oh-my-qemu/`, and `builds/` to the repository-local Git
exclude file, and excludes the generated `skills-lock.json`. It preserves
existing entries, deduplicates
leading/trailing-slash variants, and does not change the shared `.gitignore`.
Linked worktrees sharing one Git common directory also share this exclude file.
Global flags are rejected.

To avoid claiming a clean local install when Git would still show changes, the
installer refuses targets that already track `.agents/skills/`,
`.claude/skills/`, or `skills-lock.json`.

The generated lockfile remains available locally for updates but does not appear
in `git status`.

Preview the available skills without installing anything:

```bash
npx skills add https://github.com/processmission/oh-my-qemu -l
```

`-l` lists the catalog only. It does **not** install skills.

## Optional contributor installation

Skill developers and contributors can clone this repository, then install the
local working tree into a specific QEMU checkout:

```bash
git clone https://github.com/processmission/oh-my-qemu.git
cd oh-my-qemu
./install.sh --target /path/to/qemu
```

This form also installs all 17 skills, using the cloned checkout as its source
so local changes can be tested before publication. To install only a subset:

```bash
./install.sh --target /path/to/qemu --skill qemu-build
```

The installer uses `npx skills add` underneath. Calling `npx skills add`
directly is a lower-level option, but it does not perform the Git exclude setup.
Portable installation does not install the optional `/qemu-init-task` command
or artifact-policy hook.

## Skill catalog

| Skill | Purpose |
| --- | --- |
| `qemu-workflow` | Scope a non-trivial task, select skills, and maintain acceptance and evidence gates. |
| `qemu-agent-feedback` | Draft one sanitized workflow-improvement issue and file it only after approval. |
| `qemu-image` | Inspect, describe, verify, and package raw, qcow2, partitioned, and firmware boot media. |
| `qemu-boot-run` | Construct reproducible QEMU commands and classify boot results with logs and timeouts. |
| `qemu-build` | Configure, reuse, build, and diagnose QEMU build directories. |
| `qemu-debug` | Debug QEMU or guests with host debuggers, gdbstub, traces, logs, and replay. |
| `qemu-kernel-build` | Build Linux kernel, DTB, modules, and related artifacts for QEMU tests. |
| `qemu-model-verification` | Turn model behavior into explicit PASS, FAIL, or INCONCLUSIVE evidence. |
| `qemu-qtest` | Design, register, run, and debug qtest coverage. |
| `qemu-register-extraction` | Extract register contracts, side effects, IRQ/DMA behavior, and driver sequences. |
| `qemu-rst-documentation` | Write and validate QEMU reStructuredText documentation and toctree updates. |
| `qemu-uboot-build` | Build U-Boot, SPL/TPL, FIT/ITB, and firmware-chain artifacts. |
| `qemu-board-modeling` | Research and model boards, SoCs, memory maps, boot paths, and IRQ topology. |
| `qemu-linux-boot` | Boot Linux directly or through firmware and preserve the complete handoff evidence. |
| `qemu-peripheral-modeling` | Research and model MMIO, qdev, SysBus, IRQ, timer, DMA, and register-bank devices. |
| `qemu-tcg-frontend` | Research, review, or debug guest instruction decode and TCG translation. |
| `qemu-tcg-backend` | Research, review, or debug host backend ops, constraints, emission, atomics, and vectors. |

## How the skills work

Start with `qemu-workflow` for a non-trivial task. It selects the smallest useful
set of domain and flow skills, then keeps their outputs under:

```text
.oh-my-qemu/<task-slug>/
  audit.md
  commands.md
  logs/
  scripts/
  output/
```

Every skill is independently auditable: it records its inputs and sources,
commands and decisions, produced artifacts, verification evidence, and any
remaining uncertainty needed for another person or agent to reproduce the work.

Source files should change only when they are the requested deliverable.
Temporary scripts belong in `scripts/`; generated deliverables, third-party
dependencies, and non-QEMU binaries belong in `output/`. QEMU itself is always
configured into a named source-root directory such as
`builds/build-aarch64/`, never an unqualified `build/`.

## Example prompts

> Use `qemu-workflow` to model this UART from the supplied datasheet and Linux
> driver. Extract the register contract, implement a local experiment, add qtest
> coverage, build it, and produce reproducible verification evidence.

> Diagnose why this firmware image stops after early MMIO setup. Inspect the
> image layout, reproduce the boot, use QEMU tracing and gdbstub as needed, and
> report the first unsupported behavior with commands and evidence.

## Optional plugin helpers

Use a plugin only if you also need `/qemu-init-task` and the artifact-policy
hook. The skills themselves are identical to the `npx skills` installation.

Oh My Pi:

```bash
omp plugin marketplace add processmission/oh-my-qemu
omp plugin install oh-my-qemu@processmission
```

Claude Code:

```bash
claude plugin marketplace add processmission/oh-my-qemu
claude plugin install oh-my-qemu@processmission
```

## QEMU AI provenance boundary

These skills support research, debugging, static analysis, local-only
experiments, workflow guidance, and evidence collection. They must not be used
to generate code or documentation intended for submission to QEMU upstream.

Agent-generated local experiment output must not be included in an upstream
contribution. Upstream authors remain responsible for QEMU's current
`docs/devel/code-provenance.rst` policy, authorship, review, and DCO sign-off.

## Development

Skills live in `.agents/skills/<skill-name>/SKILL.md`. Keep frontmatter limited
to `name` and `description`, and keep every skill's audit contract self-contained.

Validate the catalog before committing:

```bash
npm run codex:skills:validate
```

## License

MIT. Copyright (c) 2026 Process Mission. See [LICENSE](LICENSE).
