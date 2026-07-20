---
name: qemu-agent-feedback
description: Use when a completed QEMU skill session exposed a reusable oh-my-qemu workflow problem and the user wants a sanitized improvement proposal drafted or filed as a GitHub issue.
---

# QEMU Agent Feedback

Turn reusable lessons from a QEMU task into one privacy-reviewed improvement
proposal. This skill is self-contained and does not require repository helper
scripts.

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
