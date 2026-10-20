---
# SPDX-FileCopyrightText: Copyright (c) 2026 Process Mission
# SPDX-License-Identifier: MIT
name: qemu-peripheral-modeling
description: Use for QEMU peripheral, accelerator, MMIO, qdev, or SysBusDevice modeling with register contracts, an explicit register framework decision, and qtest-backed verification.
---

# QEMU Peripheral Modeling

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

## Workflow

1. Freeze the register, IRQ, DMA, reset, migration, and allowed-path contract.
2. When facts come from drivers, datasheets, or regfiles, extract a source-cited
   register contract first; do not fill gaps from memory.
3. Work in small source-change rounds; record paths, verification, and gaps.
4. Build the affected target and map each modeled behavior to focused qtests.
5. Use traces or workload evidence for integration claims and state what remains unproven.

## QEMU upstream boundary

QEMU's official GitLab and mailing lists are upstream channels. A patch becomes an upstream
contribution when it is sent to the maintainers selected through `MAINTAINERS`. Do not prepare or
send agent-generated code, documentation, commit messages, or patches for upstream submission; see
the checked-out tree's `docs/devel/code-provenance.rst`. Research, debugging, analysis, local
experiments, verification, and workflow guidance remain allowed. Local branches, commits, patch
files, pushes, and pull requests are not by themselves upstream contributions; perform those Git
actions only when requested.

## Device modeling contract

A real hardware block should be a first-class device: board code wires topology,
device code owns behavior. Define in `audit.md` before modeling:

- MMIO windows, endianness, and accepted access widths;
- reset, masks, W1C, aliases, reserved bits, and cross-register flows;
- IRQ outputs and level/edge semantics; clock, reset, DMA, and bus dependencies;
  migration-visible state versus local caches;
- the unimplemented boundary and its visibility mechanism; reference evidence:
  datasheet, SDK driver, firmware trace, sibling device.

When the source of truth is external to QEMU, require the source-cited register
contract; never model from memory or a partial driver skim. Once the RS-IR
validates, read [the translation reference](references/ir-to-registerinfo.md)
before writing code and [the field lessons](references/field-lessons.md) at plan
and review time.

## QEMU object shape

Default shape when the framework decision and nearby code do not select
otherwise: `SysBusDevice` or the subsystem base class; one owned `MemoryRegion`
per window plus explicit `MemoryRegionOps` for a FIFO or data aperture; explicit
`qemu_irq` outputs; local-style realize and reset hooks; `VMStateDescription` for
guest-visible state; named properties only for real variation; do not put
register side effects in board files.

## Register bank framework decision

Before designing a guest-visible control/status register bank, apply in order
and stop at the first decisive input:

1. policy present in the target QEMU workspace;
2. the user's explicit compatible framework direction;
3. a clear maintained convention in a nearby device of the same subsystem.

`RegisterInfo` is the default for every guest-visible control/status bank.
A nearby manual convention alone is not decisive: it must be the same
subsystem, actively maintained, and semantically comparable, with a cited
`file:line`. Manual MMIO for a control/status bank is exceptional and needs a
structural reason (command, FIFO, DMA, timing, or reentrancy behavior that
`RegisterInfo` cannot express without distortion); use a hybrid split
(control/status on RegisterInfo, aperture on MemoryRegionOps) rather than
manual for the whole window. Time/budget/register count and "most siblings are
manual" are invalid reasons.

Record bank kind, inputs, choice, hybrid split, rationale, structural reason,
accepted limits, and review gate in
`.oh-my-qemu/<task-slug>/output/framework-decision.md` with
[the framework decision template](assets/framework-decision-template.md); the
decision schema, API inspection steps, reference families, and `.c` placement
rules are in [the register framework reference](references/register-framework.md).
A missing, vague, or unsupported decision is a review BLOCKER. Keep register
layout, storage, tables, and hooks in the device `.c` file. Run
[check-framework-decision.sh](scripts/check-framework-decision.sh) on the
record before review; it rejects placeholders and manual rationales that name
nearby convention or schedule instead of a structural limit.

