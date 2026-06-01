---
name: qemu-qtest
description: Use when writing, running, listing, or debugging QEMU qtests for device and board emulation. Covers build-directory execution, Meson test names, libqtest/libqos APIs, MMIO/QMP/IRQ/clock checks, and portable test registration.
license: GPL-2.0-or-later
---

# QEMU qtest

Use this skill when the task involves QEMU qtests: adding a device/board test, running a focused qtest from a build directory, debugging a qtest failure, or deciding what qtest coverage a hardware-model change needs.

## Hard policy boundary

Do not produce source code intended for QEMU upstream submission. QEMU currently declines contributions believed to include or derive from AI-generated content. You may help with test design, failure analysis, and local verification. Do not add `Signed-off-by` or any DCO-style trailer.

## What qtest is for

QTest is QEMU's device emulation testing framework. It is appropriate for:

- MMIO/PIO register read/write behavior;
- reset values and reset side effects;
- IRQ assertion/deassertion;
- virtual clock/timer behavior;
- QMP-visible device state and hotplug operations;
- board creation and key memory-map probes;
- small DMA or guest-memory effects that do not require a full guest OS.

Prefer qtest over firmware boot tests for register contracts. Boot tests prove integration; qtests prove device behavior.

## Build-directory execution rule

Run qtests from a configured QEMU build directory. Default to `build/` unless the repository clearly uses another directory.

Before running qtests:

1. Ensure the relevant QEMU binary is built. Use the `qemu-build` skill if not.
2. Inspect available Meson tests from the build directory.
3. Run the narrowest test name that covers the change.
4. Use `V=1` or Meson verbose/log output only when diagnosing failure.

Common commands from the source root:

```bash
ninja -C build
build/pyvenv/bin/meson test -C build --list
build/pyvenv/bin/meson test -C build qtest-riscv64/<test-name>
```

Common make frontends from `build/`:

```bash
make check-qtest
make check-qtest-riscv64
make check-qtest-aarch64
V=1 make check-qtest-riscv64
```

Use the Meson test name when possible because it is narrow and has better result/log integration.

## Finding the right qtest name

Look in:

- `tests/qtest/meson.build` for registration and architecture buckets;
- `build/pyvenv/bin/meson test -C build --list` for actual runnable names;
- `tests/qtest/<name>.c` for source;
- `build/meson-logs/testlog.txt` and per-test logs for failure details.

QEMU Meson qtest names usually look like:

- `qtest-x86_64/<test-name>`
- `qtest-aarch64/<test-name>`
- `qtest-riscv64/<test-name>`

The source filename usually omits the architecture prefix and often ends in `-test.c`.

## Adding or extending a qtest

When designing qtest coverage, write down the exact behavior claim first.

Steps:

1. Create or extend `tests/qtest/<device-or-board>-test.c`.
2. Use GLib test functions and libqtest/libqos helpers matching nearby tests.
3. Register the executable in `tests/qtest/meson.build` under the right architecture list:
   - architecture-specific `qtests_<arch>` for machine/device dependencies;
   - `qtests_generic` only when it is truly architecture-independent.
4. Add dependencies in the `qtests` dictionary only when the test needs more than the default `qemuutil`/`qos` style dependencies.
5. Build the test target and run the narrow qtest name.

Do not add a qtest to every architecture just because it compiles. Register it where the tested machine/device exists.

## Useful libqtest APIs

The API is declared in `tests/qtest/libqtest.h`; inspect it in the checked-out QEMU tree for exact signatures.

Common groups:

- startup/shutdown: `qtest_init()`, `qtest_initf()`, `qtest_quit()`, `qtest_kill_qemu()`;
- system reset: `qtest_system_reset()`, `qtest_system_reset_nowait()`;
- QMP/HMP: `qtest_qmp()`, `qtest_qmp_assert_success()`, `qtest_qmp_eventwait()`, `qtest_hmp()`;
- MMIO: `qtest_readb/readw/readl/readq()`, `qtest_writeb/writew/writel/writeq()`, `qtest_memread()`, `qtest_memwrite()`, `qtest_memset()`;
- PIO: `qtest_inb/inw/inl()`, `qtest_outb/outw/outl()`;
- IRQ: `qtest_irq_intercept_in()`, `qtest_irq_intercept_out()`, `qtest_irq_intercept_out_named()`, `qtest_set_irq_in()`;
- virtual clock: `qtest_clock_step_next()`, `qtest_clock_step()`, `qtest_clock_set()`;
- device hotplug helpers: `qtest_qmp_device_add()`, `qtest_qmp_device_del()`.

Use libqos/qgraph when the existing subsystem tests do so, especially for PCI, virtio, storage, or bus-driver style tests.

## Device-model qtest checklist

For MMIO/SysBus devices, cover:

- reset values before writes;
- writable masks and reserved bits;
- read-only and write-one-clear bits;
- unsupported access width behavior if guest-visible;
- side-effect ordering;
- IRQ raise, hold, and clear paths;
- timer behavior with virtual clock stepping;
- DMA effects on guest memory;
- reset after dirty state;
- migration-relevant state if the device is migratable.

For board tests, cover:

- machine creation with minimal arguments;
- key MMIO bases respond as expected;
- interrupt controller path for at least one source when practical;
- firmware-visible topology only if qtest can observe it without a full boot.

## Debugging qtest failures

QTests often rely on environment variables set by the build system, including:

- `QTEST_QEMU_BINARY`
- `QTEST_QEMU_ARGS`
- `QTEST_QEMU_IMG`
- `QTEST_QEMU_STORAGE_DAEMON_BINARY`
- `QTEST_STOP`
- `QTEST_LOG`

Use `V=1 make check-qtest...` or Meson verbose/log output to recover the exact command and environment.

For debugger attachment:

- Use `QTEST_STOP=1` when appropriate so the spawned QEMU stops before continuing.
- Re-run the extracted command manually if the harness needs direct gdb control.
- Add temporary trace events or `--trace` patterns only for diagnosis.

Classify failures before editing code:

- stale or missing QEMU binary;
- wrong qtest architecture bucket;
- bad command-line args;
- test assumes host-specific path behavior;
- guest-visible model bug;
- timing issue caused by using real time instead of virtual clock.

## Portability rules

QEMU qtests should be portable across POSIX and Windows hosts unless deliberately restricted:

- use GLib temporary directory/file APIs;
- avoid hardcoded `/tmp`;
- avoid shell-only redirection assumptions;
- avoid POSIX-only paths such as `/dev/null` unless guarded;
- use double quotes in extra QEMU command-line strings;
- open binary data with binary mode where relevant;
- guard Linux/POSIX-only cases explicitly.

## Reporting format

Report qtest results with:

- PASS/FAIL/INCONCLUSIVE;
- build directory;
- exact Meson or make command;
- qtest name;
- decisive failure excerpt;
- full log path;
- behavior proven by the test;
- behavior not covered.

## Upstream references

- QEMU upstream RFC skill reference: `.agents/skills/qemu-testing/SKILL.md` from the qemu-devel “AGENTS.md and associated skills” series.
- QEMU testing overview: `docs/devel/testing/main.rst`.
- QTest framework docs: `docs/devel/testing/qtest.rst`.
- QTest API: `tests/qtest/libqtest.h`.
- QTest registration: `tests/qtest/meson.build`.
- QEMU code provenance and AI policy: `docs/devel/code-provenance.rst`.
