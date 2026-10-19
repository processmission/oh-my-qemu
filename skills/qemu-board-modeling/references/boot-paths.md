# Boot path reference

Use this reference when a board must support direct kernel boot, firmware boot,
or both. Treat the two paths as separate contracts with separate evidence; do
not infer one path's health from the other.

## The two contracts

Direct kernel boot: the machine loads the kernel image itself, typically through
an architecture helper (for ARM, `arm_load_kernel` in `hw/arm/boot.c`), using
`-kernel` plus optional `-initrd`, `-dtb`, and `-append`. QEMU prepares the FDT,
sets the entry exception level, and may install PSCI emulation.

Firmware boot: the machine provides `-bios` or ROM/flash regions and runs a
firmware image (U-Boot, TF-A, OpenSBI, EDK2) that finds and starts the kernel.
The board owns the firmware entry contract; the firmware owns the kernel
handoff.

## Direct boot rules

- Require `-kernel`. Accept `-dtb` only together with `-kernel`, and `-initrd`
  only when the kernel image supports it. If the machine does not synthesize a
  complete FDT, require `-dtb` whenever `-kernel` is used.
- Reject `-bios` combined with `-kernel` on a machine whose board code
  implements only one path; fail at realize with a clear error instead of
  ignoring one option.
- Record the entry exception level. For ARM Linux, the loader boots at EL2 when
  EL2 exists, otherwise EL1; firmware boot decides its own level.
- Choose the PSCI conduit deliberately. `arm_load_kernel` disables an SMC
  conduit when booting at EL3 and an HVC conduit when booting at EL2 because
  neither can work from that level; inspect the checked-out tree before
  claiming PSCI support.
- With SMP Linux and no PSCI, the loader needs its secondary-CPU boot stub; do
  not assume secondary CPUs start without one.
- Rewrite the FDT `/memory` node (or add `/memory@<base>`) in the board's
  `modify_dtb` hook when RAM extends beyond the low-memory window.
- Verify the FDT has the properties the devices under test require (for example
  `msi-parent` and an ITS node when MSI is under test); a stale or incomplete
  DTB is a known false-negative source.

## Firmware boot rules

- Model the real boot ROM or flash mapping the firmware writes to.
- Record the firmware artifact path, hash, and the load offset the board uses.
- If the firmware intentionally receives no FDT, model that intentionally; do
  not generate a fake FDT to make a boot log cleaner.
- Keep a documented way to select the boot medium (flash image, SD image, or
  network) and validate it as a machine property.

## Reset vector and init-svtor ownership

The machine owns boot entry: it passes RAM base and size to the loader, selects
the reset entry, and sets any loader-visible property such as ARMv7M
`init-svtor`. The SoC or CPU container exposes reset defaults; a device model
must not own boot entry. Record the chosen reset vector, init-svtor, and RAM
base in `audit.md`, with the source that justifies each value.

## Validate machine properties early

- Validate RAM size and alignment, RAM base, load addresses, init-svtor, and
  firmware offsets in realize with `error_setg`, not deep inside a load path.
- Check RAM and window overlap before mapping; report the conflicting ranges.
- Reject contradictory path selections (`-bios` with `-kernel`, `-dtb` without
  `-kernel`) in one place so both paths get the same rule.

## Dual-mode functional tests and assets

- Keep one subtest per boot path and record which path each subtest exercises.
- Direct boot needs separate files (kernel image, optional initrd, DTB); a
  firmware image or boot media is not a substitute for a kernel image.
- Pin asset hashes and re-derive them when the test changes; asset drift is a
  real false-failure source. When a functional test downloads assets, serve
  them locally and keep the URL and hash in the test.
- A passing run must show the configured marker or a falsifiable qtest result.
  A timeout or an empty serial log is INCONCLUSIVE, not PASS.

## Common failure signatures

- No serial output: check the console index and baud in the DTB or `-append`,
  the UART model wiring, and whether output went to a non-serial log.
- Firmware boots, kernel does not start: stale or incomplete DTB, wrong load
  address, PSCI or exception-level mismatch, or firmware handoff arguments.
- Direct boot works at one RAM size only: `/memory` node not rewritten for high
  RAM, or loader limits exceeded.
- SMP hangs after the first CPU: PSCI conduit disabled at the boot level and no
  secondary boot stub, or the interrupt controller has no per-CPU context.
- Kernel panic after early boot: often rootfs or initramfs, not the board;
  classify image and guest failures before editing the model.

Record the first failing stage and the evidence that locates it. Boot or
workload evidence is supplemental to qtests unless the user asked only for a
boot result.
