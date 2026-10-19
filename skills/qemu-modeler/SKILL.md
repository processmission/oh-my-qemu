---
# SPDX-FileCopyrightText: Copyright (c) 2026 Process Mission
# SPDX-License-Identifier: MIT
name: qemu-modeler
description: Use when starting or resuming an end-to-end QEMU device, board, SoC, or firmware modeling task; it orchestrates planning, evidence extraction, RS-IR translation, domain-skill execution, debugging, independent review, feedback capture, and the next round until the task stops.
---

# QEMU Modeler

This is the top-level entry for a complete modeling task. It does not replace the
domain skills: it decides which of them to load, in what order, what each must
produce, and when a round may advance. Use it when the user says "model this
device/board", "bring this machine up", "continue the modeling", or "run the next
round", rather than invoking one domain skill in isolation.

Read [the phase protocol](references/phase-protocol.md) and
[the round loop](references/round-loop.md) in full before starting. Create the
task state from [the state template](assets/task-state-template.md) and keep it
current with [loop-state.sh](scripts/loop-state.sh).

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

## Start or resume

1. **Classify and freeze the task.** Record the task type (board/SoC bring-up,
   peripheral/register model, TCG, firmware chain, image/rootfs, debug-only,
   documentation), the provenance intent (local-only, downstream/fork, or
   upstream-intent), allowed paths, acceptance criteria, and the stop condition
   in `audit.md`. If the task is a continuation, read the previous
   `output/task-state.md`, the last `round-result.md`, and the unresolved gaps
   before planning.
2. **Create the state file.** Copy
   [the state template](assets/task-state-template.md) to
   `.oh-my-qemu/<task-slug>/output/task-state.md`, or run
   `bash <skill-dir>/scripts/loop-state.sh init .oh-my-qemu/<task-slug>`.
3. **Route.** Choose the smallest set of domain skills from
   [the routing table](references/phase-protocol.md#routing). Load them when
   available. If a named or required skill is not installed, record
   `missing skill: <name>` in `audit.md` and continue with the nearest
   available rules; never improvise a skill's rules or claim it was used.
4. **Plan the closed loop.** Write the current objective, the round's verification
   gate, the expected evidence, and the review request in `audit.md`. One round
   advances one coherent objective; do not fold unrelated fixes into it.

## Phase protocol

Run the phases in [phase-protocol.md](references/phase-protocol.md):

1. **Evidence and contract.** Before modeling, obtain the source-cited register
   contract and, when the handoff is structural, the RS-IR. For a board, obtain
   the memory map, boot contract, unimplemented-window plan, and image inputs.
   Use `qemu-register-extraction` for register semantics and those domain skills
   when installed; otherwise record the evidence gap.
2. **Translation.** Validate the RS-IR, run its `--translate` worklist, and turn
   it into the implementation map: RegisterInfo/manual-MMIO mechanism, hook,
   unimplemented placeholder, trace/log/error policy, and qtest. Read
   `qemu-peripheral-modeling`'s translation reference and
   `qemu-board-modeling`'s unimplemented-device reference when available.
3. **Implement.** Execute the domain skill for the object (peripheral, board,
   TCG, image, firmware chain) with one narrow round. Keep source changes to the
   requested deliverable; keep artifacts in the audit workspace.
4. **Build and test.** Use the named build directory and the narrowest gate:
   targeted build, qtest, boot marker, then workload evidence. Capture decisive
   logs under `logs/`.
5. **Debug.** When a gate fails, classify first (environment, stale input,
   command/ABI, topology, device semantics, TCG, guest) and use `qemu-debug`
   when installed. Do not edit the model to mask a wrong command, image, or host
   issue.
6. **Independent review.** Invoke `qemu-model-review` on the round packet
   (plan, diff, RS-IR/translation, tests, logs) using
   [the review request template](assets/review-request-template.md). Treat its
   findings as blocking when BLOCKER, and record a re-review after fixes.
   Self-review alone is not sufficient for a PASS.
7. **Feedback and next round.** Record reusable workflow friction; use
   `qemu-agent-feedback` for a sanitized proposal only when the user requests or
   approves filing. Decide the next action: continue, narrow a probe, replan, or
   stop.
8. **Hand off.** Report PASS/FAIL/INCONCLUSIVE per acceptance criterion, evidence
   paths, the translation/review state, remaining gaps, and the exact next action.

## Hard rules

- Do not claim PASS without a configured marker or a falsifiable qtest; a timeout,
  an empty serial log, or "no crash" is INCONCLUSIVE.
- Do not count a logging sink, an unimplemented placeholder, or a boot banner as
  modeled behavior.
- One round, one objective; a failed gate stays in the current round, but a
  multi-stage blocker triggers a replan instead of an oversized round.
- Run the review before advancing a round. A reviewer that only restates the
  round summary is not a review.
- Keep the state file append-only for rounds and findings; preserve the previous
  `round-result.md` and `commands.md` history.
- Respect the provenance boundary: local-only work never becomes upstream-ready
  by accident, and no upstream submission is prepared here.

## State and gates

- `output/task-state.md`: phase, round, objective, gate, blockers, next action,
  skills used and missing.
- `output/rounds.tsv`: append-only round log written by `loop-state.sh`.
- `output/round-result.md` and `output/evidence-manifest.tsv`: round evidence.
- If `qemu-workflow` is installed, also run its `scripts/gates.sh` workspace,
  audit-sections, round-result, marker, and handoff gates. If it is not
  installed, run `bash <skill-dir>/scripts/loop-state.sh show` and the review
  checks, and record the gate gap.

## Stop conditions

Stop and hand off when: the acceptance criteria are met with evidence; the
user's requested scope is complete; the task is blocked by missing external
input/authority; the round budget or user stop signal is reached; or the next
step would violate the policy boundary. A stop with INCONCLUSIVE is valid only
when it names the missing evidence and the next narrow command.

## Upstream references

- QEMU code provenance: `docs/devel/code-provenance.rst`.
- QEMU testing: `docs/devel/testing/main.rst` and `docs/devel/testing/qtest.rst`.
- Tracing: `docs/devel/tracing.rst`.
- GDB and replay: `docs/system/gdb.rst`, `docs/system/replay.rst`.

Paths can differ between QEMU versions; locate them in the checked-out tree.
