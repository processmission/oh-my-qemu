---
title: "Getting started"
description: "Preview and install Oh My QEMU skills locally, then prepare an auditable QEMU workspace."
order: 1
category: "Start"
---

Oh My QEMU provides 17 independently installable skills for local QEMU
research, modeling, build, boot, debug, qtest, and documentation work.

## Recommended project-local install

Run this command from the QEMU repository root. It downloads the skill source
through `npx` and installs all 17 skills into project-local Codex and Claude Code
without a selection prompt or a manual Oh My QEMU clone:

```bash
curl -fsSL https://raw.githubusercontent.com/processmission/oh-my-qemu/main/install.sh | bash
```

The installer is always project-local and rejects global flags. After the skill
install succeeds, it idempotently adds `.agents/`, `.claude/skills/`,
`.oh-my-qemu/`, `builds/`, and the generated `skills-lock.json` to the
repository-local Git exclude, preserving existing entries and deduplicating
slash variants. It does not modify the shared `.gitignore`. Linked worktrees
that use one Git common directory share the exclude file.

The lockfile remains available locally for updates but does not appear in
`git status`.

## Optional contributor installation

Skill developers and contributors can clone Oh My QEMU and install their local
working tree into a specific QEMU checkout:

```bash
git clone https://github.com/processmission/oh-my-qemu.git
cd oh-my-qemu
./install.sh --target /path/to/qemu
```

This installs all 17 skills from the cloned working tree, including local
changes. To install only one skill:

```bash
./install.sh --target /path/to/qemu --skill qemu-build
```

Preview the catalog without installing anything:

```bash
npx skills add https://github.com/processmission/oh-my-qemu -l
```

Direct `npx skills add` remains available as a lower-level path, but it does not
perform the repository-local Git exclude setup. Portable installation also does
not install the optional plugin command or runtime hook.

## Start a task

For a non-trivial task that writes to a QEMU workspace, create only the entries
you need under:

```text
.oh-my-qemu/<task-slug>/
├── audit.md
├── commands.md
├── logs/
├── scripts/
└── output/
```

Use `scripts/` for temporary probes, parsers, and harnesses. Use `output/` for
generated deliverables, downloaded dependency artifacts, and non-QEMU build
binaries. Record scope, sources, decisions, and verification in `audit.md`, and
reproducible commands and results in `commands.md`.

## Build QEMU by target

QEMU's own build output belongs in the source-root `builds/` directory:

```sh
mkdir -p builds/build-aarch64
cd builds/build-aarch64
../../configure --target-list=aarch64-softmmu
ninja
```

Use a distinct name such as `builds/build-riscv64/` or
`builds/build-aarch64-debug/` for every target or configuration. Never place a
QEMU build in `build/` or the task's `output/` directory.
