---
name: qemu-qtest
description: Use for QEMU qtest design, registration, execution, debugging, and immediate evidence capture for device, board, QMP, timer, IRQ, DMA, and memory behavior.
---

# QEMU qtest

Use this operational/domain skill for QEMU device and board tests using the qtest framework.

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

## Scope

This skill owns qtest design, registration, execution commands, and
immediate qtest evidence for a named QEMU build under `builds/`.

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

Run from the named build directory that matches the target, such as
`builds/build-riscv64/`. Do not fall back to an unqualified `build/`.

List tests:

```bash
builds/build-riscv64/pyvenv/bin/meson test \
  -C builds/build-riscv64 --list
```

Run one test:

```bash
builds/build-riscv64/pyvenv/bin/meson test \
  -C builds/build-riscv64 qtest-riscv64/<test-name>
```

Make frontends can target the same directory:

```bash
make -C builds/build-riscv64 check-qtest
make -C builds/build-riscv64 check-qtest-riscv64
V=1 make -C builds/build-riscv64 check-qtest-riscv64
```

Use the narrow Meson test name when possible.

## Finding/registering tests

Inspect:

- `tests/qtest/meson.build` for architecture buckets;
- `tests/qtest/<name>.c` for source;
- `tests/qtest/libqtest.h` for API;
- `builds/build-<target>/meson-logs/testlog.txt` for failures.

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
