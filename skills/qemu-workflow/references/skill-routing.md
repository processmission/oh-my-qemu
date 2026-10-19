# Skill routing

Read this reference when a task spans more than one QEMU area, when a user names a skill
that is not obviously the right one, or when a required skill may not be installed. Prefer
the smallest set of skills that covers the task.

For a complete device/board modeling task, start with
`qemu-modeler` when installed; it owns the phase/round loop and loads the
domain skills in the table below. Use `qemu-model-review` as the independent review leg.
This workflow remains the cross-cutting rule set when the orchestrator is not installed or
the task is not a full modeling loop.

## Verify installation first

If a skill named by the user or expected from the table below is not in the loaded skill
list, record `missing skill: <name>` in `audit.md`, follow the nearest available rule, and
do not improvise or claim the skill's rules. Installation is a separate, user-approved
step; report the gap and let the user install or update the catalog instead of
scattering copied skill files.

## Route by task

| Task | Skill |
| --- | --- |
| End-to-end modeling loop (plan, implement, debug, review, next round) | qemu-modeler |
| Independent review of one modeling round or patch | qemu-model-review |
| Board, SoC, machine, memory map, boot path, IRQ topology | qemu-board-modeling |
| Peripheral, MMIO, qdev, register framework choice | qemu-peripheral-modeling |
| Register and field contract from TRM, driver, SVD, traces | qemu-register-extraction |
| Configure, build, reuse, or diagnose QEMU build directories | qemu-build |
| Build a Linux kernel for boot testing | qemu-kernel-build |
| Build U-Boot, SPL, FIT, or BL31 inputs | qemu-uboot-build |
| Inspect or package disk, SD, flash, or qcow2 images | qemu-image |
| One reproducible QEMU run with logging, timeout, markers | qemu-boot-run |
| Direct kernel boot versus firmware and bootloader stages | qemu-linux-boot |
| Design, register, run, or debug qtests | qemu-qtest |
| Judge evidence against one falsifiable claim | qemu-model-verification |
| Debug a QEMU crash, assert, hang, or guest stall | qemu-debug |
| Write or update RST documentation | qemu-rst-documentation |
| Guest ISA decode and translation | qemu-tcg-frontend |
| Host TCG backend adaptation | qemu-tcg-backend |
| Multi-step planning, provenance, rounds, and handoff | qemu-workflow |
| Draft or file a sanitized oh-my-qemu feedback issue | qemu-agent-feedback |

## Negative boundaries

- Board versus peripheral: the board or SoC owns machine topology, RAM windows, and boot
  wiring; the device model owns that device's register behavior.
- QEMU build versus kernel or U-Boot build: qemu-build never cross-compiles Linux or
  U-Boot; qemu-kernel-build and qemu-uboot-build produce the boot inputs.
- Image inspect versus package: read-only format, partition, offset, and hash analysis is
  inspection; creating or writing images needs explicit authorization and readback
  evidence.
- Debug versus model-verification: debug localizes a failure; model-verification judges an
  existing evidence set against a claim. A debug session is not PASS evidence by itself.
- qtest versus functional test: qtest covers QEMU device and machine behavior; functional
  tests boot real assets and are a separate scope the user must request.
- Documentation versus code: docs work follows qemu-rst-documentation; do not change docs
  to compensate for missing implementation or verification evidence.

## First modeling task

register-extraction (source-cited contract) -> peripheral-modeling (framework decision and
device code) -> build (narrow target) -> qtest (unit evidence) -> model-verification
(claim against evidence) -> rst-documentation (page, only when requested). Join
board-modeling after the device model to wire memory and IRQs; use boot-run and linux-boot
to classify the first boot; use debug when a stall is not explained by the model. Keep the
task record in `.oh-my-qemu/<task-slug>/audit.md` throughout.

## Legacy names

An older plugin generation used skill-name suffixes that no longer exist. Map by suffix,
record the substitution in `audit.md`, and do not reuse old rules:

| Legacy suffix | Current skill |
| --- | --- |
| flow-plan, plan | qemu-workflow |
| source-provenance | qemu-workflow (provenance step) |
| rlcr-loop | qemu-workflow (iteration) |
| direct-linux-boot, firmware-linux-boot | qemu-linux-boot |
| image-layout, image-packaging | qemu-image |
| tcg-frontend-instruction | qemu-tcg-frontend |
| tcg-backend-adaptation | qemu-tcg-backend |
| workflow-board-modeling | qemu-board-modeling |
| workflow-linux-boot | qemu-linux-boot |
| workflow-peripheral-modeling | qemu-peripheral-modeling |
