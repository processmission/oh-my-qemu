# QEMU claim review and divergence localization

Use when a review finding, bug report, or model claim must be verified before
it drives a change. Placeholders use <...>.

## Claim intake

- Restate the claim as one falsifiable sentence and keep the reviewer's cited
  evidence next to it.
- Record source, date, tree revision, and whether the reviewer is human or
  agent.
- Name the evidence class that can settle it: static code, qtest, trace, boot,
  measurement, or numeric comparison.
- If the claim cannot be falsified as stated, rewrite it or return
  INCONCLUSIVE.

## Verify against code and QOM semantics

- Locate the claim in the checked-out tree and cite `file:line` with the
  revision.
- Read the property definition (`DEFINE_PROP_*`), the realize/init path, and
  every path that can set or reach the value.
- Check QOM reachability: can a normal machine, device, or guest reach this
  state? A debug-only default, a `-global` override, or a monitor write is
  not proof of supported behavior unless the claim is about that surface.
- Reproduce with the narrowest command. If reproduction needs an unsupported
  surface, say so and treat the claim as unproven.
- Try to refute as well as confirm: state what would falsify the claim and
  check it.

A checked-out pattern: a device property declared with
`DEFINE_PROP_UINT8(..., 2)` and overridden with `-global` for one run shows
only that the property can be overridden, not that a machine or guest reaches
that value. Reject it as evidence of a supported configuration unless normal
paths reach it.

## Classify pre-existing versus introduced

- Identify the files and hunks the change set touched.
- Reproduce on the baseline (or with the series reverted in a separate
  worktree) when available; otherwise record the missing baseline as a gap.
- Classify each finding: pre-existing, introduced by the series, pre-existing
  but newly exposed by the series, or unproven.
- Record the evidence for the classification, not only the label.

## Expected-value provenance

- Derive every expected value from the register contract, the manual page and
  section, the model source, or a checked-in test.
- Record the source and revision next to the expectation.
- Re-derive expectations when the model, image, or test changes.
- A mismatch becomes a model claim only after the expected value is verified;
  a stale literal is a known false-negative source.

## Input provenance

- Hash the QEMU binary/build directory, images, DTB, and machine options used
  by the claim.
- Check the device-tree properties the claim depends on before running (MSI:
  `msi-parent` and an ITS node; timers: clock properties and controller
  phandles).
- A stale DTB is a known false negative: rebuild it from the same tree as the
  kernel and model, or compare its hash with the recorded one.
- Record how the inputs can be re-created.

## First numerical divergence

1. Define dataflow slices in order: input capture, decode, intermediate state,
   output.
2. Compare each slice's model output against a reference (hardware trace,
   golden model, specification, or driver behavior) on identical inputs.
3. Stop at the first slice that differs and capture trace events, GDB
   register/memory state, and the exact input.
4. Re-run that slice with one variable changed to confirm causality.
5. Check the address space before declaring a bug: a model may present a
   linear view while hardware banks memory (for example separate DDR and
   global banks). Treat that as a model limitation or handoff gap.
6. Report unresolved numeric differences (for example 93 versus 96 MSI
   notifications) with counts, commands, and what would explain them. Do not
   round, average, or hide them.

## Review record

Fill one [claim record template](../assets/claim-record-template.md) per claim;
the block below is the minimum shape.

```text
Claim: <one falsifiable sentence>
Reviewer evidence: <source, date, revision>
Verification: <command, file:line, trace>
Classification: pre-existing | introduced | newly exposed | unproven
Verdict: PASS | FAIL | INCONCLUSIVE
Artifacts: <paths under .oh-my-qemu/<task-slug>/>
Gap: <what remains unexplained>
```

Unexplained numeric differences and missing baselines become handoff gaps;
record them in `audit.md` and state the next narrow check.
