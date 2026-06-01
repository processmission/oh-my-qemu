---
name: qemu-tcg-backend-adaptation
description: Use when adapting a QEMU TCG host backend, adding support for TCG IR ops, changing constraints, feature flags, register allocation assumptions, vector op emission, or host instruction encoders.
license: GPL-2.0-or-later
---

# QEMU TCG Backend Adaptation

Use this skill when the task touches a TCG host backend under `tcg/<host>/`: adding an IR op implementation, enabling an optional op, changing constraints, fixing generated host code, adapting vector support, or debugging register allocation/code emission.

## Hard policy boundary

Do not produce source code intended for QEMU upstream submission. QEMU currently declines contributions believed to include or derive from AI-generated content. You may help with backend analysis, debugging, and verification strategy. Do not add `Signed-off-by` or any DCO-style trailer.

## Backend mental model

The TCG frontend emits target-independent IR. The backend maps that IR to host machine code using:

- op support flags in `tcg-target-has.h`;
- operand constraints in `tcg-target-con-str.h` and `tcg-target-con-set.h`;
- register definitions and reserved registers in `tcg-target.h`;
- host instruction encoders and `tcg_out_*` helpers;
- `tcg_out_op()` / vector emission / qemu load-store paths in `tcg-target.c.inc`.

Correctness requires all of these to agree. Enabling a feature flag without constraints and emission support is a bug.

## 1. Classify the backend change

Before analyzing or reviewing code, decide which category applies:

- **New host instruction encoding**: add an encoder helper only.
- **Existing TCG op, missing host emission**: add `tcg_out_op` or vector case.
- **Optional op enablement**: set `TCG_TARGET_HAS_*` only after emission and constraints are correct.
- **Constraint fix**: adjust allowed registers/immediates without changing semantics.
- **Register allocation issue**: clobber, fixed register, call ABI, or temp lifetime problem.
- **Load/store/MMU issue**: qemu_ld/st fast path, slow path labels, endianness, sign extension, atomicity.
- **Vector issue**: vector length, element size, host feature gating, fallback expansion.

Do not treat an instruction encoder as proof that a TCG op is supported.

## 2. Inspect the operation contract

For the TCG op under discussion, verify:

- operand count and order from `include/tcg/tcg-opc.h` and generated enum usage;
- operand types (`i32`, `i64`, `i128`, vector, pointer, register-sized);
- constant operands vs register operands;
- side effects and memory ordering;
- undefined vs unspecified behavior from `docs/devel/tcg-ops.rst`;
- whether generic expansion already exists and should remain the fallback.

If the op has tricky semantics, prefer keeping the generic expansion until focused tests prove native emission.

## 3. Keep constraints, feature flags, and emission synchronized

A backend op is complete only when these match:

- `TCG_TARGET_HAS_foo` advertises support only when the backend can emit it for the relevant type/flags.
- Constraint sets accept exactly the register/immediate forms the emitter handles.
- `tcg_out_op()` or vector emission has a case for the op and all constant combinations allowed by constraints.
- Register clobbers are declared or avoided.
- Host CPU feature checks gate optional instructions at runtime where needed.

If any dimension is partial, leave the feature disabled or route unsupported cases to generic expansion.

## 4. Emit host code defensively

When reviewing or writing backend logic, check:

- immediate range and sign-extension assumptions;
- 32-bit operation result extension rules on 64-bit hosts;
- condition-code polarity and signed/unsigned compare distinctions;
- branch displacement range and relocation/pool handling;
- constant materialization sequences;
- call ABI and reserved registers;
- host endianness;
- instruction-cache flush requirements;
- vector register class vs scalar register class.

Avoid allocating memory or performing heavyweight work while emitting each op. Code generation is hot.

## 5. qemu_ld/st and atomics need separate scrutiny

For memory operations, verify:

- `MemOp` size, sign, and endianness handling;
- TLB fast path vs slow path labels;
- correct data register pairing for 128-bit operations;
- host atomic capability vs required guest atomicity;
- user-mode vs system-mode differences;
- helper calls preserve required state and clobbers;
- unaligned behavior matches QEMU memory semantics.

Do not assume a scalar ALU pattern applies to qemu_ld/st paths.

## 6. Vector support rules

For vector ops, check:

- host feature bits and vector length availability;
- `TCG_TARGET_HAS_v64/v128/v256` and specific optional vector op flags;
- element size (`vece`) coverage;
- scalar fallback vs vector path;
- constant-operand forms;
- `tcg_can_emit_vec_op()` and `tcg_expand_vec_op()` behavior;
- tests that distinguish element size and lane count.

A vector op that works for one element size may be wrong for another.

## 7. Debugging backend failures

Use this ladder:

1. Reproduce with `-accel tcg` and disable other accelerators.
2. Add `-accel tcg,one-insn-per-tb=on` if frontend/backend attribution is unclear.
3. Use `-d` logs to capture guest instruction, TCG ops, and host code.
4. Compare generated IR against expected frontend output.
5. Inspect backend constraints and emitted machine code for the failing op.
6. Force the generic expansion path, if possible, to determine whether the native backend case is at fault.
7. Add or identify a focused `tests/tcg/<guest>` case.

## 8. Verification checklist

A backend adaptation is not proven until:

- the backend builds for that host;
- relevant `tests/tcg` pass on that host;
- a focused test distinguishes the old bug from the fixed behavior;
- debug logs show the intended op is emitted or deliberately expanded;
- unsupported host CPU features remain disabled at runtime;
- no unrelated op support flag was enabled accidentally.

## Anti-patterns

- Setting `TCG_TARGET_HAS_*` before emission is complete.
- Letting constraints promise immediates/register classes not handled by the emitter.
- Fixing one constant form while breaking register form.
- Assuming i32 behavior automatically matches i64 behavior.
- Treating vector v64/v128/v256 as interchangeable.
- Debugging backend code under KVM/HVF instead of TCG.

## Upstream references

- TCG IR and op semantics: `docs/devel/tcg-ops.rst`.
- TCG translator/runtime internals: `docs/devel/tcg.rst`.
- Backend structure examples: `tcg/aarch64/`, `tcg/riscv64/`, `tcg/loongarch64/`.
- Core TCG declarations: `include/tcg/tcg.h`, `include/tcg/tcg-opc.h`, `include/tcg/tcg-op-common.h`.
