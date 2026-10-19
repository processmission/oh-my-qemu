---
# SPDX-FileCopyrightText: Copyright (c) 2026 Process Mission
# SPDX-License-Identifier: MIT
name: qemu-register-extraction
description: Use to extract a source-cited QEMU register and behavior contract from drivers, datasheets, firmware, device trees, runtime traces, and SVD, IP-XACT, SystemRDL, or vendor regfiles before modeling a hardware block.
---

# QEMU Register Extraction

Read [the register contract reference](references/register-contract.md) in
full. It defines the source inventory, required facts, confidence policy,
output schemas, projection schema, evidence tiers, and completion checklist.
Read [the register semantics IR reference](references/semantic-ir.md) when the
extraction must hand a machine-consumable contract to a model or test
generator; it defines the IR vocabulary and rule mapping.

Summarize proprietary or copyrighted sources and cite page, section, revision,
or source location; do not copy long passages.

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

## Extract the contract

1. **Bound the target.** Record the IP name and version, SoC or board variants,
   compatibility strings, register windows, endianness, access widths, IRQs,
   clocks, resets, power domains, DMA endpoints, and intended workload.
2. **Inventory sources.** Record the exact revision or document edition plus
   path, line, page, section, hash, or capture command for every driver,
   datasheet, firmware image, DTB, regfile, and runtime trace used.
3. **Cross-reference facts.** Tie each register or behavior to specific source
   locations. Treat generated headers and names as evidence, not authority.
4. **Extract semantics.** Capture offset, width, reset, access type, masks,
   reserved bits, valid access sizes, aliases, banking, read/write side effects,
   unsupported access behavior, and version differences.
5. **Extract feature flows.** Record initialization order, polling, IRQ and W1C
   paths, FIFO, timer, DMA, and descriptor behavior, unlock sequences, and every
   cross-register enable or completion dependency.
6. **Resolve evidence quality.** Mark each fact `HIGH`, `MEDIUM`, `LOW`, or
   `CONFLICT`. Never choose silently between disagreeing sources or invent a
   default for a gap; name the check that could resolve it.
7. **Record the framework decision.** For every guest-visible control/status
   register bank, apply target-workspace policy, compatible user direction, and
   a maintained nearby convention in that order, stopping at the first decisive
   input; select `RegisterInfo` or justified manual MMIO, defaulting to
   `RegisterInfo`. Record the decision with its inputs and rationale; the
   reference defines the schema. Keep register layout, storage, tables, and
   local hooks in the device `.c` file, not a header.
8. **Produce the handoff.** Write the human contract to
   `.oh-my-qemu/<task-slug>/output/register-contract.md` and the
   machine-consumable RS-IR to
   `.oh-my-qemu/<task-slug>/output/register-semantics.ir` from
   [the IR template](assets/register-semantics-template.ir); adapt
   [the worked example](assets/register-semantics-example.ir) with cited facts.
   The grammar and vocabulary are in
   [the semantic IR reference](references/semantic-ir.md); [ir-ops.def](assets/ir-ops.def)
   is the single op/flag table. Validate with
   [the IR validator](scripts/validate_register_ir.py); record the PASS result,
   use `--dump` for the audit record, and `--translate` for the QEMU
   RegisterInfo/unimplemented/trace worklist. Mark guest-visible rules with an
   `observe` line; mark board placeholders with
   `symbol address ... status=unimplemented placeholder=<name>`. Keep extraction
   scripts in `scripts/` and third-party artifacts in `output/`.

## Register-only evidence projection

Keep raw trace, execlog, QEMU `-d` output, GDB/RSP transcripts, and static
analysis at their original paths. Extract only register-shaped conclusions into
the human contract and the `.ir` symbols/rules. Cite provenance
(`path:line`, trace event, GDB command) without pasting non-register content.
This is a filter, not a log concatenator: if a source only proves an address
was touched, record an access observation and leave reset and side effects
unknown. The projection feeds both the contract and the IR; do not create a
separate JSON dump of raw evidence.

## Evidence rules

- Separate observed facts from inference and modeling suggestions.
- Cite source revision plus line, page, or section for every decisive fact.
- Follow driver call paths around writes; a scalar register can still trigger
  reset, DMA, IRQ, FIFO, timer, or command behavior.
- Model cross-register dependencies as named feature flows with required order,
  partial-state behavior, and a verification candidate.
- Preserve conflicts and unavailable sources as gaps.
- Classify facts by evidence tier: driver-defined fields (the driver's actual
  accesses), companion-test expectations (tests, validation, boot logs), and
  full hardware semantics (TRM or datasheet). Model at least the driver-defined
  tier; mark bare companion-test expectations and do not claim more coverage.
- Verify a user-supplied register or field premise against the cited manual page
  and section before modeling. If the premise is wrong (for example a reported
  I/O mode is 1-1-1, not 1-4-4), state the correction and use the valid
  configuration as the regression target.
- When `pdftotext` is absent, extract text with a Python PDF library available
  in the environment; record the tool, version, and command in `commands.md`,
  and verify the cited page.
- Do not include C implementation templates. The consumer must inspect the
  selected framework in the checked-out QEMU tree, including the current
  `RegisterInfo` API when that framework is selected.
- Do not suggest placing register definitions, backing storage, or semantics in
  a header. A header may expose only declarations required outside the device
  translation unit, such as a public QOM type or cross-unit helper prototype.

## Handoff

Report the target and variants, source inventory, contract and IR paths, IR
validation result, confidence and conflict summary, missing facts, qtest
candidates, and unresolved gaps. The extraction is incomplete if
software-touched registers lack access semantics, side effects, source
citations, or explicit unknowns.

## Upstream references

- QEMU code provenance: `docs/devel/code-provenance.rst`.
- `RegisterInfo` API when selected: `include/hw/core/register.h` and
  `include/hw/core/registerfields.h`.
- Framework implementation: `hw/core/register.c`.

Paths can differ between QEMU versions; locate them in the checked-out tree.
