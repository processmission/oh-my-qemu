---
# SPDX-FileCopyrightText: Copyright (c) 2026 Process Mission
# SPDX-License-Identifier: MIT
name: qemu-qtest
description: Use for QEMU qtest design, registration, execution, debugging, and immediate evidence capture for device, board, QMP, timer, IRQ, DMA, and memory behavior.
---

# QEMU qtest

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

## What qtest should prove

Use qtest for MMIO/PIO register contracts, reset behavior, IRQ
assertion/deassertion, virtual-clock and timer behavior, QMP-visible state and
hotplug, board instantiation and memory-map probes, and simple DMA or
guest-memory effects. Prefer qtest over boot smoke for a device contract.

A qtest proves only what its assertions read. A test that reads the wrong
address can hide a model bug. Copyable recipes are in
[qtest patterns](references/patterns.md).

## Run from the QEMU source root

Address the build directory explicitly; never rely on an unqualified `build/`:

```bash
builds/build-<target>/pyvenv/bin/meson test \
  -C builds/build-<target> --list
builds/build-<target>/pyvenv/bin/meson test \
  -C builds/build-<target> qtest-<arch>/<test>
builds/build-<target>/pyvenv/bin/meson test \
  -C builds/build-<target> -v qtest-<arch>/<test>
```

Inside the build directory the equivalent is `pyvenv/bin/meson test
qtest-<arch>/<test>`. The Makefile wrappers take the same build directory:
`make -C builds/build-<target> check-qtest-<arch>`. Meson registers a test as
`qtest-<arch>/<name>`, where `<arch>` is the target without `-softmmu`
(`tests/qtest/meson.build`).

## Find, register, and run

- `tests/qtest/meson.build` owns registration; put architecture-specific tests
  in `qtests_<arch>` and only truly generic ones in `qtests_generic`.
- `tests/qtest/<name>.c` is the source and `tests/qtest/libqtest.h` the API.
- `builds/build-<target>/meson-logs/testlog.txt` has failure detail.
- Run the narrow test name first; widen only when needed.
- Plan the assertions and evidence with the
  [qtest plan template](assets/qtest-plan-template.md) before writing code.
- After editing, run the skill's `scripts/check-registration.sh --help` (or
  with `--meson`, `--source`, `--arch`) to check registration, bucket, and
  lifecycle.

## Verify APIs before authoring

libqtest names and helpers change between QEMU versions. Locate every call you
use in the checked-out `tests/qtest/libqtest.h` and nearby tests; do not write
an API from memory. When a helper is absent, use a QMP command that exists in
this tree or the qtest protocol through a checked-out helper.

## Author before the machine builds

When the machine or device does not build yet, syntax-check only the new test:
take a sibling qtest's compile command from
`builds/build-<target>/compile_commands.json`, replace the source file with the
new one, add `-fsyntax-only`, run it from the build directory, and record the
command. Register the test in `tests/qtest/meson.build` in the same change and
build it for real before claiming a PASS.

## Framework preflight

Read the model source and know its register framework and unimplemented
windows before writing or accepting a device qtest. Keep tests behavioral:
exercise the guest-visible interface, not the selected framework. Report a
contradiction between model and register contract as FAIL or INCONCLUSIVE with
citations, not as a test-only problem; record the verdict and what evidence
would change it in `audit.md`.

## Tests are requested scope

Add tests when the user asks or the acceptance criteria require them; do not
expand a fix-only request into a test mandate. When the user drops a requested
test, remove it and its registration cleanly, and record the change.

## Report

Record PASS, FAIL, or INCONCLUSIVE with the build directory, exact command,
test name, decisive excerpt, log path, and what the run does and does not
prove. Keep logs under `.oh-my-qemu/<task-slug>/logs/`.

## Upstream references

- QEMU code provenance and AI policy: `docs/devel/code-provenance.rst`.
- Testing overview: `docs/devel/testing/main.rst`.
- QTest docs: `docs/devel/testing/qtest.rst`.
- Build and test invocation: `docs/devel/build-system.rst`.
- API: `tests/qtest/libqtest.h`.
- Registration: `tests/qtest/meson.build`.

Paths can differ between QEMU versions; locate them in the checked-out tree.
