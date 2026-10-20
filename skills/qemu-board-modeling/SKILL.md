---
# SPDX-FileCopyrightText: Copyright (c) 2026 Process Mission
# SPDX-License-Identifier: MIT
name: qemu-board-modeling
description: Use for QEMU board and SoC topology, memory map, boot policy, FDT/ACPI, and IRQ wiring modeling with proportional qtest verification; peripheral device behavior belongs to qemu-peripheral-modeling.
---

# QEMU Board and Machine Modeling

## Audit workflow

For a non-trivial task that writes to the workspace, use only the needed entries under
`.oh-my-qemu/<task-slug>/`: `audit.md` (baseline, plan, decisions, evidence, verification, and
gaps), `commands.md` (redacted commands, working directories, and results), `logs/` (decisive
build, test, and runtime output), `scripts/` (probes, parsers, and harnesses), and `output/`
(generated deliverables, third-party dependencies, and non-QEMU binaries). Keep QEMU's own build
tree at source-root `builds/build-<target>/`, never an unqualified `build/`. In a Git worktree,
add `.agents/`, `.oh-my-qemu/`, and `builds/` to the file from
`git rev-parse --git-path info/exclude` before writing artifacts or configuring QEMU; preserve
existing entries and avoid duplicates. Never stage or commit these paths; stage source only when
the user explicitly requests that separate action. At handoff, reconcile `git status --short`
with the baseline and report the task directory, build directory, source changes, pre-existing
changes, and unresolved gaps.

## Workflow

1. Freeze the board contract, allowed paths, and observable acceptance checks.
2. Inspect the current machine, nearby boards, tests, boot ABI, and authoritative
   hardware sources before changing code.
3. Work in small reviewable source-change rounds and record paths, verification,
   review result, and gaps for each round.
4. Build the affected target, add or extend board qtests for the changed machine
   contract, and use boot or workload evidence only as a supplemental integration
   gate that states exactly what it proves.

## QEMU upstream boundary

QEMU's official GitLab and mailing lists are upstream channels. A patch becomes an upstream
contribution when it is sent to the maintainers selected through `MAINTAINERS`. Do not prepare or
send agent-generated code, documentation, commit messages, or patches for upstream submission; see
the checked-out tree's `docs/devel/code-provenance.rst`. Research, debugging, analysis, local
experiments, verification, and workflow guidance remain allowed. Local branches, commits, patch
files, pushes, and pull requests are not by themselves upstream contributions; perform those Git
actions only when requested.

## Board contract

A board model is topology and boot policy; a peripheral model is behavior.
Default to a new board rather than modifying an existing SoC unless the task
explicitly asks for the existing machine. Model the real board revision and its
documented boot devices: do not add virtio, PCI, or other convenience devices
the hardware does not have, and do not add FDT nodes for unmodeled devices.

Name the machine for the board vendor and product and the SoC source file for
the SoC vendor and part; record the naming evidence and compatibility target in
`audit.md`. Register-bank framework decisions belong to the device model, not
the board: keep register layout, backing storage, and register-local hooks in
the device `.c` file and follow the register contract handoff for the record.

## Source comment hygiene

Keep board/SoC file-header comments minimal: SPDX/copyright plus at most a
one-line top-level description. Do not put implementation strategy, framework
choice/defense, "modeled contract" pointers, neighboring-device convention, or
review/audit rationale in source. Body comments may describe topology, boot ABI,
memory map, IRQ wiring, and public hardware references; evidence and source
citations belong in `audit.md`. Do not write `.oh-my-qemu/...`, `output/...`,
`audit.md`, evidence paths, round/review IDs, or absolute host paths into
source. If `qemu-workflow` is installed, run its `source-comments` gate on
changed source files.

## Board versus SoC ownership

| Concern | Owner | Rule |
| --- | --- | --- |
| `-m` and RAM layout/initialization | machine/boot path | Board owns RAM size, base, and initialization; the SoC does not encode board RAM policy. |
| Peripheral register windows and device behavior | SoC/device | Board wires window and IRQ; the device `.c` owns register semantics. |
| Unimplemented placeholders | SoC first; board only for board-only hardware | Do not list the same window at both layers. |
| IRQ wiring | SoC exports, board connects | Controller outputs come from the SoC; device inputs are routed by the board. |
| Boot ABI and reset entry | machine | Entry point, reset vector, FDT pointer, exception level, and RAM base are machine properties. |

