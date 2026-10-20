# Peripheral modeling field lessons

Use this reference at planning and review time. The requirements below were
abstracted from captured QEMU agent sessions (Codex CLI/desktop, DeepSeek
Harness, legacy DeepSeek TUI, Claude Code), a remote firmware-reproduction
workspace, and review-comment adjustments. Names, paths, and customer details
are removed; the evidence stays in the task audit, not in this reference.

## Modeling requirements (PM)

| ID | Requirement | Anti-pattern it prevents |
| --- | --- | --- |
| PM-01 | Model the real hardware behavior; never add a convenience device (for example virtio) that the hardware does not have. | "It boots" models that do not match the physical device. |
| PM-02 | Every reset value, access policy, and side effect needs a cited source; verify user-supplied register/field premises against manual page and section before modeling. | Bits written from memory; a wrong premise becomes a false-positive qtest. |
| PM-03 | Record the register-bank framework decision (workspace policy -> compatible user direction -> maintained nearby convention -> RegisterInfo default) with inputs and rationale. | Framework choice with no evidence; manual MMIO treated as an automatic failure. |
| PM-04 | Use RegisterInfo for control/status banks when the gate selects it; keep layout, storage, tables, and hooks in the device `.c` file; use explicit MemoryRegionOps for FIFO/data apertures. | Register definitions in headers; FIFO behavior hidden in RegisterInfo arrays. |
| PM-05 | Keep unimplemented paths visible with trace events and `LOG_UNIMP`; use `LOG_GUEST_ERROR` for invalid guest access. | Silent zero-return sinks counted as modeled behavior. |
| PM-06 | Implement the error matrix: guest error vs unimplemented vs internal invariant vs host failure; never fake success to keep boot moving. | Fake ready bits; crashes or assertions used as normal control flow. |
| PM-07 | Give material transitions stable trace events; correlate them with qtest or runtime evidence. Trace counts alone are not correctness proof. | Logs that cannot be tied to a rule or a test. |
| PM-08 | A qtest proves only what it asserts: check the real offset, access width, reset, mask, W1C, IRQ, timer, and DMA effect. | A test reading the wrong address hides the model bug. |
| PM-09 | Block devices: exclude `BLK_PERM_RESIZE` when capacity is cached; respect 32-bit LBA capacity limits; verify against the checked-out tree. | Silent capacity divergence; oversized sparse backends. |
| PM-10 | DMA/descriptor models validate guest addresses, separate parsing from execution, and trace milestones; unknown descriptors stay visible. | Unchecked DMA ranges; skipped descriptor counts hidden. |
| PM-11 | Guest-visible migratable state belongs in `VMStateDescription`; local caches do not. | Migration drift or "works only before savevm". |
| PM-12 | Keep rule ids from the RS-IR in model comments, trace events, qtests, and documentation. | Contract, model, and test impossible to cross-check. |
| PM-13 | For a guest-visible control/status bank, RegisterInfo is the default; a nearby manual convention is decisive only when it is same-subsystem, maintained, semantically comparable, and cited by file:line. | Agents citing "hw/net mostly uses manual MMIO" or "many siblings are manual" to skip RegisterInfo. |
| PM-14 | Manual MMIO for a control/status bank needs a structural reason (command/FIFO/DMA/timing/reentrancy) that RegisterInfo hooks cannot express; prefer a hybrid split over whole-window manual. | Whole-window manual callbacks where a RegisterInfo bank plus a data aperture would be clearer. |
| PM-15 | The framework decision record must state bank kind, decisive input, rationale, structural reason, hybrid split, and accepted limits; missing/vague records are review BLOCKERs. | A one-line "manual MMIO justified" note accepted without evidence or review. |
| PM-16 | Source header/body comments describe hardware and public references only; never cite local task artifacts (`.oh-my-qemu/...`, `output/...`, `audit.md`, evidence paths, review IDs, host paths). | Evidence paths leaking into upstream-style source comments and stale task-local references. |
| PM-17 | Keep file headers minimal (SPDX/copyright plus at most a one-line hardware identity); body comments only on key code, 1-3 lines, at most one brief public source reference; never put implementation strategy, framework choice/defense, "modeled contract" pointers, or neighboring-convention rationale in source. | A .c header explaining "no policy in this tree; neighboring devices use manual style" instead of keeping the decision in the audit. |
| PM-18 | Generated source is not a work log: never record rounds, milestones, AC status, audit/review/finding notes, commands, evidence trails, session or task identifiers, or progress in source comments. | Source headers narrating "round 2 review passed", "M1 done", or "next blocker" that become stale immediately. |

## Review-comment adjustments (RV)

These are recurring adjustment patterns from review feedback; apply them to a
model, a patch, or a handoff:

| ID | Adjustment |
| --- | --- |
| RV-01 | Verify each reviewer claim against the checked-out code and QOM semantics with `file:line`; do not accept a claim because it is confident. |
| RV-02 | Classify a finding as pre-existing or introduced by the change set before fixing it; do not silently "fix" a pre-existing bug inside an unrelated change. |
| RV-03 | Reject unsupported debug surfaces (for example a `-global` override unreachable from normal machine/guest paths) as correctness evidence. |
| RV-04 | Re-derive expected values (status codes, markers, DTB properties, thresholds) from the same evidence class as the artifact; stale literals are a known false-negative source. |
| RV-05 | Keep patch-series adjustments (subject/body, split/order, DCO, checkpatch) in the workflow patch-series reference; do not mix commit hygiene into the device behavior record. |
| RV-06 | Tests are requested scope: add them when asked or required by acceptance criteria; when the user removes a requested test, remove it and its registration cleanly. |
| RV-07 | Report unexplained numeric differences (IRQ counts, register deltas, RMSE-like metrics) as explicit handoff gaps; do not hide them behind a summary. |
| RV-08 | Do not treat QEMU diagnostics on stderr or a debug log as guest serial output; console markers come from the serial chardev. |
| RV-09 | For documentation review, prefer the short sibling-page shape, drop out-of-tree repository links and local recipes, and document only implemented or explicitly limited behavior. |
| RV-10 | When a review asks for a narrow fix, do exactly that scope; do not fold in unrelated cleanups without recording the decision. |

## Use in the workflow

1. Before implementing, scan PM-01..PM-18 for the device class and record the
   applicable IDs in `audit.md`.
2. Translate the RS-IR rules with `ir-to-registerinfo.md` and map each rule to a
   mechanism, trace/log policy, and qtest.
3. During review, apply RV-01..RV-10 to reviewer claims and to your own evidence.
4. After a review round, update the translation record and the gap list; add a
   new PM/RV entry only when the requirement is reusable beyond the task.

## Boundaries

These are local modeling requirements, not upstream contribution guidance.
Never turn an entry into upstream-ready code, commit messages, or patches.
