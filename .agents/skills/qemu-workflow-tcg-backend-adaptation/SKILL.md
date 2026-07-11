---
name: qemu-workflow-tcg-backend-adaptation
description: Use for adapting a QEMU TCG host backend, including optional op support, constraints, register allocation, host code emission, qemu_ld/st, atomics, and vector ops. Extends qemu-plan and qemu-rlcr-loop.
---

# QEMU TCG Backend Adaptation

Use this domain skill for host backend work under `tcg/<host>/`: instruction encoders, `TCG_TARGET_HAS_*`, constraints, `tcg_out_op`, qemu load/store paths, vector emission, and generated host-code bugs.

## Flow dependencies

1. Start with `qemu-plan`.
2. Put host-code logs, TCG dumps, temporary disassembly, benchmark notes, and review files under `.oh-my-qemu/<task-slug>/`.
3. Before the first source mutation, MUST use `qemu-rlcr-loop` and keep
   implementation/debugging inside RLCR rounds.
4. Use `qemu-build` for host backend builds.
5. Use `qemu-debug` for TCG logs and `one-insn-per-tb`.
6. Use `qemu-model-verification` for final evidence.

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

Record one category in the plan:

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
