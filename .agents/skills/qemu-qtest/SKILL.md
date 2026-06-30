---
name: qemu-qtest
description: Use for QEMU qtest design, registration, execution, and debugging. Extends qemu-flow-plan; qtest evidence and logs stay under a .oh-my-qemu task workspace.
---

# QEMU qtest

Use this operational/domain skill for QEMU device and board tests using the qtest framework.

## Flow relationship

- Use `qemu-flow-plan` to define the behavior claim and artifact root.
- Use `qemu-build` before running qtests if binaries are stale or missing.
- Use `qemu-rlcr-loop` when qtest findings drive iterative source changes.
- Store test logs, copied command lines, and debug notes under `.oh-my-qemu/<task-slug>/`.

## Hard policy boundary

Do not produce source code intended for QEMU upstream submission. Do not add DCO or review trailers.

## What qtest should prove

Use qtest for:

- MMIO/PIO register contracts;
- reset behavior;
- IRQ assertion/deassertion;
- virtual clock/timer behavior;
- QMP-visible state and hotplug;
- board instantiation and memory-map probes;
- simple DMA or guest-memory effects.

Prefer qtest over boot smoke for device contracts.

## Running qtests

Run from a configured build directory. Default to `build/`.

List tests:

```bash
build/pyvenv/bin/meson test -C build --list
```

Run one test:

```bash
build/pyvenv/bin/meson test -C build qtest-riscv64/<test-name>
```

Make frontends from inside `build/`:

```bash
make check-qtest
make check-qtest-riscv64
V=1 make check-qtest-riscv64
```

Use the narrow Meson test name when possible.

## Finding/registering tests

Inspect:

- `tests/qtest/meson.build` for architecture buckets;
- `tests/qtest/<name>.c` for source;
- `tests/qtest/libqtest.h` for API;
- `build/meson-logs/testlog.txt` for failures.

Register architecture-specific tests under the matching `qtests_<arch>` list. Use `qtests_generic` only when the test is truly architecture-independent.

## Useful libqtest APIs

- startup/shutdown: `qtest_init()`, `qtest_initf()`, `qtest_quit()`;
- reset: `qtest_system_reset()`;
- QMP/HMP: `qtest_qmp()`, `qtest_qmp_assert_success()`, `qtest_qmp_eventwait()`, `qtest_hmp()`;
- MMIO: `qtest_readb/readw/readl/readq()`, `qtest_writeb/writew/writel/writeq()`;
- memory: `qtest_memread()`, `qtest_memwrite()`, `qtest_memset()`;
- PIO: `qtest_inb/inw/inl()`, `qtest_outb/outw/outl()`;
- IRQ: `qtest_irq_intercept_in()`, `qtest_irq_intercept_out()`, `qtest_set_irq_in()`;
- virtual clock: `qtest_clock_step_next()`, `qtest_clock_step()`, `qtest_clock_set()`.

Use libqos/qgraph when nearby subsystem tests already do.

## Device qtest checklist

- reset values;
- masks and reserved bits;
- read-only/write-only/W1C behavior;
- unsupported width behavior when guest-visible;
- IRQ level and clear path;
- virtual-clock timer expiry;
- DMA guest-memory effects;
- dirty-state reset.

## Debugging qtests

Qtest environment variables include:

- `QTEST_QEMU_BINARY`
- `QTEST_QEMU_ARGS`
- `QTEST_QEMU_IMG`
- `QTEST_QEMU_STORAGE_DAEMON_BINARY`
- `QTEST_STOP`
- `QTEST_LOG`

Use verbose test output to recover exact commands. Use `QTEST_STOP=1` when attaching a debugger to spawned QEMU is needed.

## Portability rules

- Use GLib temp/file APIs.
- Avoid hardcoded `/tmp`.
- Avoid POSIX-only paths unless guarded.
- Use double quotes in extra QEMU command-line strings.
- Open binary files in binary mode when data comparison matters.

## Report

Include:

- PASS/FAIL/INCONCLUSIVE;
- build dir;
- exact command;
- qtest name;
- decisive excerpt;
- log path;
- behavior proven and not proven.

## Upstream references

- QEMU code provenance and AI policy: `docs/devel/code-provenance.rst`.
- QEMU RFC `qemu-testing` skill.
- Testing overview: `docs/devel/testing/main.rst`.
- QTest docs: `docs/devel/testing/qtest.rst`.
- API: `tests/qtest/libqtest.h`.
