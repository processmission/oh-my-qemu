---
name: qemu-build
description: Use for configuring, reusing, building, or diagnosing named QEMU build directories under source-root builds/, including target-specific, debug, sanitizer, and trace configurations.
---

# QEMU Build

Use this operational skill when the task asks to inspect, configure, build, reconfigure, or diagnose a QEMU build.

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

This skill owns build-directory selection, configure/build commands, build
logs, and build-failure diagnosis. Keep task audit records under
`.oh-my-qemu/<task-slug>/` and QEMU-generated files under `builds/`.

## Hard policy boundary

Do not produce source code intended for QEMU upstream submission. Do not add DCO or review trailers.

## Build directory rule

Use a descriptive directory under source-root `builds/` for every QEMU
configuration. Derive the name from the target and important variant, for
example:

- `builds/build-aarch64/`;
- `builds/build-riscv64-debug/`;
- `builds/build-x86_64-asan/`.

Do not configure QEMU in `build/`, the source root, or the task `output/`
directory. Reuse a named build only when its recorded configuration matches the
task.

Before creating or reconfiguring anything, inspect:

- `<build-dir>/config.log` for the configure command;
- `<build-dir>/build.ninja` for configured state;
- `<build-dir>/pyvenv/bin/meson` for Meson commands;
- `<build-dir>/meson-logs/meson-log.txt` for configure failures;
- `<build-dir>/meson-info/intro-buildoptions.json` for options.

Create another named directory for a materially different target or
configuration, such as sanitizer versus non-sanitizer.

## Configure

From the QEMU source root:

```bash
mkdir -p builds/build-aarch64
cd builds/build-aarch64
../../configure --target-list=aarch64-softmmu
```

Common targets:

- `x86_64-softmmu`
- `aarch64-softmmu`
- `riscv64-softmmu`
- `loongarch64-softmmu`
- `x86_64-linux-user`
- `aarch64-linux-user`

Useful options:

- `--enable-debug`
- `--enable-debug-info`
- `--enable-trace-backends=log`
- `--enable-asan`
- `--enable-tsan`
- `--enable-ubsan`

From that build directory, use `../../configure --help` for the checked-out
QEMU version.

## Reconfigure safely

Reconstruct the old command from `<build-dir>/config.log`, then change only the
needed option.

Preserve:

- target list unless the task changes it;
- debug/sanitizer/trace options;
- dependency/accelerator options;
- build directory evidence until diagnosis is complete.

Do not delete a named build directory merely to make an error disappear. Keep
its decisive logs until the failure is classified.

## Build

From the source root:

```bash
ninja -C builds/build-aarch64
```

Prefer narrow targets when possible:

```bash
ninja -C builds/build-riscv64 qemu-system-riscv64
ninja -C builds/build-riscv64 tests/qtest/<test-name>
```

Use verbose mode only for diagnosis:

```bash
ninja -C builds/build-riscv64 -v <target>
```

## Failure classification

- Configure: missing dependency, unsupported option, Python/Meson issue, compiler mismatch.
- Compile: API/type/include/feature guard mismatch.
- Link: missing object in Meson, missing dependency, target-specific source not linked.
- Generated source: QAPI, trace-events, decodetree, or Meson generator input.
- Toolchain/host: sanitizer or compiler incompatibility.

For generated-source failures, fix the generator input, not generated files in
`builds/build-<target>/`.

## Report

Write/report:

- PASS/FAIL/INCONCLUSIVE;
- source root and build dir;
- exact command;
- target list and key options;
- decisive failure excerpt;
- full log paths under `.oh-my-qemu/<task-slug>/`;
- what the build proves.

## Upstream references

- QEMU code provenance and AI policy: `docs/devel/code-provenance.rst`.
- QEMU RFC `qemu-build` skill.
- Testing overview: `docs/devel/testing/main.rst`.
