<h1 align="center">Oh My QEMU</h1>

<p align="center">
  <strong>Portable, auditable QEMU skills for coding agents.</strong><br>
  Device models · Board bring-up · Builds and boots · Tests and review
</p>

<p align="center">
  <a href="https://github.com/processmission/oh-my-qemu/actions/workflows/ci.yml"><img src="https://github.com/processmission/oh-my-qemu/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <img src="https://img.shields.io/badge/skills-19-315879?style=flat-square" alt="19 skills">
  <img src="https://img.shields.io/badge/license-MIT-3da639?style=flat-square" alt="License: MIT">
  <img src="https://img.shields.io/badge/interface-Codex%20%C2%B7%20Claude%20Code-7A51C2?style=flat-square" alt="Codex and Claude Code">
</p>

<p align="center">
  <strong>English</strong> · <a href="docs/zh/README.md">中文文档</a>
</p>

<p align="center">
  <a href="#why-oh-my-qemu">Why</a> ·
  <a href="#how-it-works">How it works</a> ·
  <a href="#quick-start">Quick start</a> ·
  <a href="#skills">Skills</a> ·
  <a href="#validation">Validation</a> ·
  <a href="#documentation">Documentation</a>
</p>

---

Nineteen project-local skills that teach a coding agent to model QEMU devices and
boards, translate register evidence into **RegisterInfo** and **Unimplemented
Device** implementations, and take the work through build, boot, test, debug,
independent review, and handoff.

> **Local modeling, review, and verification.** The skills are designed for
> local-only work and evidence collection. They do not prepare or send
> agent-generated code, documentation, commit messages, or patches for QEMU
> upstream submission.

## Why Oh My QEMU

- **One entry point.** Say "model this device" or "run the next round" and
  `qemu-modeler` routes the domain skills, runs the implement → build/test →
  debug → review loop, records state, and hands off.
- **Evidence before code.** `qemu-register-extraction` produces a human
  `register-contract.md` plus a machine-readable RS-IR
  (`output/register-semantics.ir`). `--translate` turns rules into
  mechanisms, hooks, trace/log/error policy, qtests, and unimplemented
  placeholders.
- **Review is part of the loop.** `qemu-model-review` is a read-only reviewer
  invoked every round; a round does not advance on self-approval. PASS needs a
  marker or a falsifiable qtest, never a timeout or a boot banner.
- **Hard checks ship as code.** A gate library, an RS-IR validator, review
  packet checks, and a loop-state CLI make the workflow repeatable across agents
  and sessions.
- **Portable by construction.** Each skill is independently installable and
  keeps its own references, assets, and scripts. A missing skill is recorded as
  a gap instead of being improvised.

## How it works

<p align="center">
  <a href="docs/en/modeling-workflow.md"><img src="docs/en/assets/modeling-flow.png" width="720" alt="qemu-modeler phases P0-P8 with the independent review loop"></a><br>
  <sub>P0-P8 modeling loop · independent review · PASS/FAIL/INCONCLUSIVE decisions</sub>
</p>

```text
request / resume
      │
 qemu-modeler ── P0 intake → P1 evidence & contract → P2 translation
      │                              → P3 implementation → P4 build & test
      │                                      │ fail → P5 debug → P3
      │                                      │ pass → P6 independent review
      │                                      │        → BLOCKER → P3 (re-review)
      │                                      ▼
      └──────────────── P7 decision: next round / replan / stop → P8 handoff
```

The full phase protocol, routing rules, and round/review templates live in
[the English modeling workflow](docs/en/modeling-workflow.md) and
[the English architecture doc](docs/en/architecture.md).

<p align="center">
  <a href="docs/en/architecture.md"><img src="docs/en/assets/modeling-architecture.png" width="760" alt="Modeling architecture: inputs, qemu-modeler, skills per phase, and audit evidence"></a><br>
  <sub>Inputs → qemu-modeler → skills per phase → audit workspace and evidence</sub>
</p>

## Quick start

Run from the QEMU repository root:

```bash
curl -fsSL https://raw.githubusercontent.com/processmission/oh-my-qemu/main/install.sh | bash
```

The installer is project-local, installs all 19 skills, and rejects global
installation. It adds `.agents/`, `.claude/skills/`, `.oh-my-qemu/`,
`builds/`, and `skills-lock.json` to the repository-local Git exclude
without changing `.gitignore` or adding duplicates.

Then start a modeling task in your agent:

> Use `qemu-modeler` to model `<device/board>` with acceptance criteria `<...>`.

Or invoke a domain skill directly for a single task. A first modeling task
normally runs:

```text
qemu-register-extraction → qemu-peripheral-modeling → qemu-build
    → qemu-qtest → qemu-model-verification → qemu-rst-documentation (if requested)
```

Verify the installation from the target repository root:

```bash
ls .agents/skills | grep '^qemu-'
ls .claude/skills | grep '^qemu-'
```

If a needed skill is not listed, record the gap in the task audit and reinstall
instead of improvising its rules.

<details>
<summary>Contributor install, subset install, and migration from 0.x</summary>

Contributors can install a local checkout:

