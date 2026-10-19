# Host and toolchain matrix

Use this reference before configuring or building QEMU when the host, container, or toolchain
is unfamiliar, or after an environment-shaped failure. Record the resolved values in
`commands.md` and the conclusions in `audit.md`.

## Preflight record

| Item | Check | Record |
| --- | --- | --- |
| Ninja | `command -v ninja`, `ninja --version` | absolute path, version |
| Meson | `<build-dir>/pyvenv/bin/meson --version`, fallback `command -v meson` | absolute path, version |
| Python | `command -v python3`, `python3 --version` | absolute path, version |
| Compiler | `<CC> --version`, resolved from `config.log` | absolute path, version |
| pkg-config / sysroot | paths recorded in `config.log` | prefix, sysroot |
| HOME | readable and writable by the executing user | path |
| QEMU runtime libs | `ldd <qemu-binary>` after build, or the documented container | missing libraries |
| Disk | `df -h` on source root and build root | available space |

## macOS arm64 host

Observed failure modes in real QEMU work on an arm64 Mac:

- There is no `timeout` or `gtimeout` by default. Use the bundled marker runner's `--timeout`,
  or run a bounded foreground command and record how it was bounded; do not silently hang.
- `TMPDIR` can break qtest AF_UNIX sockets with a bind failure. Use a short temporary directory
  for `TMPDIR` and rerun the test single-process.
- An x86_64 cross `objdump` can fail on an arm64 host with `exec format error`; use a host-native
  or LLVM tool, or run the step in a matching container.
- Apple tool variants can lack GNU options (for example `objdump -b`), and `llvm-nm`,
  `llvm-readelf`, or `pdftotext` may be absent. Record the substitute and its version.
- `cp --parents` is not portable; use `rsync -R` or a shell loop for packaging.
- GNU coreutils and GNU tar may be installed under prefixed names; record which variant ran.

## Linux and container

- Install only the dependencies the checked-out `meson.build` and configure script require;
  record package names and versions when the container image is not fixed.
- A build container may lack `ninja`, a suitable Meson, or a writable `HOME` for the executing
  UID. Prefer the build directory's `pyvenv` tools and an absolute `NINJA` path over `PATH`.
- Some images install a newer compiler than the configured warning policy expects. Record any
  `--disable-werror` or warning suppression with the exact warning that forced it.
- The image used for building may differ from the image used for running. Record both when they
  differ; a run failure caused by a missing host library is not a model failure.

## Dependency and toolchain failure table

| Symptom | Usual action |
| --- | --- |
| `ninja: command not found` | use the configured absolute Ninja |
| Meson cannot load build data | use the build directory's `pyvenv/bin/meson` |
| Meson reconfigure fails on CMake lookup | set a writable `HOME` and `XDG_CACHE_HOME` |
| `glib-2.0 not found` | point `PKG_CONFIG_PATH` at the recorded sysroot |
| Configure stops on a compiler probe | record the probe before changing flags |
| Link or start fails on a library | install the package or use the container |

## Configure-flag rationale

Keep `config.log` as the source of truth for the configure command. A non-default flag is a
recorded decision, not a preference: state the failing probe or warning, the flag, and the
narrowest reproducer. Never claim a clean build when warnings were suppressed without a record.

## Installer prerequisite

The project-local installer path used by this catalog runs a skills CLI that needs a recent
Node.js. If the installer cannot run in the current environment, record the version gap instead
of substituting a global installation or copying skill files by hand.
