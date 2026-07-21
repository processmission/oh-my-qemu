---
# SPDX-FileCopyrightText: Copyright (c) 2026 Process Mission
# SPDX-License-Identifier: MIT
name: qemu-tcg-backend
description: Use for adapting a QEMU TCG host backend, including optional op support, constraints, register allocation, host code emission, qemu_ld/st, atomics, vectors, and native-versus-fallback verification.
---

# QEMU TCG Backend Adaptation

Use this domain skill for host backend work under `tcg/<host>/`: instruction encoders, `TCG_TARGET_HAS_*`, constraints, `tcg_out_op`, qemu load/store paths, vector emission, and generated host-code bugs.

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

## Workflow

1. Record host architecture/features/toolchain, IR semantics, constraints,
   emitter path, unsupported cases, and allowed source paths.
2. Inspect the checked-out backend and generic fallback before enabling an op.
3. Work in small reviewable rounds and record changed paths, verification,
   review result, and gaps in `audit.md`.
4. Build for the affected host and run focused tests that exercise both native
   and fallback behavior where applicable.
5. Capture bounded host-code/TCG logs and keep unsupported features disabled
   until constraints, emission, and evidence agree.

## Hard policy boundary

Do not produce source code intended for QEMU upstream submission. Do not add DCO or review trailers.

## Backend contract

A backend change is correct only when these agree:

- IR op semantics from `include/tcg/tcg-opc.h` and `docs/devel/tcg-ops.rst`;
- host feature flag in `tcg-target-has.h`;
- operand constraints in `tcg-target-con-str.h` and `tcg-target-con-set.h`;
- register class/reserved-register assumptions in `tcg-target.h`;
- `tcg_out_op`, vector emission, or qemu_ld/st implementation in `tcg-target.c.inc`;
- tests/logs proving the native path or intentional generic expansion.

Do not enable `TCG_TARGET_HAS_*` before constraints and emission support are complete.

## Classify the change

Record one category in `audit.md`:

- new host instruction encoder;
- native emission for existing TCG op;
- optional op enablement;
- constraint/register allocation fix;
- qemu_ld/st or atomic path;
- vector op support;
- host feature gating/runtime CPU detection;
- code generation bug investigation.

## Emission checklist

Check:

- immediate ranges and sign extension;
- i32 result extension on 64-bit hosts;
- signed vs unsigned conditions;
- branch displacement and relocation/pool handling;
- clobbers and call ABI;
- scalar vs vector register classes;
- host endianness;
- constant materialization;
- instruction-cache flush needs.

Keep code generation paths allocation-free and simple.

## qemu_ld/st and atomics

Verify separately:

- `MemOp` size, sign, and endianness;
- TLB fast path vs slow path labels;
- i128 register pairing;
- user-mode vs system-mode differences;
- guest atomicity vs host capability;
- helper calls and clobbers;
- unaligned behavior.

## Vector rules

For vectors, verify:

- host vector feature detection;
- `v64/v128/v256` and specific op flags;
- element size coverage;
- constant operand forms;
- scalar fallback vs vector path;
- `tcg_can_emit_vec_op()` / `tcg_expand_vec_op()` behavior.

## Verification expectations

- Build the backend on the host.
- Run focused `tests/tcg` when available.
- Capture TCG IR and host-code logs proving native emission or fallback.
- Check unsupported host features remain disabled.
- Use `one-insn-per-tb` when frontend/backend attribution is unclear.

## Upstream references

- QEMU code provenance and AI policy: `docs/devel/code-provenance.rst`.
- TCG IR semantics: `docs/devel/tcg-ops.rst`.
- TCG internals: `docs/devel/tcg.rst`.
- Backend examples: `tcg/aarch64/`, `tcg/riscv64/`, `tcg/loongarch64/`.
- Core declarations: `include/tcg/tcg.h`, `include/tcg/tcg-opc.h`, `include/tcg/tcg-op-common.h`.