```bash
git clone https://github.com/processmission/oh-my-qemu.git
cd oh-my-qemu
./install.sh --target /path/to/qemu
./install.sh --target /path/to/qemu --skill qemu-build
```

Earlier releases shipped an `oh-my-qemu` agent plugin and user-level skill
symlinks. Disable the old plugin and remove its dangling links before
installing project-locally; this repository does not delete those paths
automatically.

</details>

## Skills

| Layer | Skills | What it covers |
| --- | --- | --- |
| Orchestration & review | `qemu-modeler` · `qemu-model-review` | Top-level routing, phase/round loop, state, independent review |
| Workflow | `qemu-workflow` · `qemu-agent-feedback` | Provenance, gates, patch series, evidence mining, sanitized feedback |
| Evidence & contract | `qemu-register-extraction` · `qemu-board-modeling` | Register/behavior contract, RS-IR, board contracts, unimplemented maps |
| Modeling | `qemu-peripheral-modeling` · `qemu-tcg-frontend` · `qemu-tcg-backend` | RegisterInfo/manual-MMIO devices, guest ISA decode, host backends |
| Build, image & boot | `qemu-build` · `qemu-kernel-build` · `qemu-uboot-build` · `qemu-image` · `qemu-boot-run` · `qemu-linux-boot` | Named builds, boot inputs, image packaging, marker-aware runs |
| Verification & support | `qemu-qtest` · `qemu-model-verification` · `qemu-debug` · `qemu-rst-documentation` | qtests, PASS/FAIL/INCONCLUSIVE judgment, debugging, board docs |

Skills are independently installable. Their references, assets, and scripts are
one level deep and linked from each `SKILL.md`.

## Validation

| Command | Verifies |
| --- | --- |
| `npm run codex:skills:validate` | 19 skill metadata, canonical audit/boundary blocks, resource linkage, script syntax, catalog consistency |
| `npm run test:skill-scripts` | Gate library, RS-IR parser/translation, review checks, loop state, and every skill script |
| `npm run test:qemu-boot-run` | Marker-aware QEMU run classification |
| `bash skills/qemu-workflow/scripts/gates.sh --help` | Workspace, round, evidence, Git, build, marker, and handoff gates |
| `bash skills/qemu-model-review/scripts/review-checks.sh --help` | Deterministic checks for one review packet |

CI runs the skills validator and the skill-script suite on every pull request.

## Documentation

| Resource | Contents |
| --- | --- |
| [docs/zh/README.md](docs/zh/README.md) · [English](docs/en/README.md) | 中文文档索引、设计目标、19 个 skill 分层（Chinese) |
| [docs/zh/architecture.md](docs/zh/architecture.md) · [English](docs/en/architecture.md) | Architecture, data flow, audit workspace, gates, boundaries |
| [docs/zh/modeling-workflow.md](docs/zh/modeling-workflow.md) · [English](docs/en/modeling-workflow.md) | P0-P8, round loop, review loop, stop conditions, commands |
| [docs/zh/rs-ir-and-translation.md](docs/zh/rs-ir-and-translation.md) · [English](docs/en/rs-ir-and-translation.md) | RS-IR, observe/placeholder, RegisterInfo and Unimplemented Device translation |
| [Skill routing](skills/qemu-workflow/references/skill-routing.md) | Which skill to load for which task |
| [site/](site/) | Published documentation site |

## Workspace contract

Non-trivial tasks keep their audit trail under `.oh-my-qemu/<task-slug>/`:

```text
.oh-my-qemu/<task-slug>/
  audit.md         baseline, plan, decisions, evidence, gaps
  commands.md      redacted commands, working directories, results
  logs/            decisive build, test, runtime output
  scripts/         temporary probes, parsers, harnesses
  output/          generated deliverables, dependencies, non-QEMU binaries
```

QEMU's own build output belongs in a named source-root directory such as
`builds/build-aarch64/`, never an unqualified `build/`. Source files change
only when they are the requested deliverable.

## Requirements

- A QEMU source checkout with Git.
- Linux or macOS with bash 3.2+ (scripts are portable; function form).
- Node.js 22+ for the installer.
- Python 3 with the standard library for the RS-IR validator and review checks.

## QEMU provenance

QEMU's official GitLab and mailing lists are upstream channels. A patch becomes
an upstream contribution when it is sent to the maintainers selected through
`MAINTAINERS`. Do not prepare or send agent-generated patches for that
submission; follow the checked-out tree's `docs/devel/code-provenance.rst`.

Local branches, commits, patch files, pushes, and pull requests are not by
themselves QEMU upstream contributions. Perform those Git actions only when
requested, and follow the workspace's Git policy.

## Development

Skills live in `skills/<skill-name>/SKILL.md`. Every skill contains:

- the Process Mission MIT SPDX header and `agents/openai.yaml`;
- the same canonical audit and QEMU upstream-boundary blocks;
- one-level `references/`, `scripts/`, and `assets/` resources, all linked
  from the skill's `SKILL.md`.

Architecture and workflow docs live in `docs/` and are kept aligned with the
skills and their Graphviz sources. Run the checks above before opening a pull
request.

## License

MIT. Copyright (c) 2026 Process Mission. See [LICENSE](LICENSE).
