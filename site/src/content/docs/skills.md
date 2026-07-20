---
title: "Skill catalog"
description: "The 17 portable Oh My QEMU skills, grouped by the work they support."
order: 2
category: "Reference"
---

Every skill is independently installable and includes the same compact audit,
workspace, build, and Git-exclude rules. Install only the skills a project
needs.

## Coordination and feedback

- `qemu-workflow`: optional planning, evidence, review, and handoff for a multi-step task.
- `qemu-agent-feedback`: sanitize one reusable workflow improvement and file it only after explicit approval; it does not depend on repository scripts.

## Modeling and TCG

- `qemu-register-extraction`: extract a cited register and behavior contract.
- `qemu-peripheral-modeling`: research and verify local peripheral or accelerator models.
- `qemu-board-modeling`: work with boards, SoCs, memory maps, boot paths, and IRQ topology.
- `qemu-tcg-frontend`: inspect guest instruction decode and translation behavior.
- `qemu-tcg-backend`: inspect host backend operations, constraints, and emission.

## Build, image, and boot

- `qemu-build`: configure and build QEMU in named `builds/build-<target>/` directories.
- `qemu-kernel-build`: build Linux kernel artifacts for QEMU testing.
- `qemu-uboot-build`: build U-Boot, SPL/TPL, FIT, and firmware-chain artifacts.
- `qemu-image`: inspect or package raw, qcow2, disk, flash, pflash, and firmware images.
- `qemu-boot-run`: construct reproducible QEMU runs and classify their results.
- `qemu-linux-boot`: boot Linux by direct kernel loading or through firmware.

## Verification and support

- `qemu-qtest`: design, run, and debug qtests.
- `qemu-debug`: use host debuggers, the guest gdbstub, traces, or replay.
- `qemu-model-verification`: select evidence and report PASS, FAIL, or INCONCLUSIVE.
- `qemu-rst-documentation`: work with QEMU reStructuredText and documentation builds.

The modeling, TCG, and documentation skills are for local research and
verification. They do not authorize generated content for QEMU upstream.
