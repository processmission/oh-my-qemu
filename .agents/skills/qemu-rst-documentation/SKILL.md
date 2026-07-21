---
# SPDX-FileCopyrightText: Copyright (c) 2026 Process Mission
# SPDX-License-Identifier: MIT
name: qemu-rst-documentation
description: Use for writing or updating QEMU reStructuredText documentation, including board and machine docs, system docs, device docs, developer docs, boot command examples, feature status tables, Sphinx index/toctree updates, and docs build validation.
---

# QEMU RST Documentation

Use this skill when creating or updating QEMU `.rst` documentation, especially board or machine pages under `docs/system/`, device documentation, developer documentation, and boot-command examples tied to modeled hardware.

## Audit workflow

For every non-trivial task that writes to the workspace, choose a stable task
slug and keep all agent-only records under `.oh-my-qemu/<task-slug>/`. Create
only the entries the task needs:

```text
.oh-my-qemu/<task-slug>/
├── audit.md      # Baseline, scope, decisions, evidence, verification, and gaps
├── commands.md   # Redacted commands, working directories, and results
├── logs/         # Decisive build, test, runtime, or diagnostic logs
├── scripts/      # Temporary scripts, probes, parsers, and harnesses
└── output/       # Generated deliverables, dependencies, and non-QEMU binaries
```

Before changing source or mutable artifacts, record the workspace root,
branch/revision, `git status --short`, user-owned dirty paths, goal, scope, and
acceptance checks in `audit.md`. Record exact redacted commands and results in
`commands.md`; record source revisions, configurations, tool versions, and
input/output hashes when they affect reproducibility. Separate observations
from inferences and create or change source files only when requested.

Put every QEMU build in a named directory under the QEMU source root, such as
`builds/build-aarch64/`. Put third-party dependency artifacts and non-QEMU
binaries under the task's `output/` directory. In a Git worktree, before
writing audit records or configuring QEMU, add `.agents/`, `.oh-my-qemu/`, and
`builds/` to the repository-local exclude file returned by
`git rev-parse --git-path info/exclude`; preserve existing entries and avoid
duplicates. Never stage or commit those directories. Before handoff, verify
that `git status --short` contains none of them, then report the task directory
and unresolved gaps.

## Scope

Own RST documentation edits and documentation-specific validation. Base every
support statement and command example on inspected implementation, tests, or
recorded runtime evidence. For a simple typo or one-line docs fix, do not create
unneeded audit artifacts.

## Upstream policy boundary

Do not generate code or documentation intended for QEMU upstream submission.
For upstream-facing work, limit assistance to research, inspection, debugging,
and validation guidance; do not add DCO or review trailers.

## Source-First Rule

Before writing, inspect the checked-out QEMU tree:

- nearby docs in the same directory, such as `docs/system/<arch>/` or `docs/devel/`;
- the relevant `index.rst` or toctree file;
- existing board or machine docs for tone, section order, and command style;
- `MAINTAINERS` entries when adding a new documented area;
- the implementation, tests, and boot logs that prove the documented behavior.

Do not invent support status from code names alone. Document only behavior that is implemented, verified, or explicitly marked as a limitation.

## Board or Machine Page Shape

For a new board or machine document, prefer this structure unless nearby docs use a clearer local convention:

```rst
<Board or Machine Name>
=======================

Overview
--------

Supported devices
-----------------

Boot options
------------

Direct Linux boot
~~~~~~~~~~~~~~~~~

Firmware boot
~~~~~~~~~~~~~

Known limitations
-----------------

Running tests
-------------
```

Include only sections that carry useful information. If the board has no firmware path, do not add a placeholder firmware section.

## Content Rules

- Name QEMU machine types exactly as the command line uses them.
- Keep command lines copy-pasteable and line-wrapped consistently with nearby docs.
- Show serial console choices explicitly when boot logs depend on a specific UART or chardev.
- Separate supported hardware from known stubs, unimplemented regions, and compatibility workarounds.
- For boot examples, include enough `-machine`, `-cpu`, memory, storage, kernel, firmware, DTB, initrd, and console options for reproduction.
- Avoid promising hardware accuracy from a boot smoke alone; tie claims to qtest, trace, or workload evidence when available.
- Avoid project-local paths. Use placeholders such as `/path/to/Image` or variables documented in the surrounding text.

## RST Rules

- Match the heading hierarchy and adornment style used by nearby QEMU docs.
- Use inline literals with double backticks.
- Use literal blocks with `::` for shell commands unless nearby docs prefer `.. code-block::`.
- Do not use Markdown fences in `.rst`.
- Keep toctree entries sorted or grouped according to the local index.
- Add the new page to the relevant `index.rst` or toctree; a standalone file is not enough.
- Do not add labels, cross references, or substitutions unless you verify they resolve in the local docs build.

## Validation

Run the narrowest available docs gate from the checked-out QEMU tree:

```bash
ninja -C builds/build-docs docs
```

If the build directory is not configured for docs, inspect available targets first:

```bash
ninja -C builds/build-docs -t targets | rg 'docs|sphinx'
```

At minimum, run `git diff --check` and inspect the rendered RST mentally for heading hierarchy, toctree inclusion, literal block indentation, and overlong command examples. Store any docs build logs under `.oh-my-qemu/<task-slug>/logs/` when the work is part of a larger QEMU task.

## Report

When done, report:

- docs files changed;
- index/toctree updates;
- source evidence used for feature and boot claims;
- docs build or fallback validation;
- any intentionally undocumented or unverified behavior.
