---
title: "Audit and upstream policy"
description: "How Oh My QEMU keeps local evidence auditable, isolates builds, and respects QEMU's upstream policy."
order: 3
category: "Policy"
---

Oh My QEMU is a local workflow toolkit, not a QEMU upstream contribution
branch. Its skills help collect evidence and keep QEMU-related work reviewable.

## Audit boundary

For a non-trivial task that writes to a QEMU workspace, keep task artifacts in:

```text
.oh-my-qemu/<task-slug>/
├── audit.md
├── commands.md
├── logs/
├── scripts/
└── output/
```

`audit.md` records scope, cited sources, decisions, assumptions, and verification.
`commands.md` records reproducible commands and their outcomes. Raw logs belong
in `logs/`, temporary helpers in `scripts/`, and generated deliverables or
non-QEMU binaries in `output/`.

## Build boundary

QEMU build output belongs only in a named source-root directory such as
`builds/build-aarch64/`. Third-party artifacts and non-QEMU binaries belong in
the task's `output/` directory. Source files change only when they are the
requested deliverable.

## Git boundary

Before writing audit data or configuring QEMU, ensure the repository-local file
returned by `git rev-parse --git-path info/exclude` contains an effective entry
for each of:

```text
.agents/
.oh-my-qemu/
builds/
```

Preserve existing entries, avoid adding slash-variant duplicates, never stage
these directories, and verify they are absent from `git status --short` at
handoff. Stage or commit only when the user explicitly requests that separate
Git action.

## QEMU upstream boundary

QEMU's current generated-content policy applies inside a QEMU source checkout
and to anything proposed for upstream submission. Do not generate code or
documentation intended for upstream QEMU. Research, debugging, static analysis,
local-only experiments, and verification remain valid when their generated
output is not contributed upstream.
