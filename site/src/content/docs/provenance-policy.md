---
title: "Provenance and policy"
description: "How Oh My QEMU records source provenance, keeps artifacts isolated, and treats final-series signing as human-owned."
order: 2
category: "Policy"
---

Oh My QEMU is not a QEMU upstream contribution branch. It is a local workflow toolkit that helps humans and agents collect evidence and manage QEMU-related work safely.

## Artifact boundary

Every agent-created artifact belongs under:

```text
.oh-my-qemu/<task-slug>/
```

That includes plans, logs, traces, copied command lines, temporary scripts, review ledgers, source provenance, and final summaries.
When the QEMU tree is a Git worktree, the runtime records `.oh-my-qemu/` in the
checkout's local `.git/info/exclude`.

## Git boundary

Reviewed source-changing rounds may create local checkpoint commits. These checkpoints are local workflow artifacts:

- do not push them;
- do not describe them as upstream-ready;
- do not add DCO or review trailers to them.

## Final series boundary

After the reviewer returns `COMPLETE`, Oh My QEMU can draft a human-owned final QEMU-style patch series. The draft can include suggested `Signed-off-by:` trailers and, when explicitly enabled by policy or maintainer exception, proposed `AI-used-for:` scope-disclosure trailers.

The workflow does not sign, rewrite history, format patches, or send email on behalf of the human.
