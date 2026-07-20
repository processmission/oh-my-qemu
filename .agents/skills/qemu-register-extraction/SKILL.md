---
name: qemu-register-extraction
description: Use to extract a source-cited QEMU register and behavior contract from drivers, datasheets, firmware, device trees, runtime traces, and SVD, IP-XACT, SystemRDL, or vendor regfiles before modeling a hardware block.
---

# QEMU Register Extraction

Turn external hardware evidence into a markdown register/function contract. Do
not produce QEMU source code or fill undocumented behavior from memory.

## Audit workflow

For every non-trivial task that writes to the workspace, choose a stable task
slug and keep all agent-only records under `.oh-my-qemu/<task-slug>/`. Create
only the entries the task needs:

```text
.oh-my-qemu/<task-slug>/
├── audit.md      # Baseline, scope, decisions, evidence, verification, and gaps
├── commands.md   # Redacted commands, working directories, and results
├── logs/         # Decisive build, test, runtime, or diagnostic logs
├── scripts/      # Temporary scripts, probes, parsers, and harnesses
└── output/       # Generated deliverables, dependencies, and non-QEMU binaries
```

Before changing source or mutable artifacts, record the workspace root,
branch/revision, `git status --short`, user-owned dirty paths, goal, scope, and
acceptance checks in `audit.md`. Record exact redacted commands and results in
`commands.md`; record source revisions, configurations, tool versions, and
input/output hashes when they affect reproducibility. Separate observations
from inferences and create or change source files only when requested.

Put every QEMU build in a named directory under the QEMU source root, such as
`builds/build-aarch64/`. Put third-party dependency artifacts and non-QEMU
binaries under the task's `output/` directory. In a Git worktree, before
writing audit records or configuring QEMU, add `.agents/`, `.oh-my-qemu/`, and
`builds/` to the repository-local exclude file returned by
`git rev-parse --git-path info/exclude`; preserve existing entries and avoid
duplicates. Never stage or commit those directories. Before handoff, verify
that `git status --short` contains none of them, then report the task directory
and unresolved gaps.

## Research boundary

This skill is research and analysis only. Do not produce source, documentation,
commit messages, or patches intended for QEMU upstream submission. Summarize
proprietary or copyrighted sources and cite page, section, revision, or source
location; do not copy long passages.

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
7. **Produce the handoff.** Write the contract to
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
  checked-out QEMU registerinfo API before any local-only model experiment.

## Handoff

Report the target and variants covered, source inventory, contract path,
confidence/conflict summary, missing facts, qtest candidates, and unresolved
gaps. The extraction is incomplete if software-touched registers lack access
semantics, side effects, source citations, or explicit unknowns.

## Upstream references

- QEMU code provenance policy: `docs/devel/code-provenance.rst`.
- Registerinfo API to inspect in the checked-out tree:
  `include/hw/core/register.h`, `include/hw/core/registerfields.h`, and
  `hw/core/register.c`.
