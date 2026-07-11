---
name: qemu-build
description: Use for configuring, reusing, building, or diagnosing QEMU build directories. Defaults to build and keeps agent-created logs and reports under a .oh-my-qemu task workspace.
---

# QEMU Build

Use this operational skill when the task asks to inspect, configure, build, reconfigure, or diagnose a QEMU build.

## Primitive Boundary

This primitive owns only build-directory inspection, configure/build commands,
build logs, and build-failure diagnosis. It consumes an artifact root supplied
by the caller and does not choose planning, verification, debug, or review
workflow steps.

## Hard policy boundary

Do not produce source code intended for QEMU upstream submission. Do not add DCO or review trailers.

## Build directory rule

Default to `build/` in the QEMU source tree. Reuse it when suitable.

Before creating or reconfiguring anything, inspect:

- `build/config.log` for the configure command;
- `build/build.ninja` for configured state;
- `build/pyvenv/bin/meson` for Meson commands;
- `build/meson-logs/meson-log.txt` for configure failures;
- `build/meson-info/intro-buildoptions.json` for options.

Create another directory only when needed to preserve a different configuration, such as sanitizer vs non-sanitizer.

## Configure

From the QEMU source root:

```bash
mkdir -p build
cd build
../configure --target-list=<targets>
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

Use `../configure --help` for the checked-out QEMU version.

## Reconfigure safely

Reconstruct the old command from `build/config.log`, then change only the needed option.

Preserve:

- target list unless the task changes it;
- debug/sanitizer/trace options;
- dependency/accelerator options;
- build directory evidence until diagnosis is complete.

Do not delete `build/` to make an error disappear.

## Build

From the source root:

```bash
ninja -C build
```

Prefer narrow targets when possible:

```bash
ninja -C build qemu-system-riscv64
ninja -C build tests/qtest/<test-name>
```

Use verbose mode only for diagnosis:

```bash
ninja -C build -v <target>
```

## Failure classification

- Configure: missing dependency, unsupported option, Python/Meson issue, compiler mismatch.
- Compile: API/type/include/feature guard mismatch.
- Link: missing object in Meson, missing dependency, target-specific source not linked.
- Generated source: QAPI, trace-events, decodetree, or Meson generator input.
- Toolchain/host: sanitizer or compiler incompatibility.

For generated-source failures, fix the generator input, not generated files in `build/`.

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
