---
name: qemu-agent-feedback
description: Use as a QEMU flow primitive to summarize sanitized oh-my-qemu agent workflow feedback, draft improvement proposals, and file them with gh when approved.
---

# QEMU Agent Feedback

Use this primitive when an oh-my-qemu skill or workflow session found a
reusable agent workflow problem and the user wants it turned into a sanitized
improvement proposal.

## Primitive Boundary

This primitive owns only agent-workflow feedback reporting: collecting
session-level lessons, removing sensitive details, drafting one improvement
proposal, checking local `gh` availability, and filing the proposal as an issue
when approved. It consumes existing task artifacts and conversation context. It
does not choose modeling, build, boot, debug, verification, or iteration steps.

## Target Repository

Default target:

```text
processmission/oh-my-qemu
```

Allow override:

```bash
QEMU_METHODOLOGY_ISSUE_REPO=owner/repo
```

## Inputs

Use only summary-level sources:

- the current conversation's QEMU skill or workflow problems;
- `.oh-my-qemu/<task-slug>/methodology-feedback.md`, if present;
- `plan.md`, `evidence.md`, `commands.md`, `source-provenance.md`,
  `image-layout.md`, `boot-run.md`, and `rlcr/final-summary.md` summaries;
- reviewer feedback about skill behavior or workflow composition.

Do not quote raw logs, source snippets, stack traces, private command lines, or
unreviewed artifacts into the proposal.

## Sanitization Rules

Replace sensitive values before drafting:

| Sensitive value | Replacement |
| --- | --- |
| local paths, user names, home directories | `<local-path>` |
| private repository names or remotes | `<repo>` |
| branch names, commit hashes, tree IDs | `<git-ref>` |
| private URLs, endpoints, downloads | `<url>` |
| tokens, keys, cookies, credentials | `<secret>` |
| proprietary image, kernel, rootfs, or SDK names | `<artifact>` |
| customer, product, board, or SoC identifiers not approved for disclosure | `<target>` |
| raw logs, stack traces, code snippets | summarize behavior instead |

Before filing, explicitly verify:

- no private paths or local usernames;
- no branch names, commit hashes, or tree IDs;
- no tokens, credentials, endpoints, or private URLs;
- no proprietary logs, raw stack traces, code snippets, or command output;
- no customer, product, board, SoC, SDK, image, kernel, or rootfs identifiers
  unless the user approved that exact text for a public issue.

## Improvement Issue Template

Draft the GitHub issue in this structure:

```markdown
## Summary

<one short paragraph describing the reusable agent-workflow improvement opportunity>

## Sanitized Context

- Workflow area: <modeling | boot | debug | build | qtest | documentation | mixed>
- Trigger: <what kind of task exposed the problem>
- Affected skill or workflow: <sanitized name if public>

## Problem Observed

<what failed, confused the agent, duplicated responsibility, or caused ambiguity>

## Expected Behavior

<how the skill or workflow should guide the agent>

## Impact

<why this matters for future QEMU work>

## Suggested Improvement

<specific change to skill text, workflow composition, helper scripts, docs, or tests>

## Reproduction Shape

<sanitized steps or task shape, not private commands or logs>

## Privacy Check

- [x] No private paths, repository paths, or local usernames.
- [x] No branch names, commit hashes, or git identifiers.
- [x] No proprietary logs, raw errors, or stack traces.
- [x] No code snippets or code fragments.
- [x] No project-specific URLs, endpoints, image paths, or credentials.
- [x] No customer, product, board, or SoC identifiers unless explicitly approved.
```

## Draft and File

Prefer the repository helper when a task root exists:

```bash
node /path/to/oh-my-qemu/scripts/draft-methodology-issue.mjs .oh-my-qemu/<task-slug>
```

It writes:

```text
.oh-my-qemu/<task-slug>/scratch/methodology-issue-title.txt
.oh-my-qemu/<task-slug>/scratch/methodology-issue.md
```

If there is no task root, create equivalent title and body files under a
temporary or task-local scratch directory.

Check the GitHub CLI:

```bash
command -v gh
gh auth status
```

File only after the title and body have passed the privacy check and the user
has approved filing, or when the user's current instruction explicitly asks to
file the issue:

```bash
gh issue create \
  --repo "${QEMU_METHODOLOGY_ISSUE_REPO:-processmission/oh-my-qemu}" \
  --title "$(cat .oh-my-qemu/<task-slug>/scratch/methodology-issue-title.txt)" \
  --body-file .oh-my-qemu/<task-slug>/scratch/methodology-issue.md
```

If `gh` is unavailable, unauthenticated, or network access fails, leave the
sanitized title/body paths and the exact `gh issue create` command for manual
filing.
