# QEMU debug playbooks

Ladders and recipes for failures that need more than one command. Run from the
QEMU source root with a named build directory. Placeholders use <...>.

## Host-process crash

1. Reproduce with the same binary and command line; record both.
2. Run under `gdb --args builds/build-<target>/qemu-system-<arch> ...` or
   attach `gdb -p <pid>`, then `thread apply all bt full`; capture the
   asserting frame and `info registers`.
3. Enable core dumps before rerunning (`ulimit -c unlimited`); record the core
   path and the signal.
4. For memory corruption, rebuild with ASAN/TSAN and rerun the narrow
   reproducer; record the configure options.
5. Minimize the command line while the failure persists.
6. Only then read and instrument the suspected source path.

Do not patch QEMU before the failure is classified.

## Device and board bring-up

1. Confirm image, machine options, and command line; hash the image.
2. Measure unimplemented access (below).
3. Run the narrow qtest for the MMIO/IRQ path when one exists.
4. Enable targeted trace events for the device and compare the guest-visible
   sequence with the register contract.
5. Check reset state and interrupt routing before interpreting a full boot log.
6. Then make one narrow, evidence-backed model change per round.

An unimplemented window that logs is evidence of guest access, not of modeled
behavior; a diagnostic sink is not modeled success.

## Unimplemented-map measurement

```bash
QEMU=builds/build-<target>/qemu-system-<arch>
$QEMU -M <machine> <boot args> -nographic \
  -d unimp,guest_errors -D .oh-my-qemu/<task-slug>/logs/unimp.log
```

- Group logged addresses by window/page and count unique windows.
- Compare with the declared unimplemented map and with `info mtree`/`info qtree`
  from `-monitor stdio`.
- Record counts, the command, and the log path in `audit.md`; keep raw logs
  under `logs/`.

## TCG frontend and backend

1. Reproduce under `-accel tcg` and record the guest code path.
2. For instruction-boundary bugs use `-accel tcg,one-insn-per-tb=on`.
3. Dump translation with `-d in_asm,op,op_opt,cpu`; add `out_asm` for host
   code.
4. Frontend suspects: decode/translate, feature gates, PC/TB state, helper
   side-effect flags.
5. Backend suspects: constraints and optional flags, register allocation, host
   code for one TB.
6. Reduce to one instruction or one TB before editing; attribute the fix to
   frontend or backend.

Background: `docs/devel/tcg.rst` and `docs/devel/tcg-ops.rst`. The
qemu-tcg-frontend/backend skills are optional context.

## KVM guard

A machine that cannot model a KVM vCPU combination must refuse it, not run it
wrongly:

```c
if (kvm_enabled()) {
    error_report("<machine>: KVM is not supported for this machine");
    exit(1);
}
```

- Checked-out pattern: `hw/arm/sbsa-ref.c` refuses KVM for its machine.
- Rationale: KVM owns vCPU state, reset/EL configuration, and CPU topology; a
  machine that needs heterogeneous CPU types or custom reset state cannot
  reproduce it under KVM.
- PSCI: the checked-out `hw/arm/virt.c` selects HVC when the guest runs
  without EL2 and comments that "if we're using KVM then we must use HVC"; a
  KVM-enabled machine must not require an SMC-only PSCI path. Verify the
  conduit decision in the checked-out machine before asserting it.
- Record the guard and the tested accelerator combinations in `audit.md`.

## CPU pointers in machine state

Resolve CPU objects during realize/init and store them in the SoC or board
state; use those stored pointers for wiring. `qemu_get_cpu(index)` resolves by
global `cpu_index` (`include/hw/core/cpu.h`), so it hides ordering assumptions
in hot paths and after CPU hotplug; use it only for a lookup-by-index whose
ordering assumption is checked.

## GIC interrupt count

`num-irq` counts all interrupts including the 32 private ones: "First 32 are
private to each CPU (SGIs and PPIs)" (`include/hw/intc/arm_gic_common.h`,
`GIC_INTERNAL`); SPIs start at 32.

- TRM lists N SPI lines: `num-irq = N + 32`.
- TRM lists N total interrupt lines: SPIs = N - 32 and `num-irq = N`.
- Checked-out: `DEFINE_PROP_UINT32("num-irq", ..., 32)` in
  `hw/intc/arm_gic_common.c`.
- A 480-versus-512 disagreement is usually this convention mismatch; report it
  with the manual page and the boot log instead of hiding it.

## Replay and reverse debugging

QEMU's own reverse execution runs over a record/replay log through the
gdbstub; it is not a host-level tool such as rr.

1. Record: `-icount shift=auto,rr=record,rrfile=replay.bin` with replay
   filters for block and network devices as the checked-out
   `docs/system/replay.rst` requires.
2. Replay: `-icount shift=auto,rr=replay,rrfile=replay.bin`; add
   `rrsnapshot` on both command lines (or accept the temporary
   `start_debugging` snapshot).
3. Attach the gdbstub (`-s` or `-gdb dev`) and connect with GDB, then use
   `reverse-stepi` (`rsi`) and `reverse-continue` (`rc`).
4. Monitor `info replay` reports replay mode and current icount;
   `savevm`/`loadvm` manage snapshots.

Verify in this QEMU version: reverse execution depends on the gdbstub and the
replay snapshot support present in the checked-out tree; confirm `info replay`
in `hmp-commands-info.hx` and the supported commands in
`docs/system/replay.rst` before relying on a command in a report.
