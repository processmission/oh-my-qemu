# QEMU Flow Primitives

Use these primitives as small, composable steps. Workflow skills should call them instead of repeating artifact, provenance, image, boot, debug, or verification rules.

## Primitive Contract

Every primitive must:

- start from a `qemu-flow-plan` workspace unless the task is trivial;
- write generated artifacts under `build/agent/<task-slug>/`;
- record exact commands in `commands.md`;
- record decisive evidence paths in `evidence.md`;
- classify the result as `PASS`, `FAIL`, or `INCONCLUSIVE` when it proves or disproves a claim;
- avoid board-specific constants unless the user or local sources provide them.

## Stable Primitives

- `qemu-flow-plan`: define scope, acceptance criteria, artifact root, and verification gates.
- `qemu-source-provenance`: record source roots, revisions, configs, toolchains, containers, outputs, and hashes.
- `qemu-image-layout`: record image format, size, partition map, offsets, write order, mutation policy, and hashes.
- `qemu-boot-run`: build and run reproducible QEMU boot commands, capture console logs, timeout, markers, and exit state.
- `qemu-debug`: narrow a failed run with host debugger, guest gdbstub, QEMU logs, trace events, replay, or instruction windows.
- `qemu-model-verification`: convert evidence into an explicit behavior claim.

## Common Compositions

- Kernel build: `qemu-flow-plan` -> `qemu-source-provenance` -> build command -> provenance update.
- U-Boot build: `qemu-flow-plan` -> `qemu-source-provenance` -> dependency check -> build command -> provenance update.
- Image packaging: `qemu-flow-plan` -> `qemu-source-provenance` -> `qemu-image-layout` -> package command -> layout verification.
- Direct Linux boot: `qemu-flow-plan` -> `qemu-source-provenance` -> `qemu-boot-run` -> `qemu-model-verification`.
- Firmware Linux boot: `qemu-flow-plan` -> `qemu-source-provenance` -> `qemu-image-layout` -> `qemu-boot-run` -> `qemu-debug` if needed -> `qemu-model-verification`.

## Failure Discipline

Before changing QEMU model code, classify failure as one of:

- wrong source, toolchain, or build output;
- stale or mutated image;
- image layout or offset mismatch;
- QEMU command-line mismatch;
- boot ABI or firmware handoff mismatch;
- missing device model behavior;
- guest/kernel/rootfs/application issue.

Only model-behavior, topology, boot ABI, or TCG classifications usually justify QEMU source changes.
