# Marker-aware runner contract

`scripts/run-and-classify.py` runs one command, watches a file-backed serial log, and classifies
the result from marker evidence rather than process status. It uses only the Python standard
library. Resolve it relative to the skill directory.

## Invocation

```shell
SKILL_DIR=/path/to/qemu-boot-run
TASK=.oh-my-qemu/firmware-smoke
LOG="$TASK/logs/uart1.log"

python3 "$SKILL_DIR/scripts/run-and-classify.py" \
    --timeout 120 \
    --log "$LOG" \
    --report "$TASK/logs/result.json" \
    --success-marker 'BOOT READY' \
    --failure-marker 'Kernel panic' \
    -- \
    qemu-system-aarch64 <machine and inputs> -serial "file:$LOG"
```

Required arguments: `--timeout` (positive seconds) and `--log` (file path). `--report` is
optional and must differ from `--log`. Repeat `--success-marker` for markers that must all
appear; repeat `--failure-marker` for decisive failures. The command follows `--`.

## Execution contract

1. The runner creates the log's parent directory and truncates the log to zero bytes before
   launch.
2. It starts the command in a new process group and polls the log every `--poll-interval`
   seconds (default `0.25`).
3. Any matched failure marker wins; otherwise, all success markers must match. On a marker the
   runner terminates the process group with SIGTERM, waits up to `--terminate-grace` seconds
   (default `5.0`), then sends SIGKILL if needed.
4. It waits for the child process and rescans the finalized log. A file-backed chardev may flush
   its final marker only during shutdown, so this second scan is mandatory; the report marks it
   with `evaluated_after_process_exit`.
5. Marker matching is byte-substring matching in the final log. Treat it as a configured
   contract, not as semantic boot detection.

## Exit codes

| Condition | Exit code | Meaning |
| --- | --- | --- |
| all success markers matched | 0 | semantic success, even after a timeout |
| any failure marker matched | 1 | semantic failure |
| timeout and no terminal success marker | 124 | inconclusive |
| process exit without required markers | child code if 1-125, else 1 | inconclusive |

## JSON report

The report contains: `schema_version`; `command`; `duration_seconds`; `log`;
`process` with `status` (`exited`, `timed-out`, or `terminated-after-marker`), `exit_code`,
`timed_out`, and `stop_reason`; `semantic` with `status` (`success`, `failure`, or
`unmatched`), matched and missing success markers, matched failure markers, `log_bytes`, and
`evaluated_after_process_exit`; `classification` (`passed`, `failed`, or `inconclusive`); and
`runner_exit_code`.

Write the report under task `logs/` and cite it from `audit.md`. The report is the machine-readable
record; the log remains the raw evidence.

## Marker profile example

Keep one stable profile per boot contract; use markers only the expected image emits.

| Stage | Success marker (example) | Failure marker (example) |
| --- | --- | --- |
| OpenSBI / monitor | `OpenSBI v` | `failed to init` |
| U-Boot | `U-Boot 20` or `U-Boot SPL` | `Resetting CPU` |
| Linux | `Booting Linux on physical CPU` | `Kernel panic` |
| Login | `login:` | `Attempted to kill init` |
| Workload | `BOOT READY` or `TEST PASS` | `FAILED` |

```shell
python3 "$SKILL_DIR/scripts/run-and-classify.py" \
    --timeout 180 \
    --log "$TASK/logs/console.log" \
    --report "$TASK/logs/result.json" \
    --success-marker 'U-Boot 20' \
    --success-marker 'Booting Linux on physical CPU' \
    --success-marker 'login:' \
    --failure-marker 'Kernel panic' \
    --failure-marker 'Resetting CPU' \
    -- qemu-system-<arch> <machine and inputs> -serial "file:$TASK/logs/console.log"
```

Use optional markers only when the boot contract requires them.

## Serial versus diagnostics

Guest serial is the configured `-serial` chardev. QEMU diagnostics (stderr, `-d` logs, trace
events, machine-specific debug lines) are not guest serial, even when they appear on the same
terminal. Capture diagnostics in their own file (`-D` or trace `file=`) and never add a diagnostic
string as a success marker: it can prove QEMU activity without proving guest progress. If a
diagnostic line is the only evidence, classify INCONCLUSIVE.

## Rules of use

- Empty serial output is INCONCLUSIVE, never PASS and never FAIL by itself.
- A timeout alone is not a boot failure when a success marker appears in the finalized log; the
  report's semantic status decides.
- Buffered markers can appear only after QEMU exits; do not kill the runner before its final
  scan.
- For `-serial stdio` runs, the log file does not exist; redirect stdout to a file and classify
  the file instead, or use a direct bounded run and record why the runner was not used.
- Keep the marker set stable across comparison runs; changing markers between runs invalidates
  the comparison.
