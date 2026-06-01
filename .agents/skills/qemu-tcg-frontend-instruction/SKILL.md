---
name: qemu-tcg-frontend-instruction
description: Use when adding or analyzing a guest ISA instruction in a QEMU TCG target frontend. Covers decodetree patterns, DisasContext feature gating, trans_* functions, helper calls, PC/TB behavior, and TCG tests.
license: GPL-2.0-or-later
---

# QEMU TCG Frontend Instruction

Use this skill when the task is to add, review, or debug a guest instruction in a QEMU target frontend such as `target/riscv`, `target/arm`, `target/loongarch`, or another TCG-translated architecture.

## Hard policy boundary

Do not produce source code intended for QEMU upstream submission. QEMU currently declines contributions believed to include or derive from AI-generated content. You may help with instruction semantics research, decoder analysis, debugging, and test strategy. Do not add `Signed-off-by` or any DCO-style trailer.

## Frontend mental model

A frontend turns guest instructions into TCG IR. The typical path is:

1. guest bytes are fetched for the current PC;
2. a decoder identifies the instruction and extracts fields;
3. a `trans_*` function validates feature/privilege/width constraints;
4. the translator emits TCG ops or calls helpers;
5. PC, exception, and TB termination behavior is set correctly;
6. tests prove architectural behavior.

## 1. Locate the target's translator style

Before changing anything, inspect nearby instructions in the same extension/subsystem:

- `.decode` files for opcode patterns and argument sets.
- `translate.c` for `DisasContext`, TB flags, feature helpers, PC update helpers, and decoder dispatch.
- `insn_trans/*.c.inc` or equivalent files for `trans_*` functions.
- `helper.h` and helper implementation files if nearby instructions use helpers.
- target CPU feature/property definitions.
- `tests/tcg/<target>/` for existing ISA tests.

Reuse the target's existing idioms. Do not invent a parallel translator style.

## 2. Add or review decoder coverage

For decodetree targets:

- Add a pattern only after confirming `(insn & fixedmask) == fixedbits` is unique enough.
- Use existing fields, formats, and argument sets when possible.
- If a field needs transformation, use a named field function in the style of the target.
- If several instructions share operands, use a shared argument set.
- Check overlap groups and ordering when encodings alias.
- Remember: a pattern calls `trans_NAME(DisasContext *ctx, arg_NAME *a)` or the target's equivalent generated signature.

For hand-written decoders, preserve decode order, extension checks, and illegal-instruction fallback.

## 3. Gate the instruction before emitting IR

A `trans_*` function should reject unsupported encodings before emitting side effects:

- ISA extension or CPU feature enabled;
- privilege level or virtualization state;
- XLEN/operand-width requirement;
- immediate/register constraints;
- vector length/state constraints if relevant;
- illegal reserved bits;
- alignment and memory-mode constraints where architectural.

Follow the target convention: many frontends return `false` from `trans_*` to let the decoder raise illegal instruction; others explicitly call exception helpers.

## 4. Emit TCG IR with correct architectural semantics

Prefer direct TCG ops for simple integer/logical/shift/select operations. Use helpers when the operation:

- is complex enough to be unreadable in TCG;
- needs shared C semantics;
- may raise an exception after non-trivial checks;
- touches large or non-scalar state;
- needs softfloat, crypto, vector, or target-specific helper libraries.

When using helpers:

- declare them in the target helper header;
- use correct `TCG_CALL_*` flags only if the helper truly has those properties;
- update PC before helper calls that may raise exceptions if target convention requires it;
- avoid helpers for operations that are a couple of TCG ops in hot paths.

## 5. Handle destination and zero registers correctly

Use target helpers for reading/writing registers:

- zero register writes should be discarded in the target's normal way;
- sign/zero extension should match architectural width;
- 32-bit forms on 64-bit targets often require explicit sign extension;
- vector/floating registers may need NaN-boxing, element-width, or state checks.

Do not directly index CPU state if the target provides frontend helpers.

## 6. PC, exceptions, and TB termination

Check the target's rules for:

- `ctx->base.pc_next` advancement;
- `gen_update_pc()` or equivalent before exceptions;
- `ctx->base.is_jmp` states such as next, no-return, branch, or too-many;
- direct block chaining eligibility;
- single-step/interrupt-trigger behavior;
- instructions crossing page boundaries.

A wrong PC update often produces misleading guest exceptions and broken gdbstub state.

## 7. Add tests at the right layer

Minimum test plan for a new instruction:

1. assembler/disassembler coverage if applicable;
2. `tests/tcg/<target>/` execution test for normal semantics;
3. edge values: zero, sign bit, carry/overflow, maximum shift, invalid immediate, reserved register if applicable;
4. illegal-instruction test when feature disabled or encoding invalid;
5. system-mode or privilege test if the instruction is not user-mode legal;
6. `-accel tcg,one-insn-per-tb=on` reproduction if debugging PC/TB behavior.

Do not rely only on a compiler-generated workload; it rarely exercises illegal encodings or edge cases.

## Debug checklist

When a new instruction misbehaves:

- Does the decoder select the intended `trans_*` function?
- Are fields sign-extended and concatenated correctly?
- Is the feature gate returning illegal at the right time?
- Are source/destination registers read/written through target helpers?
- Does the generated TCG IR match the intended data width?
- Does the helper have correct side-effect flags?
- Is PC saved before an exception?
- Is TB termination correct for branches, traps, and state changes?

## Upstream references

- Decodetree specification: `docs/devel/decodetree.rst`.
- TCG translator internals: `docs/devel/tcg.rst`.
- TCG IR and helper semantics: `docs/devel/tcg-ops.rst`.
- RISC-V translator examples: `target/riscv/translate.c`, `target/riscv/*.decode`, `target/riscv/insn_trans/`.
