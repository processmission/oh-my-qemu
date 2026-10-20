---
# SPDX-FileCopyrightText: Copyright (c) 2026 Process Mission
# SPDX-License-Identifier: MIT
name: qemu-tcg-frontend
description: Use for adding, reviewing, or debugging guest ISA decode and translation in a QEMU TCG frontend, including feature gates, exceptions, PC/TB behavior, and focused instruction tests.
---

# QEMU TCG Frontend

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

Source comments describe ISA/decode/backend behavior and cite public QEMU or ISA
documentation only. Do not write `.oh-my-qemu/...`, `output/...`, `audit.md`,
evidence paths, round/review IDs, or absolute host paths into source. When
`qemu-workflow` is installed, run its `source-comments` gate on changed source
files.

## QEMU upstream boundary

QEMU's official GitLab and mailing lists are upstream channels. A patch becomes an upstream
contribution when it is sent to the maintainers selected through `MAINTAINERS`. Do not prepare or
send agent-generated code, documentation, commit messages, or patches for upstream submission; see
the checked-out tree's `docs/devel/code-provenance.rst`. Research, debugging, analysis, local
experiments, verification, and workflow guidance remain allowed. Local branches, commits, patch
files, pushes, and pull requests are not by themselves upstream contributions; perform those Git
actions only when requested.

## Workflow

1. Record the ISA version, encoding, feature/privilege gates, exception behavior, PC/TB rules,
   and allowed source paths.
2. Inspect the checked-out decoder and the nearest comparable target before choosing decodetree,
   direct TCG ops, or a helper.
3. Work in small reviewable rounds; record changed paths, verification, review result, and gaps.
4. Build the target and run focused valid, invalid, and disabled-feature instruction tests.
5. Capture bounded TCG logs only when needed; distinguish translated, helper, and fallback paths.

## Frontend contract

Record in `audit.md`: ISA version and privilege requirements; instruction encoding, aliases, and
operand sign/zero extension; XLEN/vector/FPU constraints; expected illegal-instruction cases; the
helper-versus-direct-op decision; and the tests that prove semantics and invalid encodings. Use
[the ISA coverage template](assets/isa-coverage-template.md) for per-instruction coverage.

## Decoder rules

For decodetree targets, reuse existing fields, formats, and argument sets; confirm
fixedmask/fixedbits uniqueness; handle overlap groups intentionally; use field functions for
transformed immediates; and keep ordering consistent with nearby extensions. For hand decoders,
preserve existing fallback and illegal-instruction behavior.

## Decoder collision and priority debugging

When an instruction decodes to the wrong pattern or a pattern is unreachable:

1. List the patterns that match the same instruction word and compare fixedbits/fixedmask.
2. Rebuild and read the decodetree generator error or generated decoder path reported by Meson;
   conflicts fail generation or leave a later pattern unreachable.
3. Order patterns from most specific to most general; comment intentional overlap groups and add
   a negative test for every shadowed encoding.
4. Record the pattern order and tested encodings in `audit.md`.

## `trans_*` rules

Before emitting IR, gate:

- CPU/ISA feature;
- privilege/virtualization mode;
- XLEN/operand width;
- reserved bits and invalid immediates;
- vector/FPU state where relevant;
- alignment or memory-mode constraints if architectural.

Use direct TCG ops for simple integer/logical/shift/select operations. Use helpers for complex
state, softfloat/crypto/vector libraries, or exception-heavy semantics.

## Helper side-effect flags

Helper flags tell TCG which globals a helper reads or writes and whether the call has side
effects; a helper that raises an exception or mutates guest-visible state must keep those effects
visible. Failure example: a raising helper declared with the no-side-effects flag looks removable
to TCG, so the call can be dropped or reordered when its result is unused. The build still
succeeds; only a guest test that depends on the exception or state write fails. Inspect the
checked-out flag definitions (in `include/tcg/tcg.h`) and add such a test.

## PC and TB rules

Check target conventions for:

- `pc_next` advancement;
- PC update before exceptions;
- branch/direct-block chaining;
- `ctx->base.is_jmp` state;
- page-boundary behavior;
- single-step and interrupt trigger behavior.

Wrong PC state corrupts exceptions, gdbstub state, and replay/debug evidence.

## Custom ISA modeling

For a new toy, vendor, or reverse-engineered ISA target, use
[custom-isa.md](references/custom-isa.md): target enablement, decode and translation
registration, TCG op mapping, CPU state and control-register helpers, per-instruction functional
tests, qtest coverage, and build targets. Keep the frontend testable per instruction group.

## Verification expectations

- Build the target translator.
- Add focused `tests/tcg/<target>/` coverage when applicable; otherwise add a functional
  per-instruction test.
- Cover edge values, invalid encodings, feature-disabled behavior, and privilege errors.
- Use `-accel tcg,one-insn-per-tb=on` when debugging instruction boundaries.
- Store TCG logs under `.oh-my-qemu/<task-slug>/logs/`.

## Upstream references

- `docs/devel/code-provenance.rst`
- `docs/devel/decodetree.rst`
- `docs/devel/tcg.rst`
- `docs/devel/tcg-ops.rst`
- `docs/devel/submitting-a-patch.rst`
- `target/riscv/` (decodetree and `insn_trans/` implementation examples)

Paths can differ between QEMU versions; locate them in the checked-out tree.
