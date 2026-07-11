---
name: qemu-workflow-tcg-frontend-instruction
description: Use for adding, reviewing, or debugging a guest ISA instruction in a QEMU TCG frontend. Extends qemu-plan and qemu-rlcr-loop; this skill only defines frontend decode/translation decisions.
---

# QEMU TCG Frontend Instruction

Use this domain skill for guest ISA decode/translation work in `target/<arch>/`: decodetree patterns, `trans_*` functions, feature gates, helpers, PC updates, exceptions, and tests.

## Flow dependencies

1. Start with `qemu-plan`.
2. Put decode notes, generated decoder inspection, TCG logs, test outputs, and scratch files under `.oh-my-qemu/<task-slug>/`.
3. Before the first source mutation, MUST use `qemu-rlcr-loop` and keep
   iterative work inside RLCR rounds.
4. Use `qemu-build` for target builds.
5. Use `qemu-debug` for TCG logs and `one-insn-per-tb` debugging.
6. Use `qemu-model-verification` for evidence reporting.

## Hard policy boundary

Do not produce source code intended for QEMU upstream submission. Do not add DCO or review trailers.

## Frontend contract

A frontend maps guest instructions to TCG IR while preserving architectural exceptions, feature gating, PC state, and TB termination.

Record in the plan:

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
