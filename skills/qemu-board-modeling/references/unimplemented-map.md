# Unimplemented map policy

Use this reference whenever a board or SoC needs an unimplemented-device map.
The map is a reviewed list of guest-reachable windows that are deliberately not
modeled yet. It is not a place to hide missing behavior, and it is not evidence
that behavior is modeled.

## Derive the map from an authoritative memory map

- Use the checked-out tree, TRM, or board documentation as the source of base,
  size, and names. Record document title, edition or date, page, and section for
  every window in `.oh-my-qemu/<task-slug>/audit.md`.
- Do not invent windows from a rough family name; a base address and size need a
  cited source.
- Prefer names that already appear in upstream device trees, drivers, or public
  hardware documentation over vendor-only table wording.
- Keep the table next to the board or SoC source that owns it, not inside a
  test, script, or audit file.

## Minimal initial set and growth order

Add the map in this order and stop when the current workload needs the next
step:

1. SoC skeleton with CPU container, RAM/ROM, and basic bus wiring;
2. unimplemented map for the reachable windows;
3. interrupt controller;
4. boot-critical devices (clock/reset, UART, timer, flash controller);
5. board wiring and board-only windows;
6. optional devices.

Adding optional devices before the CPU, timer, IRQ, and boot spine are proven
produces noisy boots and hides the first real failure.

## Table shape and ownership

Use one row per window:

| Name | Base | Size | Owner | IRQ | Type | Status | Source |
| --- | --- | --- | --- | --- | --- | --- | --- |

- `Status` distinguishes `unimplemented` from `modeled`; move a window to
  `modeled` in the same change that implements it.
- Keep SoC windows in the SoC list and board-only hardware in the board list;
  never duplicate one window at both layers.
- Name a placeholder after the hardware block when the name is public, and after
  its address range otherwise; avoid invented marketing names.

## Classify exclusions instead of deleting evidence

Record why a window is not modeled:

- covered by another model (for example a clock/reset controller model covers
  its own register window);
- firmware-only (for example DDR training) with no guest-visible semantics in
  the tested workload;
- secure-only when the tested guest runs non-secure;
- on-chip memory already modeled as RAM or ROM;
- window outside the machine's documented address map.

An excluded window with an unexplained owner is a gap, not an exclusion.

## Compress numbered instances carefully

When many instances share one size and access pattern, group them so the table
stays readable: a range plus instance count, or a generator loop with exact
bases. Never merge windows with different sizes, ownership, or security state,
and keep address gaps visible. State the compression in a comment so a reviewer
can expand the list mechanically.

## Measure guest-touched windows before shrinking

- Boot both supported paths with `-d unimp,guest_errors` and keep the log under
  `.oh-my-qemu/<task-slug>/logs/`.
- Cross-check the touched addresses against `info mtree` and the memory map.
- Record measured counts in `audit.md`, for example windows touched versus
  windows listed, and the workloads that produced them.
- Shrink only windows that the tested workloads did not touch. A window can be
  unreached because the workload is incomplete, not because the hardware is
  absent.

## Copyright and public-IP caution

- Summarize register and window tables; do not paste long TRM passages or
  complete vendor tables into QEMU source or the audit.
- Prefer information already published in upstream device trees, Linux
  drivers, or open documentation; note when a name or address is only in a
  vendor document.
- If the license or redistribution status of a source is unclear, ask before
  copying structured tables; record the limitation as an open gap.

## A diagnostic sink is not modeled behavior

An unimplemented region that logs accesses and returns zeros, or that fakes a
status value so firmware continues, is a placeholder. It must stay visible in
the trace or `LOG_UNIMP` output, and it must never be counted as modeled
behavior or as PASS evidence. Firmware polling a faked ready bit is a known
false-positive pattern.

## Verification and review

- qtests probe modeled windows and register semantics; the unimplemented map is
  reviewed from boot traces, not by asserting that reads return zero.
- Re-run the touched-window measurement after adding devices or changing the
  firmware or kernel; the map is a snapshot of tested reachability.
- Record the table with
  [the unimplemented-map CSV template](../assets/unimplemented-map-template.csv); keep the
  provenance columns filled for every window.
- Handoff lists the map path, source citations, exclusions, and the measured
  touched windows.
