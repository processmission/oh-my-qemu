---
# SPDX-FileCopyrightText: Copyright (c) 2026 Process Mission
# SPDX-License-Identifier: MIT
name: qemu-qtest
description: Use for QEMU qtest design, registration, execution, debugging, and immediate evidence capture for device, board, QMP, timer, IRQ, DMA, and memory behavior.
---

# QEMU qtest

## Audit workflow

For non-trivial workspace writes, use a stable
`.oh-my-qemu/<task-slug>/` directory and create only needed entries:

```text
.oh-my-qemu/<task-slug>/
├── audit.md      # Baseline, scope, decisions, evidence, verification, and gaps
├── commands.md   # Redacted commands, working directories, and results
├── logs/         # Decisive build, test, runtime, or diagnostic logs
├── scripts/      # Temporary scripts, probes, parsers, and harnesses
└── output/       # Generated deliverables, dependencies, and non-QEMU binaries
```

Before changing source or mutable artifacts, record the workspace root,
revision, `git status --short`, pre-existing changes, goal, scope, and
acceptance checks in `audit.md`. Log exact redacted commands and results in
`commands.md`; record revisions, configurations, tool versions, and hashes when
they affect reproducibility. Separate observations from inferences and edit
source only when requested.

Keep QEMU builds under source-root `builds/build-<target>/`; put third-party
dependencies and non-QEMU binaries in task `output/`. Before writing audit
artifacts or configuring QEMU in a Git worktree, add `.agents/`,
`.oh-my-qemu/`, and `builds/` to the repository-local file from
`git rev-parse --git-path info/exclude`; preserve existing entries and avoid
duplicates. Never stage or commit those directories. At handoff, verify them
absent from `git status --short`. Report the task directory and unresolved gaps.

## QEMU upstream boundary

QEMU's official GitLab and mailing lists are upstream project channels. A
patch becomes an upstream contribution when sent to the mailing-list recipients
selected through `MAINTAINERS`; do not prepare or send agent-generated patches
for that submission. Local branches, commits, patch files, pushes, and pull
requests are not by themselves QEMU upstream contributions. Perform those Git
actions only when requested and follow the workspace's Git policy.

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

## Register model preflight

Before writing or running device qtests, or accepting their results, inspect
the model source and reconstruct its framework decision from current evidence.
Apply policy present in the target QEMU workspace first, compatible explicit
user direction only when policy does not decide, and a clear nearby subsystem
convention only when neither higher-priority input decides. Compare any
existing decision record with the result, but do not require a prior artifact.
For a non-trivial task that writes to the workspace, record the reconstructed
decision and rationale in `audit.md`.

Both `RegisterInfo` and manual MMIO callbacks are valid when selected by this
gate. Report a contradiction between the reconstructed decision and either the
implementation or an existing record, an unjustified implementation, or a
source-layout violation as a model-structure failure. Keep qtests behavioral:
exercise the guest-visible interface rather than coupling tests to the selected
framework.

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
- Testing overview: `docs/devel/testing/main.rst`.
- QTest docs: `docs/devel/testing/qtest.rst`.
- API: `tests/qtest/libqtest.h`.
