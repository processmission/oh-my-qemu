---
title: "Portable, auditable QEMU skills"
description: "Why Oh My QEMU uses independent project-local skills, one audit contract, and named QEMU build directories."
pubDate: 2026-07-20
author: "Zevorn"
tags: ["workflow", "skills", "qemu"]
draft: false
---

Oh My QEMU is a set of 17 portable skills for local QEMU work. Each skill can
be installed on its own and carries the same small workspace contract, so a
project does not need any source-repository runtime.

## Project-local installation

From a QEMU source root, the recommended path is:

```bash
curl -fsSL https://raw.githubusercontent.com/processmission/oh-my-qemu/main/install.sh | bash
```

It requires no manual clone, installs all 17 skills into project-local Codex and
Claude Code, and rejects global flags. Skill contributors can instead clone Oh
My QEMU and run `./install.sh --target /path/to/qemu`; that form installs all
skills directly from their local working tree. The lower-level `npx skills add
https://github.com/processmission/oh-my-qemu -l` remains the preview-only
catalog command.

After installation, the target repository clone locally excludes `.agents/`,
`.claude/skills/`, `.oh-my-qemu/`, and `builds/`. This keeps installed skills,
audit evidence, build output, and the generated `skills-lock.json` out of commits
without changing the project's shared `.gitignore`.

## One audit contract

A non-trivial task uses the entries it needs under
`.oh-my-qemu/<task-slug>/`: `audit.md`, `commands.md`, `logs/`, `scripts/`, and
`output/`.

The two Markdown files preserve decisions and reproducible commands. Raw logs
stay in `logs/`; temporary probes and parsers stay in `scripts/`; generated
deliverables, dependency artifacts, and non-QEMU binaries stay in `output/`.
Because every skill repeats this contract, it remains auditable even when only
one skill is installed.

## Named QEMU builds

QEMU itself is the exception to the task output rule. Its build tree belongs at
the source root under a name such as `builds/build-aarch64/`. Separate names
make target, feature, and debug configurations explicit and prevent one task
from silently reusing an incompatible build.

## Small skills, clear boundaries

The catalog covers coordination and feedback; register, peripheral, board, and
TCG work; QEMU, kernel, U-Boot, image, and Linux boot workflows; and qtest,
debug, model verification, and reStructuredText documentation.

`qemu-workflow` is optional coordination for larger tasks.
`qemu-agent-feedback` remains a self-contained way to sanitize one reusable
workflow improvement and request approval before filing it externally. Neither
skill is required by the domain skills.

The result is deliberately simple: select the skill that matches the task,
keep evidence local and reviewable, isolate QEMU builds, and leave the source
tree with only the requested deliverables.
