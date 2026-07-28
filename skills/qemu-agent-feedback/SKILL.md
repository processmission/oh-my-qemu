---
# SPDX-FileCopyrightText: Copyright (c) 2026 Process Mission
# SPDX-License-Identifier: MIT
name: qemu-agent-feedback
description: Use when a completed QEMU skill session exposed a reusable oh-my-qemu workflow problem and the user wants a sanitized improvement proposal drafted or filed as a GitHub issue.
---

# QEMU Agent Feedback

## Audit workflow

For non-trivial workspace writes, use a stable
`.oh-my-qemu/<task-slug>/` directory and create only needed entries:

```text
.oh-my-qemu/<task-slug>/
├── audit.md      # Baseline, scope, decisions, evidence, verification, and gaps
├── commands.md   # Redacted commands, working directories, and results
├── logs/         # Decisive build, test, runtime, or diagnostic logs
├── scripts/      # Temporary scripts, probes, parsers, and harnesses
└── output/       # Generated deliverables, dependencies, and non-QEMU binaries
```

Before changing source or mutable artifacts, record the workspace root,
revision, `git status --short`, pre-existing changes, goal, scope, and
acceptance checks in `audit.md`. Log exact redacted commands and results in
`commands.md`; record revisions, configurations, tool versions, and hashes when
they affect reproducibility. Separate observations from inferences and edit
source only when requested.

Keep QEMU builds under source-root `builds/build-<target>/`; put third-party
dependencies and non-QEMU binaries in task `output/`. Before writing audit
artifacts or configuring QEMU in a Git worktree, add `.agents/`,
`.oh-my-qemu/`, and `builds/` to the repository-local file from
`git rev-parse --git-path info/exclude`; preserve existing entries and avoid
duplicates. Never stage or commit those directories. At handoff, verify them
absent from `git status --short`. Report the task directory and unresolved gaps.

## Boundary

Use only summary-level task evidence and conversation context. Do not quote raw
logs, source snippets, stack traces, private commands, or unreviewed artifacts
into a public proposal. Do not file anything unless the user explicitly asks
for it or approves the final title and body.

The default issue repository is `processmission/oh-my-qemu`. Honor an explicit
user-selected repository instead.

## Sanitize

Replace or remove:

| Sensitive value | Public replacement |
| --- | --- |
| local paths, user names, home directories | `<local-path>` |
| private repositories, branches, commits, or tree IDs | `<repo>` / `<git-ref>` |
| private URLs, endpoints, credentials, or tokens | `<url>` / `<secret>` |
| proprietary artifacts, SDKs, images, kernels, or root filesystems | `<artifact>` |
| unapproved customer, product, board, or SoC names | `<target>` |
| raw logs, stack traces, commands, or code | a behavior-level summary |

Before presenting the draft, verify that the proposed title and body disclose
none of these values. Treat uncertainty as a privacy gap and ask the user before
including it.

## Draft

Write the proposed title to
`.oh-my-qemu/<task-slug>/output/methodology-issue-title.txt` and the body to
`.oh-my-qemu/<task-slug>/output/methodology-issue.md` with this shape:

```markdown
## Summary

## Sanitized context

## Problem observed

## Expected behavior

## Impact

## Suggested improvement

## Reproduction shape

## Privacy check
```

Keep the proposal to one reusable workflow problem. State evidence and gaps;
do not present a project-specific failure as a general conclusion.

## File only with approval

After the user approves the exact title, body, and target repository, check
`gh auth status`, then run:

```bash
approved_repo="<approved owner/repository>"
gh issue create \
  --repo "$approved_repo" \
  --title "<approved title>" \
  --body-file .oh-my-qemu/<task-slug>/output/methodology-issue.md
```

Record the resolved `approved_repo`, approved command, and resulting issue URL
in `commands.md` and `audit.md`. If `gh` is unavailable, unauthenticated, or
fails, leave the two sanitized draft files for manual filing and report the gap.
