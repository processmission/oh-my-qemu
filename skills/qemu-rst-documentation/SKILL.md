---
# SPDX-FileCopyrightText: Copyright (c) 2026 Process Mission
# SPDX-License-Identifier: MIT
name: qemu-rst-documentation
description: Use for writing or updating QEMU reStructuredText documentation, including board and machine docs, system docs, device docs, developer docs, boot command examples, feature status tables, Sphinx index/toctree updates, and docs build validation.
---

# QEMU RST Documentation

## Audit workflow

For a non-trivial task that writes to the workspace, use only the needed entries under
`.oh-my-qemu/<task-slug>/`: `audit.md` (baseline, plan, decisions, evidence, verification, and
gaps), `commands.md` (redacted commands, working directories, and results), `logs/` (decisive
build, test, and runtime output), `scripts/` (probes, parsers, and harnesses), and `output/`
(generated deliverables, third-party dependencies, and non-QEMU binaries). Keep QEMU's own build
tree at source-root `builds/build-<target>/`, never an unqualified `build/`. In a Git worktree,
add `.agents/`, `.oh-my-qemu/`, and `builds/` to the file from
`git rev-parse --git-path info/exclude` before writing artifacts or configuring QEMU; preserve
existing entries and avoid duplicates. Never stage or commit these paths; stage source only when
the user explicitly requests that separate action. At handoff, reconcile `git status --short`
with the baseline and report the task directory, build directory, source changes, pre-existing
changes, and unresolved gaps.

## QEMU upstream boundary

QEMU's official GitLab and mailing lists are upstream channels. A patch becomes an upstream
contribution when it is sent to the maintainers selected through `MAINTAINERS`. Do not prepare or
send agent-generated code, documentation, commit messages, or patches for upstream submission; see
the checked-out tree's `docs/devel/code-provenance.rst`. Research, debugging, analysis, local
experiments, verification, and workflow guidance remain allowed. Local branches, commits, patch
files, pushes, and pull requests are not by themselves upstream contributions; perform those Git
actions only when requested.

## Scope and allowed use

Write or update local, fork, or downstream QEMU documentation. This skill does not prepare
documentation for upstream submission; follow the boundary above and the checked-out tree's
`docs/devel/code-provenance.rst`. For a simple typo or one-line fix, do not create audit
artifacts: edit, validate the page, and report the change.

## Source-first rule

Before writing, inspect the checked-out tree:

- the nearest sibling page in the same directory, such as `docs/system/<arch>/`,
  `docs/devel/`, or `docs/tools/`;
- the relevant `index.rst` or toctree file;
- `MAINTAINERS` when adding a documented area;
- the implementation, tests, logs, or traces that prove the documented behavior.

Document only implemented, verified, or explicitly marked behavior. Do not infer support status
from names or from a boot smoke alone.

## Board and machine pages

Start from [the board page template](assets/board-machine-page-template.rst) and follow
[the page requirements](references/board-machine-page.md). A short board page (roughly 80-120
lines) contains overview, supported devices, boot options, machine properties, memory map
(optional), interrupts (optional), known limitations, running tests, and references (optional).
Omit empty sections and keep the nearest sibling page's section order and length.

- Document only behavior implemented in the checked-out tree and verified by qtest, trace, logs,
  or an explicit limitation note.
- Do not link external repositories, image recipes, private build systems, or local
  machine-image internals; use checked-out-tree paths only.
- Remove undecided internals instead of explaining them; record cuts in `audit.md`.
- Place the page in the architecture toctree by title sort, matching nearby entries.

## Content rules

- Name machine types exactly as the QEMU command line does.
- Keep command lines copy-pasteable and wrap them consistently.
- State serial console routing when boot output depends on it.
- Separate supported devices from stubs, unimplemented regions, and workarounds.
- Use placeholders such as `/path/to/Image`; never project-local paths.
- Tie behavior claims to qtest, trace, workload evidence, or a limitation note.

## RST rules

- Match the heading hierarchy and adornment style used by nearby pages.
- Use double backticks for inline literals and `::` for command blocks unless nearby docs
  prefer `.. code-block::`.
- Do not use Markdown fences or Markdown-only syntax.
- Keep toctree entries sorted or grouped as the local index does.
- Add the page to the relevant toctree; a standalone file is not enough.
- Verify that labels, references, and substitutions resolve in the local build.

## Validation

Run the local gates on the page and record the command, tool version, and result under `logs/`:

```bash
SKILL_DIR=<path-to-this-skill>
"$SKILL_DIR/scripts/rst-gates.sh" --repo-root <qemu-root> <page>.rst
ninja -C builds/build-<target> sphinxdocs
```

The script checks heading underlines, toctree presence, out-of-tree repository links, local
absolute paths, line length, literal blocks, and docutils parsing when available; record any SKIP
as a validation limitation. The `sphinxdocs` target exists only when Sphinx was found and docs
are enabled; configure a named build directory with `-Ddocs=enabled` when Sphinx is available.
When the target is absent, use the docutils or direct Sphinx fallback in
[docs-validation.md](references/docs-validation.md).

At minimum run `git diff --check` and inspect heading hierarchy, toctree inclusion,
literal-block indentation, and command-line wrapping.

## Report

Report the docs files changed, toctree updates, source evidence for behavior claims, the
validation command and result, known validation limitations, and any intentionally undocumented
behavior.

## Upstream references

- `docs/devel/docs.rst`
- `docs/devel/code-provenance.rst`
- `docs/devel/style.rst`
- `docs/devel/submitting-a-patch.rst`

Paths can differ between QEMU versions; locate them in the checked-out tree.
