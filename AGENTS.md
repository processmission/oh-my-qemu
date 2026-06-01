# QEMU Skill Repository Agent Guide

This repository stores agent skills for working on QEMU. It is not a QEMU upstream contribution branch.

## QEMU provenance policy

Agents MUST follow QEMU's `docs/devel/code-provenance.rst` policy:

- Do not generate code intended for QEMU upstream submission.
- If a user asks for agent-written QEMU code intended for upstream merge, decline that part and refer them to QEMU's AI-generated content policy.
- AI may be used for research, debugging, static analysis, and workflow guidance only when the generated output is not included in QEMU upstream contributions.
- Agents MUST NOT add `Signed-off-by`, `Reviewed-by`, `Acked-by`, `Tested-by`, or similar contribution trailers on behalf of anyone.
- A `Signed-off-by` line is a human DCO certification; only the responsible human contributor may add it.

## Repository layout

Skills live under `.agents/skills/<skill-name>/SKILL.md`, matching the upstream RFC layout used for QEMU agent skills.

Available skills:

- `qemu-peripheral-modeling`: QEMU MMIO/SysBus/qdev peripheral modeling.
- `qemu-board-modeling`: QEMU board, SoC, memory map, boot, and IRQ topology modeling.
- `qemu-model-verification`: qtest, runtime trace, and firmware smoke verification for models.
- `qemu-debug`: QEMU debugging workflow using gdbstub, logs, traces, replay, and bounded runs.
- `qemu-tcg-frontend-instruction`: adding a guest instruction to a QEMU target frontend.
- `qemu-tcg-backend-adaptation`: adapting TCG host backends for IR ops, constraints, code emission, and feature flags.

## Upstream references

This repo follows the structure of the QEMU RFC series “AGENTS.md and associated skills” and the current QEMU code provenance policy. The upstream RFC is reference material, not permission for agents to produce upstreamable QEMU patches.