When qemu-register-extraction hands off the RS-IR `output/register-semantics.ir`,
read the framework reference for the trigger/hook/operation mapping and preserve
rule ids in comments, trace names, and qtests. The vocabulary is that skill's
`assets/ir-ops.def`; do not invent operations outside it.

## Source comment hygiene

Source headers and body comments describe hardware behavior and cite public
evidence only: datasheet/TRM section, vendor HAL path, checked-in QEMU docs, or
a stable public reference. Never write local task artifacts into source:
`.oh-my-qemu/...`, `output/...` (including register contracts, model notes,
framework decisions), `audit.md`, evidence paths, round/review IDs, or absolute
host paths. Keep that provenance in `audit.md` and `output/`; the source must
stand on its own and remain reviewable outside the local workspace.

When `qemu-workflow` is installed, run
`bash <qemu-workflow-dir>/scripts/gates.sh source-comments <changed-source-files...>`
before review. A source diff that leaks local task paths into comments is a
review blocker.

## Unimplemented visibility

- Every intentionally unimplemented guest-visible path must emit a trace event
  or `qemu_log_mask(LOG_UNIMP, ...)`; invalid accesses use `LOG_GUEST_ERROR` so
  they appear under `-d guest_errors`. Keep both mechanisms in the model and
  record the reachable addresses in `audit.md`.
- A diagnostic sink that logs and returns zero or fake status is a placeholder,
  not modeled behavior; never count it as PASS evidence or qtest coverage.

## MMIO rules

- Implement every control/status register through the selected framework; use
  constants or macros for offsets, masks, shifts, reset values, and IDs.
- Keep callbacks allocation-free and long-running work out of them; use timers,
  bottom halves, workers, or staged execution.
- Represent RO, W1C, reserved, clear-on-read, and unimplemented bits without
  duplicating semantics across callbacks; update status before IRQ changes.
- Validate guest DMA addresses with QEMU address-space or DMA helpers; never
  edit generated files under `builds/build-<target>/`.
- With `RegisterInfo`, use pre-write hooks to filter or transform writes,
  post-write hooks for IRQ/status/timer/DMA effects, and post-read hooks only
  for guest-visible effects; callbacks must be reset-safe.

Known limits (leaf `MemoryRegion` ownership and reentrancy, FIFO apertures,
block permissions and cached capacity, 32-bit LBA) are summarized in
[the register framework reference](references/register-framework.md).

## qtest expectations

Every material peripheral change needs narrow qtest coverage: reset values;
read/write masks, reserved bits, and unsupported widths; W1C and status-clear
behavior; IRQ assert and deassert; framework reset and side-effect callbacks;
unimplemented-path logging; timer virtual-clock behavior; DMA effects. Map each
semantic-IR condition and transition to one assertion; see
[modeling patterns](references/patterns.md).

## Accelerator addendum

For command-stream or accelerator blocks: separate descriptor parsing from
execution; record command ranges, DMA windows, and output buffers; validate
skipped or unknown counts; correlate trace milestones with guest-visible
output; record image hashes in `audit.md`.

## Anti-patterns

- Generic scratch register banks for real devices, or a framework choice
  without a complete decision record.
- Manual MMIO for a control/status bank justified only by neighboring devices,
  schedule, or register count; a hybrid split was possible but skipped.
- Fake success paths that only make firmware boot; board behavior hidden in
  MMIO callbacks.
- Register definitions, storage, tables, or hooks in a header; trace-count-only
  success claims.

## Upstream references

- QEMU code provenance: `docs/devel/code-provenance.rst`.
- QOM/qdev: `docs/devel/qom.rst`; tracing: `docs/devel/tracing.rst`.
- QEMU qtest: `docs/devel/testing/qtest.rst`.
- RegisterInfo API: `include/hw/core/register.h` and
  `include/hw/core/registerfields.h`.

Paths can differ between QEMU versions; locate them in the checked-out tree.
