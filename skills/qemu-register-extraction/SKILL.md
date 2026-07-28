---
# SPDX-FileCopyrightText: Copyright (c) 2026 Process Mission
# SPDX-License-Identifier: MIT
name: qemu-register-extraction
description: Use to extract a source-cited QEMU register and behavior contract from drivers, datasheets, firmware, device trees, runtime traces, and SVD, IP-XACT, SystemRDL, or vendor regfiles before modeling a hardware block.
---

# QEMU Register Extraction

## Audit workflow

For non-trivial workspace writes, use a stable
`.oh-my-qemu/<task-slug>/` directory and create only needed entries:

```text
.oh-my-qemu/<task-slug>/
├── audit.md      # Baseline, scope, decisions, evidence, verification, and gaps
├── commands.md   # Redacted commands, working directories, and results
├── logs/         # Decisive build, test, runtime, or diagnostic logs
├── scripts/      # Temporary scripts, probes, parsers, and harnesses
└── output/       # Generated deliverables, dependencies, and non-QEMU binaries
```

Before changing source or mutable artifacts, record the workspace root,
revision, `git status --short`, pre-existing changes, goal, scope, and
acceptance checks in `audit.md`. Log exact redacted commands and results in
`commands.md`; record revisions, configurations, tool versions, and hashes when
they affect reproducibility. Separate observations from inferences and edit
source only when requested.

Keep QEMU builds under source-root `builds/build-<target>/`; put third-party
dependencies and non-QEMU binaries in task `output/`. Before writing audit
artifacts or configuring QEMU in a Git worktree, add `.agents/`,
`.oh-my-qemu/`, and `builds/` to the repository-local file from
`git rev-parse --git-path info/exclude`; preserve existing entries and avoid
duplicates. Never stage or commit those directories. At handoff, verify them
absent from `git status --short`. Report the task directory and unresolved gaps.

## QEMU upstream and research boundary

QEMU's official GitLab and mailing lists are upstream project channels. A
patch becomes an upstream contribution when sent to the mailing-list recipients
selected through `MAINTAINERS`; do not prepare or send agent-generated patches
for that submission. Local branches, commits, patch files, pushes, and pull
requests are not by themselves QEMU upstream contributions. Perform those Git
actions only when requested and follow the workspace's Git policy.

Summarize proprietary or copyrighted sources and cite page, section, revision,
or source location; do not copy long passages.

Before extracting, read
[the register contract reference](references/register-contract.md) in full. It
defines the source inventory, required facts, confidence policy, detailed
output schema, and completion checklist.

## Extract the contract

1. **Bound the target.** Record the IP name/version, SoC or board variants,
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
   paths, FIFO/timer/DMA/descriptor behavior, unlock sequences, and every
   cross-register enable or completion dependency.
6. **Resolve evidence quality.** Mark each fact `HIGH`, `MEDIUM`, `LOW`, or
   `CONFLICT`. Never choose silently between disagreeing sources or invent a
   default for a gap; name the check that could resolve it.
7. **Record the framework decision.** For every guest-visible control/status
   register bank, record policy present in the target QEMU workspace, explicit
   user direction, and a clear maintained nearby subsystem convention. Apply
   them in that order, stopping at the first decisive input. Select
   `RegisterInfo` or justified manual MMIO callbacks; use `RegisterInfo` when
   none decides. Keep register offsets, field macros, backing storage, framework
   tables, and register-local hooks in the device `.c` file, not a header.
8. **Produce the handoff.** Write the contract to
   `.oh-my-qemu/<task-slug>/output/register-contract.md`, with source-cited
   qtest candidates and explicit unknowns. Keep extraction/conversion scripts
   in `scripts/` and copied or generated third-party artifacts in `output/`.

## Evidence rules

- Separate observed facts from inference and modeling suggestions.
- Cite source revision plus line/page/section for every decisive field or
  sequence.
- Follow driver call paths around writes; a scalar register can still trigger
  reset, DMA, IRQ, FIFO, timer, or command behavior.
- Model cross-register dependencies as named feature flows with required order,
  partial-state behavior, and a verification candidate.
- Preserve conflicts and unavailable sources as gaps.
- Do not include C implementation templates. The consumer must inspect the
  selected framework in the checked-out QEMU tree before any local-only model
  experiment, including the current `RegisterInfo` API when that framework is
  selected.
- Do not suggest placing register definitions, backing storage, or semantics in
  a header. Headers may expose only non-register-layout declarations genuinely
  required outside the device translation unit, such as a public QOM type or a
  cross-unit helper prototype.

## Handoff

Report the target and variants covered, source inventory, contract path,
confidence/conflict summary, missing facts, qtest candidates, and unresolved
gaps. The extraction is incomplete if software-touched registers lack access
semantics, side effects, source citations, or explicit unknowns.

## Upstream references

- QEMU code provenance policy: `docs/devel/code-provenance.rst`.
- `RegisterInfo` API to inspect when selected:
  `include/hw/core/register.h`, `include/hw/core/registerfields.h`, and
  `hw/core/register.c`.
