# Boot stages and artifact mapping

Use this reference when a Linux boot traverses firmware or bootloader stages, or when a task must
map artifacts to QEMU options. Record the selected stages, markers, hashes, and gates in
`audit.md` and the exact commands in `commands.md`.

## Default firmware stage list

Stages, in order, with the evidence to record and the gate for that round:

1. Reset vector or ROM entry. Marker: first firmware console line. Evidence: QEMU command, ROM
   and pflash inputs. Gate: the run reaches the first console line.
2. Early loader (SPL or TPL). Marker: loader version or DRAM init message. Evidence: loader
   artifact hash and load offset. Gate: the loader transfers control.
3. Trusted firmware or monitor (TF-A/BL31, OpenSBI, vendor monitor). Marker: monitor version or
   handoff message. Evidence: dependency revision, hash, packaging offset. Gate: handoff.
4. Bootloader (U-Boot or vendor). Marker: prompt, autoboot line, version string. Evidence:
   bootloader hash, environment, media. Gate: the bootloader reads the boot media.
5. Boot media access. Marker: a read or load message. Evidence: media layout, offsets, hashes.
   Gate: the kernel payload read succeeds.
6. Kernel entry. Marker: `Starting kernel` or the machine's equivalent. Evidence: kernel image
   hash, bootargs, DTB hash. Gate: the kernel starts executing.
7. Linux console and init. Marker: kernel version, init or shell line. Evidence: full serial log
   and DTB properties. Gate: the init or shell marker is reached.
8. Root filesystem or shell reachability. Marker: login prompt or workload marker. Evidence:
   rootfs/initramfs hash and write policy. Gate: the workload marker is reached.
9. Documentation. Marker: the documentation page builds. Evidence: docs source path and
   validation command. Gate: the docs validation passes.

Markers are examples: choose them from the actual firmware and record the exact text. A banner
alone is not proof of the next stage. Direct boot skips stages 1-5; its gate is kernel entry
followed by the Linux console. Do not require firmware markers on a direct-boot run.

## Dual-path contract

| Concern | Direct boot | Firmware boot |
| --- | --- | --- |
| Kernel loading | QEMU loads the kernel | firmware loads the kernel |
| DTB | QEMU option or generated FDT | firmware-provided DTB |
| Initrd/rootfs | QEMU option or block backend | boot media payload |
| Required artifacts | kernel, DTB, initrd/rootfs | firmware, bootloader, media |
| Failure ownership | command, kernel, DTB, rootfs | layout, firmware, media, handoff |
| Acceptance | Linux milestone | handoff markers plus Linux milestone |

## Artifact to QEMU option map

| Artifact | Usual consumer | Record |
| --- | --- | --- |
| SPL or early loader | ROM or pflash path | hash, expected load address |
| U-Boot proper | pflash, `-bios`, or boot media | hash, offset, entry |
| OpenSBI | firmware path or `-bios` | hash, next-stage expectation |
| TF-A/BL31 | firmware path, FIP, or pflash | revision, hash, offset |
| EDK2 | pflash code and variable store | both volumes, write policy |
| Kernel image | `-kernel` or media payload | hash, expected image format |
| DTB | `-dtb` or firmware-loaded DTB | hash, required properties |
| initrd or initramfs | `-initrd` or media payload | hash, compression, offset |
| Root filesystem | block backend or boot media | format, layout, write policy |
| Boot media image | `-drive`, pflash, SD/eMMC model | layout, offsets, hash |

The exact option depends on the machine model. Inspect the checked-out machine's documentation
and source; do not assume an option exists in every version.

## Round gates and final acceptance

For each round, record the stage being advanced, the expected marker, the gate that decides
success for this round, and the next handoff stage it unlocks. The final acceptance criterion is
the task's Linux milestone, not the round gate; a round can pass its own gate while the task
stays INCONCLUSIVE.

Replan mid-round when several independent blockers appear, when evidence moves the task to a new
stage, or when a hypothesis is invalidated. Record the reason, the new gate, and the unchanged
final acceptance criterion. Do not silently expand one round to cover several stages.

## Record stage evidence

Copy [boot evidence template](../assets/boot-evidence-template.md) into the task directory and
fill one row per stage reached or attempted: stage, expected marker, evidence path and line,
reached or not, round gate, and next blocker. Record the final acceptance status separately from
the per-stage gates, and delete rows that do not apply to the selected boot path.

## Failure classification

| First failing point | Likely category | Next check |
| --- | --- | --- |
| no first console line | QEMU command, ROM inputs | machine options, artifact identity |
| loader runs, no handoff | image layout, load address | byte-compare at documented offset |
| monitor prompt absent | dependency, environment | TF-A/OpenSBI input, console route |
| media read fails | media layout, block model | offset map, readback |
| no kernel entry line | image format, DTB, bootargs | hashes, DT properties, command line |
| no init or login | rootfs, initramfs, console | init script, console and root= |
| `switch_root` failure | init script, guest side | PID 1, `st_dev`, `exec` usage |
| persistence check fails | write policy, poweroff | remount read-only, then check |