## Hardware fidelity

- Do not widen a shared SoC model for one board; add board-local wiring or a new board.
- Use vendor/board naming consistently; record the naming decision instead of guessing.

## Required plan facts

Record before implementation: compatibility target (board/SoC revision, firmware, OS or SDK);
closest upstream QEMU reference board; memory map table; boot ABI (entry point, reset vector, FDT
pointer, privilege mode, RAM base); interrupt graph (local interrupts, controller contexts,
cascades, MSI routing); unimplemented windows and why they are safe. Use
[the board contract template](assets/board-contract-template.md) to record the contract.

## Realize order

Use dependency order: machine/SoC state; CPUs/harts; root RAM and ROM;
interrupt controllers and timers; CPU interrupt inputs; always-present
devices; MMIO maps and IRQ/clock/reset wiring; optional devices;
firmware/kernel/initrd/DTB loading; reset vector and reset hooks.

## Boot paths

Support direct kernel boot and firmware boot as separate paths with separate
evidence. Direct boot uses `-kernel` with optional `-initrd` and a DTB plus the
architecture loader; firmware boot uses `-bios` or the machine's flash/ROM
regions. Do not combine `-bios` with `-kernel`, or pass `-dtb` without
`-kernel`, on a direct-boot machine; validate machine properties and command
line combinations in the board. Reuse architecture boot helpers before
hand-rolling loader code, and model an intentional no-FDT firmware path instead
of generating a fake FDT.

For ARM, `arm_load_kernel` in `hw/arm/boot.c` adjusts the boot exception level
and disables a PSCI conduit that cannot work from that level; choose conduit
and exception level deliberately, and do not pair a direct EL2 entry with an
EL3 firmware model that owns the same PSCI call. Rewrite high-RAM `/memory`
FDT nodes before direct boot when RAM extends beyond the low-memory window. See
[boot path details](references/boot-paths.md).

## Unimplemented map

List only guest-reachable unimplemented windows, derived from the TRM or authoritative memory
map, with provenance in `audit.md`. Start minimal and add the SoC skeleton and interrupt
controller before boot-critical devices. Measure which windows the guest touches with
`-d unimp,guest_errors` and `info mtree` before shrinking; a diagnostic sink is not modeled
behavior. Record the table with [the CSV template](assets/unimplemented-map-template.csv),
follow [the unimplemented map policy](references/unimplemented-map.md), and use
[the unimplemented-device reference](references/unimplemented-device.md) for the
board-level placeholder lifecycle. Read [the field lessons](references/field-lessons.md)
at plan and review time.

## qtest verification

Make verification proportional: read-only research or review plans tests
without editing or running them; a source change requires tests for machine
creation, memory maps, reset vectors, and IRQ topology; optional devices need
representative register and IRQ coverage when practical.

When a test is required, add or extend a `tests/qtest/<board>-test.c` case,
register it in `tests/qtest/meson.build` under the correct architecture bucket,
instantiate the machine with minimal arguments, and probe RAM/ROM/MMIO and
unimplemented bases. Run the narrow Meson test name from the matching
`builds/build-<target>/` directory and store the command, result, and log path
under `.oh-my-qemu/<task-slug>/`. If a change cannot be covered by qtest, record
the technical reason and replacement evidence in `audit.md`.

## Anti-patterns

- Device register behavior in board or SoC files.
- Fake FDT nodes for devices that are not modeled.
- Boot success caused only by globally ignoring invalid accesses.
- Adding many devices before CPU, timer, IRQ, and boot spine are proven.

## Upstream references

- QEMU code provenance: `docs/devel/code-provenance.rst`.
- Source layout: `docs/devel/codebase.rst`.
- QEMU qtest: `docs/devel/testing/qtest.rst`.
- Linux boot: `docs/system/linuxboot.rst`.
- Invocation and machine options: `docs/system/invocation.rst`.

Paths can differ between QEMU versions; locate them in the checked-out tree.
