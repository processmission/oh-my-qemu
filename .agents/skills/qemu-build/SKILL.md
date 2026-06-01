---
name: qemu-build
description: Use when configuring, reconfiguring, building, or diagnosing build failures in QEMU. Assumes the common out-of-tree build directory is `build/`, and covers config.log reuse, pyvenv/meson, ninja, debug/sanitizer builds, and reporting.
license: GPL-2.0-or-later
---

# QEMU Build

Use this skill when the task asks to build QEMU, inspect a QEMU build directory, reconfigure targets/options, or debug compiler/linker/configure failures.

## Hard policy boundary

Do not produce source code intended for QEMU upstream submission. QEMU currently declines contributions believed to include or derive from AI-generated content. You may help with build setup, failure analysis, and verification. Do not add `Signed-off-by` or any DCO-style trailer.

## Build-directory rule

QEMU uses out-of-tree builds. Default to an existing `build/` directory under the QEMU source tree unless the user or repository clearly uses another layout.

Before creating or reconfiguring anything:

1. Check whether `build/` exists.
2. Inspect `build/config.log`; the first lines record the configure invocation.
3. Check whether `build/build.ninja`, `build/pyvenv/bin/meson`, and target binaries already exist.
4. Reuse `build/` when its configure options match the task.
5. Create a separate build directory only when reuse would corrupt a meaningfully different configuration, such as sanitizer vs non-sanitizer or a target list that should remain stable.

If the repo uses `builds/<name>/`, apply the same rules to that directory. Do not guess; inspect the existing config.

## Inspecting an existing build

Useful files and commands from the QEMU source root:

- `build/config.log`: configure command, detected tools, option failures.
- `build/meson-info/intro-buildoptions.json`: Meson option state.
- `build/meson-logs/meson-log.txt`: Meson configure diagnostics.
- `build/compile_commands.json`: compiler command database.
- `build/pyvenv/bin/meson introspect build --targets`: target list.
- `build/pyvenv/bin/meson test -C build --list`: Meson-visible tests.

Prefer inspecting these artifacts before rerunning configure. Configure can be expensive and may destroy useful failure evidence.

## Configuring `build/`

Only configure after confirming no suitable build exists.

Common baseline:

```bash
mkdir -p build
cd build
../configure --target-list=<targets>
```

Common target names:

- `x86_64-softmmu`
- `aarch64-softmmu`
- `riscv64-softmmu`
- `loongarch64-softmmu`
- `x86_64-linux-user`
- `aarch64-linux-user`

Common debug options:

- `--enable-debug`: assertions and debug-oriented behavior.
- `--enable-debug-info`: debug symbols.
- `--enable-trace-backends=log`: simple log-backed tracing when trace behavior matters.

Common sanitizer options:

- `--enable-asan`
- `--enable-tsan`
- `--enable-ubsan`

Use `../configure --help` for the exact option set supported by the checked-out QEMU version.

## Reconfiguring safely

If `build/` has the right general purpose but the wrong target list, reconstruct the existing configure command from `build/config.log`, change only the necessary option, and rerun configure from the build directory.

Rules:

- Preserve debug/sanitizer/trace options unless the task explicitly changes them.
- Preserve accelerator and dependency options unless they caused the failure.
- Do not silently narrow the target list if existing users may rely on it.
- Do not delete a build directory just to fix a configure error; inspect logs first.

## Building

From the QEMU source root:

```bash
ninja -C build
```

Or from inside `build/`:

```bash
ninja
```

Build only the narrow target when possible:

```bash
ninja -C build qemu-system-riscv64
ninja -C build tests/qtest/<test-name>
```

Use verbose output only for diagnosis:

```bash
ninja -C build -v <target>
```

After source changes, rebuild before running tests. Do not report a test result against stale binaries.

## Debugging build failures

Classify failures before changing files:

- **Configure failure**: missing dependency, unsupported option, wrong compiler, stale submodule, Meson/Python issue.
- **Compile failure**: syntax/type/API mismatch in touched files, missing include, wrong feature guard.
- **Link failure**: missing object in `meson.build`, wrong library dependency, symbol visibility, target-specific object missing.
- **Generated source failure**: QAPI, trace-events, decodetree, or Meson generator issue.
- **Host/toolchain failure**: compiler bug, sanitizer incompatibility, unsupported host feature.

For generated-code failures, inspect the generator input first. Do not edit generated files under `build/`.

## Reporting format

Report builds with:

- PASS/FAIL/INCONCLUSIVE;
- source tree path and build directory path;
- exact command;
- configure target list and key options;
- decisive compiler/linker/configure excerpt if failed;
- full log paths, especially `build/config.log` or `build/meson-logs/meson-log.txt`;
- what the build proves and what remains untested.

## Upstream references

- QEMU upstream RFC skill reference: `.agents/skills/qemu-build/SKILL.md` from the qemu-devel “AGENTS.md and associated skills” series.
- QEMU build system docs: `docs/devel/build-system.rst` when present in the checked-out tree.
- QEMU testing overview: `docs/devel/testing/main.rst`.
- QEMU code provenance and AI policy: `docs/devel/code-provenance.rst`.
