# QEMU Skill Repository Agent Guide

This repository stores portable agent skills plus optional Oh My Pi and Claude
Code helpers for local QEMU work. It is not a QEMU upstream source branch.

## QEMU upstream provenance boundary

QEMU's `docs/devel/code-provenance.rst` applies inside a QEMU source checkout
and to anything proposed for upstream submission:

- Do not generate code or documentation intended for QEMU upstream submission.
- Decline requests for agent-written upstream patches and point to QEMU's
  current AI-generated-content policy.
- Research, debugging, static analysis, local-only experiments, verification,
  and workflow guidance are allowed when generated output is not contributed.

Repository-maintenance changes in this skill repository follow its normal local
Git policy.

## Auditable workspace contract

Every skill is independently installable and contains the same compact audit
workflow. For non-trivial tasks that write to a QEMU workspace, use only the
entries the task needs under:

```text
.oh-my-qemu/<task-slug>/
├── audit.md
├── commands.md
├── logs/
├── scripts/
└── output/
```

- `scripts/` holds temporary scripts, probes, parsers, and harnesses.
- `output/` holds generated deliverables, third-party dependency artifacts,
  and non-QEMU build binaries.
- QEMU's own build output belongs only in a named source-root directory such as
  `builds/build-aarch64/`, never `build/` or task `output/`.
- Source files change only when they are the requested deliverable.

Before writing audit artifacts or configuring QEMU in a Git worktree, add these
entries to the repository-local file returned by
`git rev-parse --git-path info/exclude`:

```text
.agents/
.oh-my-qemu/
builds/
```

Preserve existing entries, avoid duplicates, never stage or commit these
directories, and verify them absent from `git status --short` at handoff.

## Portable installation boundary

The root `install.sh` is the recommended project-local entry point. It runs
`npx skills add`, defaults to all skills in project-local Codex and Claude Code
without prompts, rejects global installation, and updates the required
repository-local Git excludes only after installation succeeds. The installer
also excludes `.claude/skills/` and `skills-lock.json`; the shared audit
workspace contract above remains the three tool-independent directories. An
explicit `--skill` selects a subset. When invoked from a repository checkout,
it installs that local skill tree into the target, which supports contributor
testing. It rejects targets that already track an installer-managed skill path
or lockfile because repository-local excludes cannot hide tracked changes.
Direct
`npx skills add` installs skill directories only; it does not execute source
repository hooks, update Git excludes, or install plugin command/runtime
scripts. Each skill still enforces the audit contract when it runs alone.

## Repository layout

- `.agents/skills/<skill-name>/SKILL.md`: portable skill catalog.
- `install.sh`: self-contained curl installer for a selected Git project root.
- `skills`: symlink to `.agents/skills` for plugin discovery.
- `src/extension.js`: Oh My Pi tools, command, and artifact-policy hook.
- `src/lib.mjs`: shared minimal workspace initialization and policy logic.
- `commands/qemu-init-task.md`: optional `/qemu-init-task` command.
- `hooks/hooks.json`: Claude Code pre-tool policy hook.
- `.claude-plugin/`: Claude Code and marketplace metadata.
- `scripts/`: repository validation and optional plugin entry points.

The optional initializer creates only `audit.md`, `commands.md`, `logs/`,
`scripts/`, `output/`, and source-root `builds/`, then updates the three local
Git exclude entries.

## Skill catalog

### Coordination and feedback

- `qemu-workflow`: optional planning, provenance, small-round review, evidence,
  and handoff for multi-step tasks.
- `qemu-agent-feedback`: self-contained sanitization and approved filing of one
  reusable oh-my-qemu workflow improvement.

### Modeling and TCG

- `qemu-register-extraction`
- `qemu-peripheral-modeling`
- `qemu-board-modeling`
- `qemu-tcg-frontend`
- `qemu-tcg-backend`

### Build, image, and boot

- `qemu-build`
- `qemu-kernel-build`
- `qemu-uboot-build`
- `qemu-image`
- `qemu-boot-run`
- `qemu-linux-boot`

### Verification and support

- `qemu-qtest`
- `qemu-debug`
- `qemu-model-verification`
- `qemu-rst-documentation`

## Skill design rules

- Keep YAML data fields to `name` and `description`, preceded by the Process
  Mission copyright and MIT license SPDX comments used by the Zephyr skills.
- Keep a matching `agents/openai.yaml` in every skill with quoted
  `display_name`, `short_description`, and `$skill-name` `default_prompt`.
- Make each skill usable when installed alone; do not require repository-level
  scripts, plugin hooks, or another skill.
- Repeat the compact audit workflow in every `SKILL.md` intentionally.
- Keep the main skill concise; move long templates and variants to one-level
  `references/`, `scripts/`, or `assets/` resources inside that skill.
- Do not reintroduce mandatory checkpoint commits. Stage or commit only when
  the user explicitly requests that separate Git action.
- Keep external writes, including `gh issue create`, behind explicit approval.

Validate with:

```bash
npm run codex:skills:validate
```

## Upstream references

The structure draws from the QEMU “AGENTS.md and associated skills” RFC and the
current QEMU code-provenance policy. Those are references, not permission to
produce upstreamable QEMU patches.
