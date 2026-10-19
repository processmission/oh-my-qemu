# QEMU crash report: <short-id>

Copy this report into `.oh-my-qemu/<task-slug>/audit.md` and fill it after the
first capture. Record observed facts only; keep guesses in Classification.
Generate the first pass from the installed skill directory:

```bash
bash scripts/collect-context.sh --output <report.md> --qemu <qemu-binary>
```

## Reproduction

- Command: `<exact command line>`
- Working directory: `<absolute path>`
- First observed: <date/time, tree revision>
- Reproducer: `<minimized command>`; deterministic: <yes/no>

## Binary and build

- QEMU binary: `<absolute path>`
- sha256: <hash>
- Build directory: `<path>`
- Build config: `<configure line from config.log>`
- Debug info: <yes/no; for example --enable-debug or --enable-debug-tcg>
- Accelerator and machine: `<accel and -machine>`

## Failure

- Signal or exit status: <signal/exit code>
- Assertion or abort message: `<file:line: message>`
- Backtrace:

```text
<thread apply all bt full output>
```

- Core dump path: `<path or none>`
- Threads involved: <thread names/ids>

## Environment

- Host OS and architecture: <...>
- Tool versions: <gdb/lldb, compilers, ninja, meson>
- Image and firmware hashes: <sha256 per input>
- QEMU arguments and environment: <QTEST_*, trace or -d flags, ulimits>

## Classification and next check

- Classification: <environment | image | boot ABI | board | device model |
  TCG | guest>
- Evidence for the classification: <paths and lines>
- Next narrow check: <one command or instrumentation>
- Cleanup: <processes stopped, files removed>
- Handoff gap: <what remains unknown>
