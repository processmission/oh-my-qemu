# QEMU Skill Repository Agent Guide

This file governs development of this repository. It is not installed into
QEMU. Each installed skill must contain its own runtime rules and must not
depend on or cite this file.

## QEMU upstream boundary

QEMU's official GitLab and mailing lists are upstream channels. A patch becomes
an upstream contribution only when it is sent to the mailing-list recipients
selected through QEMU's `MAINTAINERS`.

- Do not prepare or send agent-generated code or documentation for upstream
  submission. Follow QEMU's current `docs/devel/code-provenance.rst`.
- Local branches, commits, patch files, pushes, and pull requests are not by
  themselves upstream contributions. Perform Git actions only when requested.
- Research, debugging, analysis, local experiments, verification, and workflow
  guidance are allowed.

Changes to this repository follow its local Git policy.

## Skill rules

- Put skills in `skills/<skill-name>/SKILL.md`.
- Keep each skill independently installable. Do not depend on another skill,
  repository file, installer behavior, or plugin hook.
- Precede YAML frontmatter with the Process Mission copyright and MIT SPDX
  comments; keep YAML data fields to `name` and `description`.
- Include matching `agents/openai.yaml` with quoted `display_name`,
  `short_description`, and `$skill-name` `default_prompt`.
- Keep `SKILL.md` concise. Put long material in one-level `references/`,
  `scripts/`, or `assets/`.
- Do not require checkpoint commits. Stage or commit only when requested.
- Require explicit approval for external writes such as `gh issue create`.

Every skill must include the compact audit contract. For a non-trivial task
that writes to QEMU, use only the needed entries under:

```text
.oh-my-qemu/<task-slug>/
├── audit.md
├── commands.md
├── logs/
├── scripts/
└── output/
```

Keep temporary tooling in `scripts/`, generated or third-party artifacts in
`output/`, and QEMU build output in a named source-root directory such as
`builds/build-aarch64/`—never `build/` or task `output/`. Change source files
only when they are the requested deliverable.

Before creating audit artifacts or configuring QEMU, add `.agents/`,
`.oh-my-qemu/`, and `builds/` to the repository-local
`git rev-parse --git-path info/exclude`. Preserve existing entries, avoid
duplicates, never stage these paths, and verify them absent from
`git status --short` at handoff.

## Installer rules

Keep `install.sh` self-contained and project-local. It must:

- run `npx skills add`, defaulting non-interactively to all skills for Codex and
  Claude Code;
- reject global installs and tracked installer-managed paths or lockfiles;
- support `--skill` and use this checkout's local skill tree;
- update Git excludes only after a successful install for `.agents/`,
  `.claude/skills/`, `.oh-my-qemu/`, `builds/`, and `skills-lock.json`.

Direct `npx skills add` installs skills only and does not update Git excludes.
Keep validation in `scripts/validate-codex-skills.mjs` and public documentation
in `site/`.

Run:

```bash
npm run codex:skills:validate
```
