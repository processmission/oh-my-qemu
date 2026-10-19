# Issue template

Use this shape for `output/methodology-issue.md`. Keep every section; write "not
available" or "unknown" instead of dropping one. Fill it with summary-level evidence only,
and run the skill's sanitization table over the final text before presenting it.

## Summary

One or two sentences: the reusable workflow problem and the affected skill or step.

## Sanitized context

Where the problem appeared: skill name, task phase (planning, modeling, build, boot,
verification, docs), and the kind of session. No paths, hostnames, identities, or
proprietary targets.

## Problem observed

What the installed skill led the agent to do, stated behaviorally. Distinguish what the
skill said or omitted from what the agent then did.

## Expected behavior

The rule or step that should have prevented the problem, in imperative form.

## Impact

What the gap costs: repeated user corrections, a wasted round, a false PASS, or similar.
Quantify only when the number is safe to disclose.

## Suggested improvement

A concrete change to one skill or reference: the section to add or edit, its trigger
conditions, and its negative boundaries. It must be implementable without private context.

## Reproduction shape

Ordered, sanitized steps: prompt class, skill loaded or missing, observed behavior. Do not
include private commands, artifacts, or log excerpts.

## Privacy check

- [ ] No local paths, hostnames, machine IDs, or user identities.
- [ ] No git author identity, email, or Signed-off-by line.
- [ ] No private repository, branch, commit, or tree identifiers.
- [ ] No URLs, endpoints, credentials, or tokens.
- [ ] No proprietary artifacts, SDKs, images, kernels, or root filesystems.
- [ ] No build, source-root, task, or audit paths.
- [ ] No unapproved customer, product, board, or SoC names.
- [ ] No raw logs, stack traces, commands, or code.
- [ ] Title and body disclose only summary-level behavior.
