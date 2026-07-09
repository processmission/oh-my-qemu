# QEMU Skill Repository Agent Guide

This repository stores agent skills for working on QEMU. It is not a QEMU upstream contribution branch.

## QEMU upstream provenance boundary

This repository is an Oh My Pi/Claude Code plugin and skill collection, not a
QEMU source tree. Repository maintenance commits follow the local commit policy.
QEMU's `docs/devel/code-provenance.rst` still applies when agents work inside a
QEMU source checkout or discuss output intended for QEMU upstream submission:

- Do not generate code intended for QEMU upstream submission.
- If a user asks for agent-written QEMU code intended for upstream merge, decline that part and refer them to QEMU's AI-generated content policy.
- AI may be used for research, debugging, static analysis, local-only experiments, and workflow guidance only when generated output is not included in QEMU upstream contributions.

## Artifact policy for QEMU source trees

All agent-created artifacts MUST live under the local Oh My QEMU artifact directory:

```text
.oh-my-qemu/<task-slug>/
```

This includes plans, goal trackers, reviews, logs, traces, replay files, scratch scripts, decoder dumps, copied command lines, and reports.
The runtime adds `.oh-my-qemu/` to the QEMU checkout's local `.git/info/exclude`
when the checkout is a Git worktree.

Never create `.plan/`, `.humanize/`, root-level notes, temporary helper files, or scratch directories in QEMU source paths. Source files should change only when they are the requested deliverable.

## Repository layout

Skills live under `.agents/skills/<skill-name>/SKILL.md`, matching the upstream RFC layout used for QEMU agent skills.

## Oh My Pi plugin layout

This repository is also an Oh My Pi plugin:

- `package.json` declares the OMP extension entry point.
- `src/extension.js` registers `qemu_init_task`, `/qemu-init-task`, and the artifact-policy hook.
- `skills` points to `.agents/skills` so OMP plugin discovery exposes the same skill content.
- `.claude-plugin/marketplace.json` lets OMP install the repository through the marketplace flow.

## Claude Code plugin layout

This repository is also a Claude Code plugin:

- `.claude-plugin/plugin.json` is the plugin manifest (name, version, hooks reference).
- `.claude-plugin/marketplace.json` lists the plugin with `source: "./"`, so the marketplace and the plugin live in one repo.
- `commands/qemu-init-task.md` provides the `/qemu-init-task` slash command.
- `hooks/hooks.json` wires a `PreToolUse` hook to `scripts/artifact-policy.mjs`, mirroring the OMP artifact policy.
- `scripts/init-task.mjs` backs `/qemu-init-task`; `scripts/artifact-policy.mjs` backs the hook.
- `src/lib.mjs` holds the shared workspace-init and artifact-policy logic used by both `src/extension.js` (OMP) and the Claude Code scripts, so behavior is identical across runtimes.
- `skills` points to `.agents/skills`, so the same SKILL.md content is exposed to Claude Code, OMP, and the portable `npx skills` install.

## Flow skills

- `qemu-plan`: first step for non-trivial tasks; creates the .oh-my-qemu artifact root, acceptance criteria, scope, evidence ledger, and verification gates.
- `qemu-source-provenance`: flow primitive for source roots, revisions, configs, toolchains, produced artifacts, and hashes.
- `qemu-image-layout`: flow primitive for boot media formats, partitions, offsets, write operations, mutation policy, and hashes.
- `qemu-boot-run`: flow primitive for reproducible QEMU boot commands, logs, timeout markers, and result classification.
- `qemu-register-extraction`: research flow that extracts register maps, bitfields, cross-register dependencies, side effects, IRQ/DMA behavior, and driver sequences from drivers, datasheets, firmware filesystems, and regfiles into markdown for peripheral modeling.
- `qemu-rlcr-loop`: simplified Humanize-style implementation/review loop using the plan, round summaries, independent review, scoped local Git checkpoint commits, final evidence, and one-time sanitized methodology feedback at terminal workflow points.

## Operational skills

- `qemu-build`: configuring, reusing `build/`, building, and diagnosing QEMU build failures.
- `qemu-qtest`: writing, listing, running, and debugging QEMU qtests from a build directory.
- `qemu-debug`: host-side QEMU process gdb/lldb, guest gdbstub, logs, traces, replay, and TCG/device debugging.
- `qemu-model-verification`: evidence ladder and reporting for model/runtime behavior.

## Domain skills

- `qemu-workflow-peripheral-modeling`: QEMU MMIO/SysBus/qdev peripheral modeling, using the checked-out QEMU registerinfo framework for guest-visible register banks.
- `qemu-workflow-board-modeling`: QEMU board, SoC, memory map, boot, and IRQ topology modeling, verified through added or extended qemu-qtest cases.
- `qemu-rst-documentation`: flow primitive for QEMU reStructuredText docs, including toctree/index updates and docs build validation.
- `qemu-workflow-tcg-frontend-instruction`: guest instruction decode/translation in a QEMU TCG frontend.
- `qemu-workflow-tcg-backend-adaptation`: TCG host backend adaptation for IR ops, constraints, emission, and feature flags.

## Boot and build skills

- `qemu-kernel-build`: flow primitive for building Linux kernel artifacts for QEMU boot testing.
- `qemu-uboot-build`: flow primitive for building U-Boot, SPL/TPL, FIT/ITB, and firmware-chain artifacts.
- `qemu-image-packaging`: flow primitive for packaging boot media.
- `qemu-workflow-direct-linux-boot`: workflow for direct Linux boot commands.
- `qemu-workflow-firmware-linux-boot`: workflow for firmware-to-Linux paths.

## Methodology feedback

At RLCR completion, pause, blocked state, or max-iteration exit, agents may produce sanitized workflow feedback in `.oh-my-qemu/<task-slug>/methodology-feedback.md` and ask once whether to file an upstream issue. Do not ask after every primitive or every step in a composed workflow. Use `scripts/draft-methodology-issue.mjs` only after the feedback report has been sanitized; it drafts issue title/body files under the task's `scratch/` directory. Default issue target is `processmission/oh-my-qemu`, overridable with `QEMU_METHODOLOGY_ISSUE_REPO`.

## Codex skill compatibility

Codex skills require `SKILL.md` frontmatter with only `name` and `description`. Keep license, ownership, category, and plugin metadata in repository-level files rather than skill frontmatter. Validate with:

```bash
npm run codex:skills:validate
```

## Upstream references

This repo follows the structure of the QEMU RFC series “AGENTS.md and associated skills” and the current QEMU code provenance policy. The upstream RFC is reference material, not permission for agents to produce upstreamable QEMU patches.
