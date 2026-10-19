# Custom ISA target modeling

Use this checklist for a toy, vendor, or reverse-engineered guest ISA that QEMU does not
support. It extends the frontend rules to target, CPU, machine, and test plumbing. Grounded in
the checked-out target layout and in repeated custom-ISA work (a 2026-07/08 STC32/MCS-251
target modeling effort produced `target/mcs251/*` plus `tests/functional/stc32/test_isa.py`).

## 1. Inspect before copying

- Read the nearest comparable target under `target/`; for a small 16-bit ISA,
  `target/avr/` shows a compact layout (`Kconfig`, `cpu.c`, `cpu.h`, `helper.c`,
  `translate.c`, `insn.decode`, `machine.c`, `meson.build`).
- Read how that target registers its decoder, CPU type, helpers, migration state, and gdbstub.
- Read `configs/targets/` for a matching `<target>-softmmu.mak` and the Kconfig select lines.
- Record the QEMU revision in `audit.md`; target APIs and file names differ between versions.

## 2. Enable the target

- Add `target/<arch>/` sources and follow the nearest target's `Kconfig` and `meson.build`
  wiring instead of inventing a new build shape.
- For decodetree, the checked-out `target/avr/meson.build` shows the shape:
  `decodetree.process('insn.decode', extra_args: ['--decode', 'decode_insn',
  '--insnwidth', '<width>'])`, with `translate.c` including `"decode-insn.c.inc"`.
- Add the target makefile under `configs/targets/` and configure with
  `--target-list=<target>-softmmu` in a named `builds/build-<target>/` directory.
- Keep the initial machine minimal: RAM, one console UART, one timer, and the interrupt/trap
  model the ISA needs; this machine exists to run instruction and machine tests.

## 3. CPU state and helpers

- Define CPU state in `cpu.h`/`cpu.c` following the nearest target: QOM type registration,
  reset values, realize checks, and any CPU properties.
- Put instruction helpers in `helper.c` and declare them with the tree's
  `DEF_HELPER_FLAGS_*` mechanism; inspect `include/tcg/tcg.h` for the current flag names and
  semantics before marking a helper as side-effect free.
- Compute PC and TB exits consistently: update the architectural PC, set
  `ctx->base.is_jmp` when the TB must end, and raise exceptions through the target's exception
  helpers rather than returning normally.
- Expose control/status registers (CSR-like state) through helpers only when the ISA defines
  them; keep the state in the CPU object and document the mapping in `audit.md`.

## 4. Decoder and translation registration

- Write `insn.decode` with fields and formats for every encoding group; reuse argument sets
  where fields repeat. Record the encoding table in `audit.md`.
- Implement `static bool trans_<NAME>(DisasContext *ctx, arg_<NAME> *a)` functions in
  `translate.c`; return `false` when the encoding is not handled so the caller can reject it.
- Register the decoder the way the nearest target does. Some targets include the generated
  decoder directly; others call a target translation-init function. Inspect the checked-out
  target before choosing.
- Add feature and privilege gates before emitting IR, and reject reserved or invalid encodings
  with the target's illegal-instruction exception.

## 5. TCG op mapping

- Prefer direct TCG ops for simple integer, logic, shift, and select instructions.
- Use helpers for complex state, division/softfloat, memory ordering, and exception-heavy
  semantics; keep long work out of translation.
- Verify each mapping against the ISA definition and record it per instruction group.
- Distinguish translated native behavior from helper or fallback behavior in tests and logs.

## 6. Per-instruction functional tests

Add `tests/functional/<target>/test_isa.py` (the real STC32 work created this file and edited
it repeatedly):

- subclass `qemu_test.QemuSystemTest` and select the new machine;
- build or ship a tiny guest binary that executes each instruction group and reports results over
  the UART or through the exit status; pin a SHA-256 when the binary is an external asset;
- cover valid encodings, invalid/illegal encodings, and feature-disabled behavior;
- register tests in `tests/functional/<target>/meson.build` using the arrays the parent
  `tests/functional/meson.build` expects, for example
  `tests_<target>_system_thorough = ['isa']`; the parent registers a test named
  `func-<target>-isa` in the matching suites;
- run it from the QEMU source root with the build's Meson, for example
  `builds/build-<target>/pyvenv/bin/meson test -C builds/build-<target> func-<target>-isa`;
  verify the exact test name in the checked-out Meson files.

## 7. qtest coverage

- Add `tests/qtest/<machine>-test.c` for machine creation and memory-map probes; keep the test
  behavioral (the guest-visible interface), not tied to the translator implementation.
- Register it in `tests/qtest/meson.build` under the matching architecture bucket and run
  `builds/build-<target>/pyvenv/bin/meson test -C builds/build-<target> qtest-<target>/<name>`.

## 8. Build and verify

- `ninja -C builds/build-<target> qemu-system-<target>` builds the target binary.
- Run the functional and qtest suites after every instruction-group change, not only at the end.
- Use `-accel tcg,one-insn-per-tb=on` and bounded `-d op,out_asm` logs when an instruction
  boundary or host-code mapping is unclear.
- Record commands, logs, and results under `.oh-my-qemu/<task-slug>/`.

## 9. Record the coverage in `audit.md`

Fill in [the ISA coverage template](../assets/isa-coverage-template.md) and keep it next to the
audit record: instruction group, pattern names, `trans_*` function, TCG mapping or helper, test
name, and PASS/FAIL/INCONCLUSIVE. List unimplemented instructions explicitly instead of letting
them raise a generic illegal instruction by accident.

## 10. Inspect the checked-out tree

File names, decodetree options, CPU type macros, helper flags, Meson registration, and test
framework APIs differ between QEMU versions. Locate each of them in the checked-out tree before
using them, and record the revision and any version-specific finding in `audit.md`.
