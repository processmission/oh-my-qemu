# Board modeling field lessons

Use this reference at board/SoC planning and review time. Requirements were
abstracted from captured agent sessions and a remote firmware-reproduction
workspace; names, paths, and customer details are removed.

## Board requirements (BM)

| ID | Requirement | Anti-pattern it prevents |
| --- | --- | --- |
| BM-01 | Separate board/SoC topology from device behavior: RAM initialization and `-m` handling belong to the machine/boot path; register windows and side effects belong to the device. | Boot code editing SoC state; device behavior in board files. |
| BM-02 | Derive the unimplemented map from an authoritative memory map; start minimal; measure guest-touched windows with `-d unimp,guest_errors` before shrinking; keep source and exclusions. | A 300-row table with no measurement; deleted evidence. |
| BM-03 | Use Unimplemented Device placeholders for windows that are not modeled yet, keep them visible, and remove them when the real device lands. | Stale placeholders; placeholders counted as modeled behavior. |
| BM-04 | Preserve hardware fidelity and naming: model a new board instead of mutating an existing SoC unless asked; use vendor vs board names correctly; do not add convenience devices. | "Generic" boards that silently change existing machines. |
| BM-05 | Record the dual-boot contract: direct kernel boot vs firmware chain, `-kernel`/`-dtb`/`-initrd` rules, EL2/PSCI constraints, high-RAM FDT handling, reset-vector ownership. | Testing only one path; broken high-memory or PSCI assumptions. |
| BM-06 | Define boot markers and stage boundaries; timeout or a missing marker is INCONCLUSIVE, not PASS; pin image and firmware hashes. | Timeout-only success claims; stale assets. |
| BM-07 | Add focused qtests for machine creation, memory-map probes, and representative IRQ/device wiring; scale test effort to the requested scope. | Boot-only validation hiding topology errors. |
| BM-08 | Record the cross-repo image/boot asset contract: separate boot files, hash pinning, local asset serving, and repository-specific metadata. | Functional-test hash drift; assets that only exist on one machine. |
| BM-09 | Keep board documentation short and implementation-grounded: follow the nearest sibling page, no out-of-tree repository links or local recipes, toctree registered. | 130-line pages with recipe internals and stale claims. |
| BM-10 | Record the framework/unimplemented boundary in the audit before writing board source; keep per-commit gates (build, qtest, checkpatch) when a series is requested. | Mixed topology and behavior changes in one unverifiable round. |

## Review adjustments

Apply the same review adjustments used for peripheral work when reviewing
board work: verify reviewer claims against code/QOM with `file:line`, classify
pre-existing versus introduced findings, re-derive expected values, and keep the
requested scope. The qemu-peripheral-modeling field-lessons reference carries
the numbered RV-01..RV-10 list when that skill is installed.

## Use in the workflow

1. At plan time, list applicable BM IDs and the unimplemented-map strategy.
2. Create placeholders via `unimplemented-device.md` and record their sources.
3. Boot evidence follows the stage/marker rules; no PASS without a marker or a
   falsifiable qtest.
4. After the real model lands, remove placeholders and rerun the same evidence.
5. Add a new BM entry only when the requirement is reusable beyond the task.

## Boundaries

Local board modeling and verification only; do not prepare upstream-ready code,
commit messages, or patches from these lessons.
