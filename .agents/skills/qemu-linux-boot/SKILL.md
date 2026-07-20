---
name: qemu-linux-boot
description: Use for booting Linux in QEMU through either direct kernel loading or firmware and bootloader stages, selecting the path from task inputs while preserving provenance, boot logs, debug handoff, and verification evidence.
---

# QEMU Linux Boot

Use this workflow when the task is to boot Linux under QEMU and the request may
need either direct kernel loading or a firmware/bootloader chain.

## Audit workflow

For every non-trivial task that writes to the workspace, choose a stable task
slug and keep all agent-only records under `.oh-my-qemu/<task-slug>/`. Create
only the entries the task needs:

```text
.oh-my-qemu/<task-slug>/
├── audit.md      # Baseline, scope, decisions, evidence, verification, and gaps
├── commands.md   # Redacted commands, working directories, and results
├── logs/         # Decisive build, test, runtime, or diagnostic logs
├── scripts/      # Temporary scripts, probes, parsers, and harnesses
└── output/       # Generated deliverables, dependencies, and non-QEMU binaries
```

Before changing source or mutable artifacts, record the workspace root,
branch/revision, `git status --short`, user-owned dirty paths, goal, scope, and
acceptance checks in `audit.md`. Record exact redacted commands and results in
`commands.md`; record source revisions, configurations, tool versions, and
input/output hashes when they affect reproducibility. Separate observations
from inferences and create or change source files only when requested.

Put every QEMU build in a named directory under the QEMU source root, such as
`builds/build-aarch64/`. Put third-party dependency artifacts and non-QEMU
binaries under the task's `output/` directory. In a Git worktree, before
writing audit records or configuring QEMU, add `.agents/`, `.oh-my-qemu/`, and
`builds/` to the repository-local exclude file returned by
`git rev-parse --git-path info/exclude`; preserve existing entries and avoid
duplicates. Never stage or commit those directories. Before handoff, verify
that `git status --short` contains none of them, then report the task directory
and unresolved gaps.

## Path Selection

Classify the boot path before composing primitives:

- Use **direct Linux boot** when QEMU should load the kernel itself with options
  such as `-kernel`, `-dtb`, `-initrd`, and `-append`, without traversing
  firmware or bootloader stages.
- Use **firmware Linux boot** when Linux must be reached through BIOS, pflash,
  ROM, SPL, TPL, U-Boot, TF-A, EDK2, OpenSBI, vendor firmware, or boot media
  that firmware reads.
- If the user explicitly names a path, follow that path.
- If the request only asks for a fast Linux smoke boot and provides a kernel,
  prefer direct boot.
- If the request is validating a board's real boot chain, firmware behavior, or
  boot media layout, prefer firmware boot.
- If required artifacts are missing or the path is ambiguous, record the gap in
  `audit.md` before running QEMU.

## Workflow

1. Freeze the selected boot path, named success marker, allowed writes, and
   acceptance checks in `audit.md`.
2. Record the identity and hash of QEMU, kernel, DTB, initrd/rootfs, firmware,
   bootloader, and boot-media inputs that the selected path consumes.
3. For writable media, record its layout and mutation/refresh policy before
   running QEMU.
4. Construct one copy-pasteable QEMU command, capture the full console log, and
   record timeout, exit status, positive markers, and negative markers.
5. If boot fails, isolate the first failing stage with the narrowest reversible
   debug probe before changing source or artifacts.
6. Report the exact Linux milestone as `PASS`, `FAIL`, or `INCONCLUSIVE`, plus
   what the evidence does and does not prove.

The selected path determines the boot contract; do not run both paths unless
the task explicitly asks for comparison or fallback evidence.

## Direct Boot Contract

Record these inputs:

- QEMU binary and machine name;
- CPU, SMP, memory, accelerator, and machine properties;
- kernel image type expected by the target architecture;
- DTB path or generated FDT policy;
- initrd or block rootfs path;
- kernel command line, especially `console=`, `root=`, `rdinit=`, `init=`,
  and early console settings;
- expected marker, such as a shell prompt, init banner, or workload output.

Direct boot command rules:

- Keep the command copy-pasteable.
- Route serial output deterministically, usually with `-nographic`.
- Include a timeout for non-interactive smoke tests.
- Store the full console log under `.oh-my-qemu/<task-slug>/logs/`.
- When the goal is an interactive shell, provide the exact command separately
  from the timed smoke command.

## Firmware Boot Contract

Record these inputs:

- firmware, bootloader, kernel, DTB, rootfs, and QEMU inputs;
- boot media, pflash, ROM, or disk image expectations;
- serial markers for each firmware handoff stage;
- the first failing stage when boot stalls;
- the reached Linux milestone when boot succeeds.

Record each expected stage and marker:

- reset vector or ROM entry;
- first firmware console output;
- SPL/TPL or early loader milestone;
- trusted firmware or monitor handoff if present;
- bootloader prompt or autoboot path;
- boot media access;
- kernel entry;
- Linux console and rootfs or shell marker.

Firmware command rules:

- Keep firmware inputs and boot media inputs distinct in the command record.
- Record firmware environment assumptions and any interactive bootloader
  commands.
- Use disposable or refreshed images when firmware writes runtime state.
- Capture the entire serial log; summarize the first failing stage in
  `audit.md`.
- If Linux uses a different console from firmware, state which QEMU chardev
  carries each log.

## Stage Milestones

For firmware implementation or debugging work, expose the stage checklist as
explicit milestones that an outer workflow can consume. The final Linux shell
or full boot result is the final acceptance criterion, not the default first
milestone.

Default firmware round boundaries are:

- reset vector or ROM entry;
- early firmware services;
- SPL/TPL or early loader milestone;
- trusted firmware or monitor handoff if present;
- bootloader entry or autoboot path;
- boot media access;
- kernel entry;
- Linux console and rootfs or shell marker;
- documentation or handoff notes.

Each milestone must name:

- the expected serial, trace, or debugger marker;
- the current verification gate;
- the next firmware handoff stage it unlocks.

By default, a single debugging or implementation step should not span more
than one firmware handoff stage. If it must cross stages, record why before
making changes.

## Success Criteria

Boot success should name the marker reached. Examples: kernel decompressed,
init started, initramfs shell, login prompt, workload completed, or Linux shell.
Do not claim board or device correctness from a banner alone.

## Debug Handoff

For timeouts, narrow by path and stage before changing source:

- for direct boot, compare kernel command line, console, DTB, initrd/rootfs,
  and machine options before assuming model behavior is wrong;
- for firmware boot, compare image layout, firmware inputs, boot media access,
  and handoff markers before assuming model behavior is wrong;
- add `-S -s` or another gdbstub backend for guest state;
- add focused QEMU log flags or trace events;
- use instruction logs only around a bounded PC window when possible.
