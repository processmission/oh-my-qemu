---
# SPDX-FileCopyrightText: Copyright (c) 2026 Process Mission
# SPDX-License-Identifier: MIT
name: qemu-agent-feedback
description: Use when a completed QEMU skill session exposed a reusable oh-my-qemu workflow problem and the user wants a sanitized improvement proposal drafted or filed as a GitHub issue.
---

# QEMU Agent Feedback

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

## Privacy boundary

Keep the proposal at summary level: no raw logs, source snippets, stack traces, private
commands, or unreviewed artifacts. Do not file anything unless the user explicitly asks
for it or approves the exact title and body.

The default issue repository is `processmission/oh-my-qemu`; honor an explicit choice.

## One issue per proposal

Draft one reusable workflow problem per issue; leave incidental fixes out. Search existing
issues before drafting with `gh issue list --repo processmission/oh-my-qemu --search
"<keywords>" --state all`, then report a match instead of filing a duplicate; update it
only with user approval. If `gh` is unavailable, record the gap and produce the draft.

## Sanitize

| Sensitive value | Public replacement |
| --- | --- |
| local paths, user names, home directories | `<local-path>` |
| hostnames, machine IDs, hardware serials | `<host>` |
| git author identity, email, Signed-off-by | `<author>` |
| private repositories, branches, commits, or tree IDs | `<repo>` / `<git-ref>` |
| private URLs, endpoints, credentials, or tokens | `<url>` / `<secret>` |
| proprietary artifacts, SDKs, images, kernels, root filesystems | `<artifact>` |
| build paths, source roots, task and audit directories | `<build-path>` |
| unapproved customer, product, board, or SoC names | `<target>` |
| raw logs, stack traces, commands, or code | a behavior-level summary |

Verify the proposed title and body disclose none of these values before presenting the
draft; treat uncertainty as a privacy gap and ask the user.

## Draft

Write the title to `.oh-my-qemu/<task-slug>/output/methodology-issue-title.txt` and the
body to `.oh-my-qemu/<task-slug>/output/methodology-issue.md` using
[issue-template.md](references/issue-template.md). State the affected skill, observed and
expected behavior, and evidence gaps; never generalize a project-specific failure.

Run [check-redaction.sh](scripts/check-redaction.sh) over the title and body before
presenting the draft, and resolve every finding:

```bash
bash <skill-dir>/scripts/check-redaction.sh <title-file> <body-file>
```

## File only with approval

After the user approves the exact title, body, and target repository, check `gh auth
status` and confirm the issue is not a duplicate. Then run:

```bash
gh issue create --repo "<approved owner/repository>" \
  --title "<approved title>" \
  --body-file .oh-my-qemu/<task-slug>/output/methodology-issue.md
```

Record the approved repository, command, and issue URL in `commands.md` and `audit.md`. If
`gh` is unavailable or fails, keep the sanitized drafts and report the gap.

## Upstream references

- docs/devel/code-provenance.rst
- docs/devel/submitting-a-patch.rst
- docs/devel/testing/main.rst

Paths can differ between QEMU versions; locate them in the checked-out tree.
