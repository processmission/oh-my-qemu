# QEMU Skill Repository Agent Guide

This file governs development of the portable skills in this repository. It is
not installed into target QEMU checkouts. Installed skills must not depend on
or cite this file; put every runtime rule the skill needs inside that skill.

This repository is not a QEMU upstream source branch and contains no agent
plugin runtime.

## QEMU upstream provenance boundary

QEMU's official GitLab and mailing lists are upstream project channels. For
patches, follow the recipients and lists selected through `MAINTAINERS`:
sending a patch there is a QEMU upstream contribution.

- Do not prepare or send agent-generated code or documentation for that
  mailing-list submission. Point such requests to QEMU's current
  `docs/devel/code-provenance.rst` policy.
- Creating a local branch, commit, or patch file, pushing a branch, or opening a
  pull request is not by itself a QEMU upstream contribution. Perform those Git
  actions only when the user requests them and follow the workspace's Git
  policy.
- Research, debugging, static analysis, local-only experiments, verification,
  and workflow guidance remain allowed.

Repository-maintenance changes in this skill repository follow its normal local
Git policy.

## Installed skill authoring rules

Keep every skill independently installable and include the same compact audit
workflow. Require non-trivial tasks that write to a QEMU workspace to use only
the entries they need under:

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

## Installer development rules

Keep root `install.sh` as the recommended project-local entry point. Preserve
these behaviors:

- run `npx skills add`;
- default to all skills in project-local Codex and Claude Code without prompts;
- reject global installation;
- update repository-local Git excludes only after installation succeeds;
- exclude `.agents/`, `.claude/skills/`, `.oh-my-qemu/`, `builds/`, and
  `skills-lock.json`;
- let an explicit `--skill` select a subset;
- install the local skill tree when invoked from this repository checkout;
- reject targets that track an installer-managed skill path or lockfile.

Direct `npx skills add` installs skill directories only and does not update Git
excludes. Do not make an installed skill depend on installer behavior beyond
the files inside its own directory.

## Repository layout rules

- Put portable skill instructions in `skills/<skill-name>/SKILL.md`.
- Keep `install.sh` self-contained for curl-based installation.
- Keep repository validation in `scripts/validate-codex-skills.mjs`.
- Keep public documentation in `site/`.

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
prepare or send generated patches to the QEMU mailing lists.
