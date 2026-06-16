# QEMU Methodology Feedback

Use this phase at the end of a QEMU workflow to extract reusable workflow improvements without leaking project-specific details. It is modeled after Humanize methodology analysis, but the target is QEMU modeling and oh-my-qemu workflow improvement.

## Trigger Policy

Ask about upstream feedback only at terminal points:

- RLCR complete after final verification;
- user explicitly pauses or stops the workflow;
- the workflow is blocked and no meaningful progress remains;
- max iteration or review limit is reached;
- a `/goal` or multi-workflow composition reaches its final completion or final pause point.

Do not ask after every primitive or workflow step. For a composition such as kernel build, image packaging, firmware boot, debug, and verification, ask at most once after the composition has ended.

## Feedback Artifact

Write the sanitized report to:

```text
build/agent/<task-slug>/methodology-feedback.md
```

Use only summary-level artifacts:

- `plan.md`
- `evidence.md`
- `commands.md` only for workflow shape, not verbatim private commands
- `source-provenance.md`
- `image-layout.md`
- `boot-run.md`
- `rlcr/round-*-summary.md`
- `rlcr/round-*-review.md`
- `rlcr/final-summary.md`

Do not quote raw logs, source snippets, stack traces, file paths, branch names, image paths, customer names, product names, SoC names, board names, or private URLs unless the user explicitly approves that exact detail for public issue text.

## Report Shape

Use this structure:

```markdown
# <task> Methodology Feedback

## Status

- State: analyzed
- Exit reason: <complete | paused | blocked | max-iteration>
- User asked for issue: <yes | no>
- Issue filed: <yes | no>

## Sanitized Workflow Context

- Workflow type: <board modeling | peripheral modeling | firmware boot | direct boot | debug | packaging | mixed>
- Exit condition:
- Phases involved:

## Observed Patterns

## Improvement Suggestions

## Issue Draft

### Title

### Body

## Privacy Check

- [x] No private paths, repository paths, or local usernames.
- [x] No branch names, commit hashes, or git identifiers.
- [x] No proprietary logs, raw error messages, or stack traces.
- [x] No code snippets or code fragments.
- [x] No project-specific URLs, image paths, or endpoints.
- [x] No customer, product, board, or SoC identifiers unless explicitly approved.
```

If no reusable improvements are found, write `State: analyzed-no-suggestions`, keep the report brief, and do not ask the user to file an issue.

## User Consent Flow

If the report contains reusable improvements:

1. Summarize only the sanitized report.
2. Ask the user once whether they want to create an upstream issue.
3. If they decline, mark `User asked for issue: yes` and `Issue filed: no`.
4. If they agree, draft title and body in the report and show the draft for confirmation.
5. Only after confirmation, create the issue.

Default target repository:

```text
processmission/oh-my-qemu
```

Allow override:

```text
QEMU_METHODOLOGY_ISSUE_REPO=owner/repo
```

## Draft Helper

After the feedback file is sanitized, generate a draft:

```bash
node /path/to/oh-my-qemu/scripts/draft-methodology-issue.mjs build/agent/<task-slug>
```

This writes:

```text
build/agent/<task-slug>/scratch/methodology-issue.md
build/agent/<task-slug>/scratch/methodology-issue-title.txt
```

The helper does not sanitize raw records. It only formats the already-sanitized `methodology-feedback.md` and emits warnings for obvious privacy risks.

## Filing

After user confirmation:

```bash
gh issue create \
  --repo "${QEMU_METHODOLOGY_ISSUE_REPO:-processmission/oh-my-qemu}" \
  --title "$(cat build/agent/<task-slug>/scratch/methodology-issue-title.txt)" \
  --body-file build/agent/<task-slug>/scratch/methodology-issue.md
```

If `gh` is unavailable or unauthenticated, provide the draft path and issue text for manual filing.
