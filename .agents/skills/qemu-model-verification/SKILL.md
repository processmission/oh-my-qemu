---
name: qemu-model-verification
description: Use as a QEMU flow primitive to prove QEMU device, board, TCG, or runtime behavior with qtest, traces, logs, replay, and boot/workload evidence.
---

# QEMU Model Verification

Use this skill when a QEMU model, board, TCG change, or debug hypothesis must be proven rather than merely built.

As a flow primitive, use this skill to turn the result of a build, image package, boot run, trace, or debugger session into a clear PASS, FAIL, or INCONCLUSIVE claim.

## Primitive Boundary

This primitive owns only evidence interpretation and reporting. It consumes a
behavior claim, evidence paths, commands, hashes, traces, and logs supplied by
the caller, then reports `PASS`, `FAIL`, or `INCONCLUSIVE`. It does not choose
build, qtest, debug, boot, or iterative-fix workflow steps.

## Hard policy boundary

Do not produce source code intended for QEMU upstream submission. Do not add DCO or review trailers.

## Evidence ladder

Use the lowest rung that proves the claim:

1. **Static inspection**: source/docs establish a fact.
2. **Build**: touched target compiles.
3. **Unit/qtest**: register, IRQ, timer, memory, or board contract holds.
4. **Trace/log**: the expected runtime path executes and the bad path does not.
5. **Boot smoke**: firmware/kernel reaches a named milestone.
6. **Workload**: guest output proves the modeled hardware was consumed correctly.
7. **Replay/reproduction**: failure is deterministic or captured for later analysis.

Do not claim device correctness from a boot banner alone.

## Required artifact discipline

Record in `.oh-my-qemu/<task-slug>/evidence.md`:

- exact command line;
- QEMU binary and build directory;
- image paths and hashes/build IDs;
- accelerator and machine type;
- positive marker expected;
- negative markers checked;
- log/trace/replay paths;
- what the evidence proves;
- what remains unproven.

## Failure classification

Classify before changing model code:

- environment/toolchain/build directory;
- stale or wrong image;
- boot ABI mismatch;
- board topology mismatch;
- device register/IRQ/timer/DMA semantics;
- TCG frontend/backend bug;
- guest/application bug unrelated to the model.

Only topology, model-semantics, and TCG categories usually justify source changes.

## Device/board verification checklist

- reset state;
- read/write masks and reserved bits;
- W1C/status clear;
- IRQ raise/lower and interrupt-controller route;
- virtual clock/timer behavior;
- DMA guest-memory effect;
- machine creation;
- key memory-map probes;
- reset after dirty state.

## Trace validation rules

For accelerators or reverse-engineered paths:

- count events and inspect semantic summaries;
- check skipped/unknown descriptor counts;
- verify command-memory and DMA ranges;
- correlate trace milestones with UART or workload output;
- verify the running image is the image you intended.

## Reporting format

Use:

```text
PASS|FAIL|INCONCLUSIVE: <gate>
Command: <exact command>
Artifacts: <paths under .oh-my-qemu/<task-slug>/>
Evidence: <decisive lines or summary>
Proves: <specific claim>
Does not prove: <remaining gap>
```

## Upstream references

- QEMU code provenance and AI policy: `docs/devel/code-provenance.rst`.
- Testing overview: `docs/devel/testing/main.rst`.
- qtest docs: `docs/devel/testing/qtest.rst`.
- Tracing: `docs/devel/tracing.rst`.
- Replay: `docs/system/replay.rst`.
