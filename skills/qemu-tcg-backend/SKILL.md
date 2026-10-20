---
# SPDX-FileCopyrightText: Copyright (c) 2026 Process Mission
# SPDX-License-Identifier: MIT
name: qemu-tcg-backend
description: Use for adapting a QEMU TCG host backend, including optional op support, constraints, register allocation, host code emission, qemu_ld/st, atomics, vectors, and native-versus-fallback verification.
---

# QEMU TCG Backend

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

## Source comment hygiene

Keep file-header comments minimal: SPDX/copyright plus at most a one-line
component identity. Do not put implementation strategy, framework choice/defense,
"modeled contract" pointers, neighboring-device convention, or review/audit
rationale in source. Comment only key ISA/decode/backend code, in one to three
lines with at most one brief public QEMU or ISA reference; do not expand it into
a design or translation essay. Never write `.oh-my-qemu/...`, `output/...`,
`audit.md`, evidence paths, round/milestone/AC status, review notes, commands,
progress, or absolute host paths into source. When `qemu-workflow` is installed,
run its `source-comments` gate on changed source files.

## QEMU upstream boundary

QEMU's official GitLab and mailing lists are upstream channels. A patch becomes an upstream
contribution when it is sent to the maintainers selected through `MAINTAINERS`. Do not prepare or
send agent-generated code, documentation, commit messages, or patches for upstream submission; see
the checked-out tree's `docs/devel/code-provenance.rst`. Research, debugging, analysis, local
experiments, verification, and workflow guidance remain allowed. Local branches, commits, patch
files, pushes, and pull requests are not by themselves upstream contributions; perform those Git
actions only when requested.

## Workflow

1. Record the host architecture/features/toolchain, IR semantics, constraints, emitter path,
   unsupported cases, and allowed source paths.
2. Inspect the checked-out backend, the generic fallback, and the current TCG headers before
   enabling an op.
3. Work in small reviewable rounds; record changed paths, verification, review result, and gaps.
4. Build for the affected host and run focused tests that exercise native and fallback behavior.
5. Capture bounded host-code/TCG logs; keep unsupported features disabled until evidence agrees.

## Backend contract

A backend change is correct only when these agree:

- IR op semantics from `include/tcg/tcg-opc.h` and `docs/devel/tcg-ops.rst`;
- host feature flag in `tcg-target-has.h`;
- operand constraints in `tcg-target-con-str.h` and `tcg-target-con-set.h`;
- register class and reserved-register assumptions in `tcg-target.h`;
- `tcg_out_op`, vector emission, or qemu_ld/st implementation in `tcg-target.c.inc`;
- tests and logs proving the native path or the intentional generic expansion.

Do not enable a `TCG_TARGET_HAS_*` op before its constraints and emission support are complete.

## Host matrix

A backend is compiled for the build host only. Inspect the checked-out `tcg/` directory for the
current backend list and directory names; the x86 backend is `tcg/x86_64/` in this tree.

| Backend directory | Host class | Notes |
| --- | --- | --- |
| `tcg/x86_64/` | i386/x86_64 hosts | verify the directory name in the checked-out tree |
| `tcg/aarch64/` | AArch64 | `w`-class vector constraints, large immediate classes |
| `tcg/riscv64/` | RV64 | check branch/immediate ranges and scratch registers |
| `tcg/loongarch64/` | LoongArch64 | check immediate encodings and scratch registers |
| `tcg/s390x/` | s390x (big-endian) | host endianness and register model matter |

Backends for other hosts exist; inspect `tcg/` instead of assuming this list is complete.

## Inspect the checked-out TCG headers

TCG internal APIs change. Before using an op flag, constraint macro, or emission helper, read the
current definitions in the checked-out tree: `include/tcg/` (op definitions, `TCG_TARGET_HAS_*`,
helper flags) and the backend files above. Prefer the nearest backend that already supports the
feature over copying remembered signatures.

## Constraint file updates

| File | Purpose | Change when |
| --- | --- | --- |
| `tcg-target-con-str.h` | `REGS()`/`CONST()` letters | new register class or immediate |
| `tcg-target-con-set.h` | `C_O<n>_I<m>()` operand sets | new operand combination |
| `tcg-target-has.h` | `TCG_TARGET_HAS_*` op availability | after constraints and emission exist |
| `tcg-target.h` | register classes, reserved regs, word size | host ABI or register model change |
| `tcg-target.c.inc` | encoders, `tcg_out_op`, qemu_ld/st, vectors | the implementation change |
| `tcg-target-mo.h`, `tcg-target-opc.h.inc` | memory model; vector opcodes | inspect role first |

Update the constraint letter and the constraint set together; a set that references an undefined
letter is a build error, while an overly narrow set silently blocks an optimization.

## Classify the change

Record one category in `audit.md`, and capture the host, constraint, emission, and evidence
details with [the backend change template](assets/backend-change-template.md):

- new host instruction encoder;
- native emission for an existing TCG op;
- optional op enablement;
- constraint or register allocation fix;
- qemu_ld/st or atomic path;
- vector op support;
- host feature gating or runtime CPU detection;
- code generation bug investigation.

## Emission checklist

Check immediate ranges and sign extension, i32 result extension on 64-bit hosts, signed versus
unsigned conditions, branch displacement and relocation/pool handling, clobbers and call ABI,
scalar versus vector register classes, host endianness, constant materialization, and
instruction-cache flush needs. Keep code generation paths allocation-free and simple.

## qemu_ld/st and vectors

For qemu_ld/st, verify `MemOp` size/sign/endianness, TLB fast path versus slow path labels, i128
register pairing, user-mode versus system-mode differences, guest atomicity versus host
capability, helper calls and clobbers, and unaligned behavior. For vectors, verify host feature
detection, element-size coverage, constant operand forms, scalar fallback versus vector path, and
the `tcg_can_emit_vec_op()`/`tcg_expand_vec_op()` split.

## Verification and cross-host testing

- Build the backend on the host and run focused `tests/tcg` coverage where available.
- Capture TCG IR and host-code logs proving native emission or the intentional fallback.
- Keep unsupported host features disabled until constraints, emission, and tests agree.
- Use `-accel tcg,one-insn-per-tb=on` when frontend and backend attribution is unclear.
- A binary built for another host cannot execute locally (exec-format error). Validate another
  host backend with a cross toolchain under emulation or in CI, and record the environment and
  the limitation.

## Upstream references

- `docs/devel/code-provenance.rst`
- `docs/devel/tcg.rst`
- `docs/devel/tcg-ops.rst`
- `docs/devel/submitting-a-patch.rst`

Paths can differ between QEMU versions; locate them in the checked-out tree.
