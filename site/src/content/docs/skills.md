---
title: "Skill catalog"
description: "The 19 portable Oh My QEMU skills, grouped by the work they support."
order: 2
category: "Reference"
---

Every skill is independently installable and includes the same compact audit,
workspace, build, and Git-exclude rules. Skills also ship one-level resources:
`references/` for detailed procedures, `assets/` for copy-ready templates, and
`scripts/` for portable checks. Bash helpers are bash 3.2 function libraries;
Python helpers use only the standard library. Install only the skills a project
needs.

## Choosing a skill

Pick the skill that matches the object being changed or the evidence being
produced:

- new register contract: `qemu-register-extraction`;
- device behavior: `qemu-peripheral-modeling`;
- board or SoC topology: `qemu-board-modeling`;
- instruction decode or host code generation: `qemu-tcg-frontend` or
  `qemu-tcg-backend`;
- build, image, or boot: `qemu-build`, `qemu-kernel-build`,
  `qemu-uboot-build`, `qemu-image`, `qemu-boot-run`, `qemu-linux-boot`;
- evidence and regression: `qemu-qtest` and `qemu-model-verification`;
- debugging or documentation: `qemu-debug` or `qemu-rst-documentation`;
- coordination, provenance, round management, patch-series, and handoff:
  `qemu-workflow`, with `qemu-agent-feedback` for approved workflow feedback;
- end-to-end modeling: start with `qemu-modeler`, which routes the
  domain skills and runs the implement -> build/test -> debug -> review loop;
  `qemu-model-review` is the independent reviewer it invokes each round.

A first modeling task normally runs in this order:
`qemu-register-extraction` -> `qemu-peripheral-modeling` -> `qemu-build` ->
`qemu-qtest` -> `qemu-model-verification`, then `qemu-rst-documentation` if
documentation is requested. The orchestrator runs this as a reviewed loop.

If the agent does not list a needed skill, record the gap in the task audit
and reinstall instead of improvising the skill's rules.

## Orchestration and review

- `qemu-modeler`: top-level entry for a complete modeling task; phase
  protocol, round loop, task-state and review-request templates, and `loop-state.sh`.
- `qemu-model-review`: independent review of one round; checklist, report template,
  and deterministic `review-checks.sh`; returns BLOCKER/MAJOR/MINOR/NOTE findings and
  a PASS/FAIL/INCONCLUSIVE verdict.

## Coordination and feedback

- `qemu-workflow`: planning, evidence, review, handoff, and a self-contained hard-gate
  library (`scripts/gates.sh`) for workspace, round, evidence, Git, build, marker, and
  handoff checks.
- `qemu-agent-feedback`: sanitize one reusable workflow improvement and file it only after
  explicit approval; ships a redaction checker and an issue template and does not depend on
  repository scripts.

## Modeling and TCG

- `qemu-register-extraction`: extract a cited register and behavior contract plus a
  Register Semantics IR (RS-IR) text (Trigger/Condition/Transition rules, DEF-style vocabulary,
  parser/validator with canonical dump, translation worklist, and unimplemented placeholders).
- `qemu-peripheral-modeling`: research and verify local peripheral or accelerator models,
  including the RS-IR to RegisterInfo/manual-MMIO translation, trace/log/error mapping, and
  field lessons.
- `qemu-board-modeling`: work with boards, SoCs, memory maps, boot paths, and IRQ topology,
  including the unimplemented-device placeholder lifecycle and board field lessons.
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
- `qemu-rst-documentation`: work with QEMU reStructuredText and documentation builds;
  ships a board/machine page template, requirements reference, and RST gate script.

The modeling, TCG, and documentation skills are for local research and
verification. They do not authorize preparing or sending generated patches to
the QEMU mailing-list recipients selected through `MAINTAINERS`. Local Git
operations and pull requests do not by themselves constitute QEMU upstream
contributions.
