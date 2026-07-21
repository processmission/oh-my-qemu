# Oh My QEMU

Portable, auditable skills for QEMU modeling, builds, boot, debugging, tests,
documentation, and TCG work.

## Install

Run from the QEMU repository root:

```bash
curl -fsSL https://raw.githubusercontent.com/processmission/oh-my-qemu/main/install.sh | bash
```

This installs all 17 skills project-locally for Codex and Claude Code. It also
adds `.agents/`, `.claude/skills/`, `.oh-my-qemu/`, `builds/`, and
`skills-lock.json` to the repository-local Git exclude without changing
`.gitignore` or adding duplicates. Global installation is rejected.

List the available skills without installing them:

```bash
npx skills add https://github.com/processmission/oh-my-qemu -l
```

## Contributor install

Contributors can install a local checkout into a specific QEMU repository:

```bash
git clone https://github.com/processmission/oh-my-qemu.git
cd oh-my-qemu
./install.sh --target /path/to/qemu
./install.sh --target /path/to/qemu --skill qemu-build
```

## Skills

- Workflow: `qemu-workflow`, `qemu-agent-feedback`
- Modeling: `qemu-register-extraction`, `qemu-peripheral-modeling`,
  `qemu-board-modeling`
- Build and boot: `qemu-build`, `qemu-kernel-build`, `qemu-uboot-build`,
  `qemu-image`, `qemu-boot-run`, `qemu-linux-boot`
- Verification: `qemu-qtest`, `qemu-debug`, `qemu-model-verification`,
  `qemu-rst-documentation`
- TCG: `qemu-tcg-frontend`, `qemu-tcg-backend`

## Workspace

Non-trivial tasks keep their audit trail under:

```text
.oh-my-qemu/<task-slug>/
  audit.md
  commands.md
  logs/
  scripts/
  output/
```

Temporary scripts belong in `scripts/`. Generated deliverables, third-party
dependencies, and non-QEMU binaries belong in `output/`. QEMU build output
belongs in a named source-root directory such as `builds/build-aarch64/`, never
an unqualified `build/`.

## QEMU provenance

These skills support research, debugging, local experiments, workflow guidance,
and evidence collection. Do not use agent-generated code, documentation, or
experiment output in QEMU upstream submissions. Follow QEMU's current
`docs/devel/code-provenance.rst` policy.

## Development

Skills live in `skills/<skill-name>/SKILL.md`. Every skill also contains
`agents/openai.yaml`, the Process Mission MIT SPDX header, and a self-contained
audit workflow.

```bash
npm run codex:skills:validate
```

## License

MIT. Copyright (c) 2026 Process Mission. See [LICENSE](LICENSE).
