# QEMU Flow Primitives

Use these primitives as small, composable steps. Workflow skills call them
instead of repeating artifact, provenance, image, boot, debug, or verification
rules. A flow primitive must not tell the agent to call another flow primitive.

## Primitive Contract

Every primitive must:

- consume a task workspace supplied by the caller unless the task is trivial;
- write generated artifacts under `.oh-my-qemu/<task-slug>/`;
- record exact commands in `commands.md`;
- record decisive evidence paths in `evidence.md`;
- classify the result as `PASS`, `FAIL`, or `INCONCLUSIVE` when it proves or disproves a claim;
- avoid board-specific constants unless the user or local sources provide them.

## Stable Primitive Types

- planning;
- source provenance;
- image layout;
- boot/run logging;
- debugging;
- model or runtime verification;
- build, package, qtest, documentation, and issue reporting.

## Composition Rule

Only workflow skills define ordering between primitives. If a skill needs to
sequence multiple primitives, classify it as `qemu-workflow-*`, not
`qemu-*`.

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
