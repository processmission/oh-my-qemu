# Orchestration phase protocol

The orchestrator runs a bounded loop. Each phase has an entry condition, an exit
gate, and named artifacts; a phase does not advance on prose alone. Keep the
state in `output/task-state.md` and append rounds to `output/rounds.tsv`.

## Phase table

| Phase | Entry | Work | Exit gate |
| --- | --- | --- | --- |
| P0 Intake | user request or continuation | classify task, freeze scope/AC/provenance, read prior state | audit baseline written; scope, AC, stop condition, permitted actions recorded |
| P1 Evidence | P0 passed | read sources, extract register/board/firmware facts, record tiers/citations | contract and/or board contract exists; unknowns and conflicts visible |
| P2 IR and translation | P1 passed for register work | validate RS-IR, run `--translate`, map rules to mechanism/hook/observe/placeholder/qtest | every rule has mechanism+hook+qtest row; guest-visible observe; unimplemented placeholder; errors/trace/log considered |
| P3 Implementation | P2 passed | one narrow source round via the domain skill | requested source paths changed; audit/commands updated; no unrelated changes |
| P4 Build and test | P3 complete | named build, narrow qtest/boot marker/workload | gate result recorded with command and log path |
| P5 Debug | P4 failed or ambiguous | classify first suspect, narrow probe, use debug skill when available | failure class names the first suspect and next narrow check |
| P6 Independent review | P4/P5 produced round evidence | run qemu-model-review on the packet | review verdict and findings recorded; blockers listed |
| P7 Feedback and decision | P6 complete | apply blockers, re-review, capture reusable feedback, decide next round | next action recorded; PASS/FAIL/INCONCLUSIVE per AC; state updated |
| P8 Handoff | stop condition reached | summarize evidence, translation, review, gaps, next action | handoff report complete; no hidden blocker |

P0-P2 may be omitted only when the user explicitly asks for a narrow debug or a
single command task; record the omission and the reason.

## Routing

Choose the smallest set of skills that covers the object and its evidence:

| Task shape | Skills to load (when installed) |
| --- | --- |
| Board/SoC bring-up, memory map, boot policy | qemu-board-modeling, qemu-register-extraction (for register facts), qemu-qtest, qemu-boot-run |
| Peripheral/register model, MMIO, IRQ, FIFO, DMA | qemu-register-extraction, qemu-peripheral-modeling, qemu-qtest, qemu-model-verification |
| TCG guest decode or host backend | qemu-tcg-frontend or qemu-tcg-backend, qemu-qtest, qemu-debug |
| Firmware/U-Boot/Linux boot chain | qemu-uboot-build, qemu-kernel-build, qemu-image, qemu-linux-boot, qemu-boot-run |
| Build or image failure only | qemu-build or qemu-image, qemu-debug |
| Evidence judgment for an existing claim | qemu-model-verification, qemu-qtest |
| Documentation change | qemu-rst-documentation |
| Cross-cutting planning, gates, patch series | qemu-workflow |

Rules:

- A board model is topology and boot policy; device behavior belongs to a device
  skill. Do not let the board own register semantics.
- A peripheral model is behavior inside a window; the board owns the window,
  IRQ wiring, and the unimplemented placeholder.
- Unimplemented windows are board-level placeholders; they are not a substitute
  for a device model and must be visible (trace/`LOG_UNIMP`).
- Missing skill: record `missing skill: <name>` in `audit.md`, use the nearest
  available rule set, and list the gap in the review packet. Never pretend the
  skill was loaded.

## Round budget and replanning

- Default one objective per round. A round may touch several files only when
  they implement one coherent rule/feature.
- If verification fails for an environmental reason, fix the environment first
  and record it; do not change model source to compensate.
- If a round uncovers two independent blockers across stages or subsystems,
  stop, replan, and split the round. Do not accumulate an oversized round.
- Record the round budget before starting (for example "at most 3 rounds before
  a design checkpoint"). On reaching it, stop and report the state; do not
  silently continue.

## Failure and debug

Classify the first suspect before editing source:

1. wrong or stale input/image/DTB/firmware;
2. command, machine option, or boot ABI mismatch;
3. host/toolchain/build directory;
4. board topology or IRQ wiring;
5. device register/IRQ/timer/DMA semantics;
6. TCG frontend/backend;
7. guest/rootfs application issue.

Use qemu-debug for host/guest debugger, trace, replay, or crash intake. A debug
session is not PASS evidence by itself; return to P4 with a naming gate.

## Review cycle

1. Build the review packet: plan/AC, audit.md, diff, RS-IR and translation
   worklist, commands/logs, tests, and the round result.
2. Request an independent review with
   [the review request template](../assets/review-request-template.md) and
   qemu-model-review.
3. On BLOCKER findings: fix, add evidence, and re-review the changed scope.
   MAJOR findings need a documented decision (fix or defer); MINOR/NOTE may be
   deferred with a reason.
4. A PASS verdict requires the reviewer's positive statement on every acceptance
   criterion, not just the absence of findings.
5. The reviewer does not edit source. The orchestrator applies fixes and records
   the re-review.

## Stop and handoff

Stop when any of the following is true:

- all acceptance criteria have evidence-backed PASS;
- the user's requested scope is complete;
- a concrete external input/authority is missing (record it as blocked);
- the round budget or user stop signal is reached;
- continuing would violate the provenance boundary.

Handoff includes: task/build directories, AC status, translation mapping,
review verdict and findings, evidence paths, source changes, pre-existing
changes, policy limits, and unresolved gaps. A stop with INCONCLUSIVE must name
the missing evidence and the next narrow command.
