# QEMU run record

Copy this file under the task directory and fill it after the finalized log, not from memory.

## Command

| Item | Value |
| --- | --- |
| QEMU binary | <path> |
| Build directory | <path> |
| Machine / CPU / accelerator | <machine> / <cpu> / <accel> |
| SMP / memory | <smp> / <memory> |
| Inputs and SHA-256 | <kernel, dtb, initrd, firmware, disk and hashes> |
| Serial route | file:<task-dir>/logs/<console>.log or `-serial stdio` |
| Monitor | none / stdio / socket |
| Timeout | <seconds> |
| Success markers | <marker-1>, <marker-2> |
| Failure markers | <marker-1>, <marker-2> |
| Runner | `scripts/run-and-classify.py` or direct bounded run |
| Report | <task-dir>/logs/result.json |
| Console log | <task-dir>/logs/<console>.log |

## Result

| Item | Value |
| --- | --- |
| Process status | exited / timed-out / terminated-after-marker |
| Process exit code | <code> |
| Semantic status | success / failure / unmatched |
| Verdict | PASS / FAIL / INCONCLUSIVE |
| Reached marker | <exact marker text and log line> |
| First suspect | wrong artifact / image layout / QEMU command / boot ABI / missing device / guest OS |
| Diagnostics separated from serial | yes / no |

## Limits

| Item | Value |
| --- | --- |
| What this run proves | <claim supported by markers and log> |
| What it does not prove | <device, board, or hardware claims> |
| Next blocker | <concrete next check or none> |
| Unresolved gaps | <missing input, empty serial, unexplained difference, or none> |
