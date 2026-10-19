---
# SPDX-FileCopyrightText: Copyright (c) 2026 Process Mission
# SPDX-License-Identifier: MIT
name: qemu-linux-boot
description: Use for booting Linux in QEMU through either direct kernel loading or firmware and bootloader stages, selecting the path from task inputs while preserving provenance, boot logs, debug handoff, and verification evidence.
---

# QEMU Linux Boot

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

## QEMU upstream boundary

QEMU's official GitLab and mailing lists are upstream channels. A patch becomes an upstream
contribution when it is sent to the maintainers selected through `MAINTAINERS`. Do not prepare or
send agent-generated code, documentation, commit messages, or patches for upstream submission; see
the checked-out tree's `docs/devel/code-provenance.rst`. Research, debugging, analysis, local
experiments, verification, and workflow guidance remain allowed. Local branches, commits, patch
files, pushes, and pull requests are not by themselves upstream contributions; perform those Git
actions only when requested.

## Path selection

Classify the boot path before composing primitives:

- Use **direct Linux boot** when QEMU loads the kernel itself with options such as `-kernel`,
  `-dtb`, `-initrd`, and `-append`, without traversing firmware or bootloader stages.
- Use **firmware Linux boot** when Linux must be reached through BIOS, pflash, ROM, SPL, U-Boot,
  TF-A, EDK2, OpenSBI, vendor firmware, or boot media the firmware reads.
- Follow an explicitly requested path. For a fast smoke boot with a provided kernel, prefer
  direct boot; for a real board chain or boot-media validation, prefer firmware boot.
- If required artifacts are missing or the path is ambiguous, record the gap before running.

The selected path determines the contract; do not run both paths unless the task asks for
comparison or fallback evidence.

## Workflow

1. Freeze the path, named success markers, allowed writes, and acceptance checks in `audit.md`.
2. Record identity and hashes of QEMU, kernel, DTB, initrd or rootfs, firmware, bootloader, and
   boot media the selected path consumes.
3. For writable media, record layout and mutation or refresh policy before running QEMU.
4. Construct one copy-pasteable command, capture the full console log, and record timeout, exit
   status, positive markers, and negative markers. The optional `qemu-boot-run` skill documents a
   marker-aware runner and classification; use it when a file-backed serial log is available.
5. If boot fails, isolate the first failing stage with the narrowest reversible probe before
   changing source or artifacts.
6. Report the reached Linux milestone as PASS, FAIL, or INCONCLUSIVE with the evidence limits.

## Stage milestones and round gates

Use the default firmware stage list in `references/boot-stages.md`: reset/ROM, early loader,
trusted firmware or monitor, bootloader, boot medium, kernel entry, Linux console, rootfs or
shell, and the documentation stage. The final Linux result remains the acceptance criterion; each
round has its own gate and must name the expected marker, the current gate, and the next handoff
stage it unlocks. Copy `assets/boot-evidence-template.md` and record one row per stage.
By default, one round should not span more than one handoff stage; record why if it must.

Replan mid-round when several independent blockers appear, when evidence moves the task to a new
stage, or when a hypothesis is invalidated. Record the replan and the new gate in `audit.md`
instead of silently widening the round.

## Artifact to QEMU flag map

Keep each boot stage a separate input and record which QEMU option consumes it. The map in
`references/boot-stages.md` covers SPL, U-Boot, OpenSBI, TF-A, EDK2, pflash, ROM, and boot media.
Do not infer that a combined image contains the expected stage; inspect it as built.

## Input and DTB provenance

Hash every input before the run and record the hash in `audit.md`. For a DTB or generated FDT,
record the source DTS or generator and validate the properties the boot contract needs, for
example `msi-parent` and interrupt-controller nodes. A stale DTB is a known false negative: if
the input hashes differ from a previously verified run, classify the input change before blaming
the model. When the path needs separate kernel, initramfs, DTB, and firmware files, require them
to be the exact hashed artifacts, not copies of unknown age.

## Non-QEMU boot failure classification

Before changing QEMU or a model, classify the failure as environment or guest-side where the
evidence supports it:

- initramfs and init scripts: BusyBox `switch_root` requires PID 1, a different `st_dev` for the
  new root, and an `exec` that replaces PID 1; failures here are not device-model failures.
- stale or mismatched DTB, kernel, initramfs, or rootfs;
- root filesystem assumptions: wrong console, missing init, read-only or missing device nodes;
- host tooling and QEMU command mismatches.

When verifying persistence after a writable-root boot, remount the root filesystem read-only
before poweroff, then run the read-only filesystem check and read back the marker. A filesystem
check on a filesystem that was left writable can report pending journal state that is not boot
failure.

## Success criteria

Name the reached marker: kernel decompressed, init started, initramfs shell, login prompt,
workload completed, or Linux shell. Do not claim board or device correctness from a banner alone.

## Debug handoff

Narrow by path and stage first: for direct boot compare kernel command line, console, DTB,
initrd or rootfs, and machine options; for firmware boot compare image layout, firmware inputs,
boot media access, and handoff markers. Then add `-S -s` or another gdbstub backend, focused QEMU
log flags or trace events, and, only around a bounded PC window, instruction logs. The optional
`qemu-boot-run` skill documents the marker runner and serial-versus-diagnostics rule.

## Upstream references

- `docs/system/linuxboot.rst`
- `docs/system/invocation.rst`
- `docs/system/gdb.rst`
- `docs/devel/code-provenance.rst`

Paths can differ between QEMU versions; locate them in the checked-out tree.
