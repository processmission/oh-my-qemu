---
# SPDX-FileCopyrightText: Copyright (c) 2026 Process Mission
# SPDX-License-Identifier: MIT
name: qemu-tcg-frontend
description: Use for adding, reviewing, or debugging guest ISA decode and translation in a QEMU TCG frontend, including feature gates, exceptions, PC/TB behavior, and focused instruction tests.
---

# QEMU TCG Frontend Instruction

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

## Workflow

1. Record the ISA version, encoding, operands, feature/privilege gates,
   exception behavior, PC/TB rules, and allowed source paths.
2. Inspect the checked-out decoder and nearby translations before choosing
   decodetree, direct TCG ops, or a helper.
3. Work in small reviewable rounds and record changed paths, verification,
   review result, and gaps in `audit.md`.
4. Build the affected target and run focused valid, invalid, and disabled-
   feature instruction tests.
5. Capture bounded TCG logs only when needed and distinguish native translated
   behavior from fallback or helper behavior.

## QEMU upstream boundary

QEMU's official GitLab and mailing lists are upstream project channels. A
patch becomes an upstream contribution when sent to the mailing-list recipients
selected through `MAINTAINERS`; do not prepare or send agent-generated patches
for that submission. Local branches, commits, patch files, pushes, and pull
requests are not by themselves QEMU upstream contributions. Perform those Git
actions only when requested and follow the workspace's Git policy.

## Frontend contract

Record in `audit.md`:

- ISA extension/version and privilege requirements;
- instruction encoding and aliases;
- operand fields and sign/zero extension;
- XLEN/vector/FPU state constraints;
- expected illegal-instruction cases;
- helper vs direct TCG-op decision;
- tests that prove semantics and invalid encodings.

## Decoder rules

For decodetree targets:

- reuse existing fields, formats, and argument sets;
- confirm fixedmask/fixedbits uniqueness;
- handle overlap groups intentionally;
- use field functions for transformed immediates;
- keep decoder ordering consistent with nearby extensions.

For hand decoders, preserve existing fallback and illegal-instruction behavior.

## `trans_*` rules

Before emitting IR, gate:

- CPU/ISA feature;
- privilege/virtualization mode;
- XLEN/operand width;
- reserved bits and invalid immediates;
- vector/FPU state where relevant;
- alignment or memory-mode constraints if architectural.

Use direct TCG ops for simple integer/logical/shift/select operations. Use helpers for complex state, softfloat/crypto/vector libraries, or exception-heavy semantics.

Helper calls must use correct side-effect flags. Do not mark a helper no-side-effects if it can raise or mutate CPU state.

## PC and TB rules

Check target conventions for:

- `pc_next` advancement;
- PC update before exceptions;
- branch/direct-block chaining;
- `ctx->base.is_jmp` state;
- page-boundary behavior;
- single-step and interrupt trigger behavior.

Wrong PC state corrupts exceptions, gdbstub state, and replay/debug evidence.

## Verification expectations

- Build the target translator.
- Add/run focused `tests/tcg/<target>/` coverage when applicable.
- Cover edge values, invalid encodings, feature-disabled behavior, and privilege errors.
- Use `-accel tcg,one-insn-per-tb=on` when debugging instruction boundaries.
- Store TCG logs under `.oh-my-qemu/<task-slug>/logs/`.

## Upstream references

- QEMU code provenance and AI policy: `docs/devel/code-provenance.rst`.
- Decodetree: `docs/devel/decodetree.rst`.
- TCG internals: `docs/devel/tcg.rst`.
- TCG IR/helper semantics: `docs/devel/tcg-ops.rst`.
- Target examples: `target/riscv/translate.c`, `target/riscv/*.decode`, `target/riscv/insn_trans/`.
