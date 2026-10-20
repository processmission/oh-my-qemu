# Review checklist

Use this checklist against one modeling round. For each row, record PASS, FAIL,
or N/A with evidence. Findings use BLOCKER/MAJOR/MINOR/NOTE and reference a
`file:line` or artifact path. Do not edit anything while reviewing.

## A. Goal contract, scope, and plan

- [ ] The overall goal is recorded as an observable end state, not an activity
      or a round count.
- [ ] The goal is decomposed into 2-5 milestones with exit conditions, and into
      falsifiable acceptance criteria that each name their evidence.
- [ ] Each round objective maps to at least one AC; a completed round is not
      treated as a completed goal.
- [ ] The diff matches the requested scope and current round objective; no
      unrelated changes.
- [ ] Acceptance criteria are testable and unchanged; any change is recorded in
      the decision log.
- [ ] Audit artifacts (audit.md, commands.md, logs, scripts, output) are outside
      the source diff.
- [ ] Pre-existing dirty paths are distinguished from task changes.
- [ ] Provenance intent is recorded (local-only, downstream/fork, or
      upstream-intent) and the work respects it.

## B. Evidence and provenance

- [ ] Each claimed fact has a source (path:line, manual page/section, trace).
- [ ] Reset values, access policy, masks, and side effects are cited, not
      remembered.
- [ ] User-supplied register/field premises were verified against the manual
      page and section.
- [ ] Inputs that affect the claim are hashed or recorded (QEMU build, image,
      DTB, firmware, kernel, rootfs).
- [ ] Conflicts and unknowns are visible; none were silently resolved.
- [ ] PASS/FAIL/INCONCLUSIVE is based on the configured marker or falsifiable
      test, not timeout/absence of crash.

## C. Register framework decision

- [ ] A framework decision record exists for every guest-visible control/status
      bank, with bank kind, decisive input, rationale, hybrid split, structural
      reason (if manual), accepted limits, and review gate.
- [ ] Control/status registers use RegisterInfo unless the record has a
      decisive policy/user direction or a same-subsystem, maintained,
      semantically comparable convention cited by file:line.
- [ ] Manual MMIO is limited to a structural command/FIFO/DMA/timing/reentrancy
      aperture, or to a hybrid split; "neighboring devices are manual", time,
      budget, and register count are rejected as rationale.
- [ ] Missing, vague, or contradictory decision records are BLOCKERs.

## D. RS-IR and translation

- [ ] RS-IR validates with the extraction skill's validator when available.
- [ ] Every rule has a mechanism (RegisterInfo, manual MMIO, helper) and a hook
      with a rationale.
- [ ] Guest-visible rules carry an `observe` trace/log policy; unimplemented or
      logging-only rules use `log=unimp` and a gap.
- [ ] Every unimplemented address has a board-level placeholder name and a
      source; no placeholder is counted as modeled behavior.
- [ ] The translation worklist matches the IR rules; no invented operations.
- [ ] Trigger/condition/transition order and read-versus-write side effects are
      implemented as the IR states.
- [ ] `EXPANDS` operations have an expansion note; `UNSUPPORTED` has a gap.

## E. Model implementation

- [ ] File headers are minimal (SPDX/copyright plus at most a one-line hardware
      identity). Source comments contain no design/framework rationale, "modeled
      contract" pointers, neighboring-convention defenses, `.oh-my-qemu/...`,
      `output/...`, `audit.md`, evidence paths, round/review IDs, or absolute
      host paths. A leak or rationale block is a BLOCKER.
- [ ] Register layout, field macros, storage, tables, and hooks live in the
      device `.c` file, not a header or board file.
- [ ] Framework choice follows the recorded decision gate and is justified.
- [ ] IRQ level/edge, clear/W1C, timer, FIFO, DMA, and exception paths match the
      contract; status updates happen before IRQ changes where ordering matters.
- [ ] Error paths: invalid guest access uses `LOG_GUEST_ERROR`; unimplemented
      paths use trace/`LOG_UNIMP`; internal invariant failures use
      `error_report`/assert; no silent sink fakes success.
- [ ] FIFO/data apertures use explicit `MemoryRegionOps`; reentrancy and block
      permission/capacity limits were considered when applicable.
- [ ] Guest-visible migratable state is in `VMStateDescription`; local caches
      are not.
- [ ] Board versus device ownership is respected (topology in board, behavior in
      device, placeholders at board level).

## F. Tests and runtime evidence

- [ ] qtests exercise the real offsets, widths, reset values, masks, W1C, IRQ,
      timer, and DMA behavior claimed by the rule.
- [ ] Tests are registered in `tests/qtest/meson.build` (or the correct test
      harness) and run from the named build directory.
- [ ] Boot/workload evidence uses the intended image and hashes, reaches a named
      marker, and states what it does not prove.
- [ ] Functional-test assets are hash-pinned and available; no stale local-only
      asset was assumed.
- [ ] Tests are within the requested scope; removed tests were removed cleanly.

## G. Audit, gates, and handoff

- [ ] `audit.md` has baseline, goal, scope, acceptance criteria, plan/gates,
      provenance, decisions, round record, evidence, unresolved gaps, handoff.
- [ ] `commands.md` records effective commands, working directories, and
      results; decisive logs are under `logs/`.
- [ ] A PASS round names a marker/qtest/test gate (not timeout/none) and its
      evidence path exists under the task packet without `..` escaping it.
- [ ] Excluded paths (`.agents/`, `.oh-my-qemu/`, `builds/`) are not staged or
      tracked; the worktree matches the recorded baseline.
- [ ] Round result has verdict, gate, evidence, changed paths, commands, and a
      concrete next blocker when not PASS.
- [ ] Goal completion is claimed only when every AC has evidence-backed PASS,
      every milestone is evidence-backed done, and no BLOCKER is unresolved;
      a round budget or round count is not accepted as completion. Final
      completion uses `review-checks.sh --final-goal`; intermediate rounds use
      the default contract check.
- [ ] The review packet includes previous findings and their status.

## H. Review quality

- [ ] The review is independent from the implementation pass when an independent
      context was available; otherwise this is stated.
- [ ] Every finding names a concrete failure mode and requested action, not a
      restatement of the round.
- [ ] Positive checks are listed (what was verified), not only the absence of
      findings.
- [ ] The verdict names what would change it (especially INCONCLUSIVE).

## Severity guide

- BLOCKER: correctness/policy/AC missed, failed gate, unjustified mechanism,
  hidden placeholder/logging sink, untraceable evidence.
- MAJOR: coverage or maintainability risk needing a fix or accepted deferral.
- MINOR: bounded cleanup that does not invalidate evidence.
- NOTE: follow-up observation with no current action.
