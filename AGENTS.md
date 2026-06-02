# QEMU Skill Repository Agent Guide

This repository stores agent skills for working on QEMU. It is not a QEMU upstream contribution branch.

## QEMU provenance policy

Agents MUST follow QEMU's `docs/devel/code-provenance.rst` policy:

- Do not generate code intended for QEMU upstream submission.
- If a user asks for agent-written QEMU code intended for upstream merge, decline that part and refer them to QEMU's AI-generated content policy.
- AI may be used for research, debugging, static analysis, local-only experiments, and workflow guidance only when generated output is not included in QEMU upstream contributions.
- Agents MUST NOT add `Signed-off-by`, `Reviewed-by`, `Acked-by`, `Tested-by`, or similar contribution trailers on behalf of anyone.
- A `Signed-off-by` line is a human DCO certification; only the responsible human contributor may add it.

## Artifact policy for QEMU source trees

All agent-created artifacts MUST live under the QEMU build directory:

```text
build/agent/<task-slug>/
```

This includes plans, goal trackers, reviews, logs, traces, replay files, scratch scripts, decoder dumps, copied command lines, and reports.

Never create `.plan/`, `.humanize/`, root-level notes, temporary helper files, or scratch directories in QEMU source paths. Source files should change only when they are the requested deliverable.

## Repository layout

Skills live under `.agents/skills/<skill-name>/SKILL.md`, matching the upstream RFC layout used for QEMU agent skills.

## Flow skills

- `qemu-flow-plan`: first step for non-trivial tasks; creates the build/agent artifact root, acceptance criteria, scope, evidence ledger, and verification gates.
- `qemu-register-extraction`: research flow that extracts register maps, bitfields, cross-register dependencies, side effects, IRQ/DMA behavior, and driver sequences from drivers, datasheets, firmware filesystems, and regfiles into markdown for peripheral modeling.
- `qemu-rlcr-loop`: simplified Humanize-style implementation/review loop using the plan, round summaries, independent review, and final evidence.

## Operational skills

- `qemu-build`: configuring, reusing `build/`, building, and diagnosing QEMU build failures.
- `qemu-qtest`: writing, listing, running, and debugging QEMU qtests from a build directory.
- `qemu-debug`: host-side QEMU process gdb/lldb, guest gdbstub, logs, traces, replay, and TCG/device debugging.
- `qemu-model-verification`: evidence ladder and reporting for model/runtime behavior.

## Domain skills

- `qemu-peripheral-modeling`: QEMU MMIO/SysBus/qdev peripheral modeling, using the checked-out QEMU registerinfo framework for guest-visible register banks.
- `qemu-board-modeling`: QEMU board, SoC, memory map, boot, and IRQ topology modeling, verified through added or extended qemu-qtest cases.
- `qemu-tcg-frontend-instruction`: guest instruction decode/translation in a QEMU TCG frontend.
- `qemu-tcg-backend-adaptation`: TCG host backend adaptation for IR ops, constraints, emission, and feature flags.

## Upstream references

This repo follows the structure of the QEMU RFC series “AGENTS.md and associated skills” and the current QEMU code provenance policy. The upstream RFC is reference material, not permission for agents to produce upstreamable QEMU patches.
