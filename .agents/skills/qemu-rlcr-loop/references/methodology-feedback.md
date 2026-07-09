# QEMU Methodology Feedback Record

Use this record at the end of a QEMU workflow to extract reusable workflow improvements without leaking project-specific details. It is modeled after Humanize methodology analysis, but the target is QEMU modeling and oh-my-qemu workflow improvement.

## Trigger Policy

Write methodology feedback only at terminal points:

- RLCR complete after final verification;
- user explicitly pauses or stops the workflow;
- the workflow is blocked and no meaningful progress remains;
- max iteration or review limit is reached;
- a `/goal` or multi-workflow composition reaches its final completion or final pause point.

Do not ask after every primitive or workflow step. For a composition such as kernel build, image packaging, firmware boot, debug, and verification, write at most one record after the composition has ended.

## Feedback Artifact

Write the sanitized report to:

```text
.oh-my-qemu/<task-slug>/methodology-feedback.md
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
- Follow-up issue: outside this primitive

## Sanitized Workflow Context

- Workflow type: <board modeling | peripheral modeling | firmware boot | direct boot | debug | packaging | mixed>
- Exit condition:
- Phases involved:

## Observed Patterns

## Improvement Suggestions

## Privacy Check

- [x] No private paths, repository paths, or local usernames.
- [x] No branch names, commit hashes, or git identifiers.
- [x] No proprietary logs, raw error messages, or stack traces.
- [x] No code snippets or code fragments.
- [x] No project-specific URLs, image paths, or endpoints.
- [x] No customer, product, board, or SoC identifiers unless explicitly approved.
```

If no reusable improvements are found, write `State: analyzed-no-suggestions` and keep the report brief.

## Follow-up Boundary

This record is input to later issue reporting, but issue drafting and GitHub
submission are outside this primitive. Do not run `gh`, file issues, or choose
follow-up workflow steps from inside RLCR.
