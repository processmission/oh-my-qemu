# Boot evidence record

Copy this file under the task directory and fill one row per stage reached or attempted. Final
acceptance is the task's Linux milestone, not an intermediate stage gate.

## Summary

| Item | Value |
| --- | --- |
| Task | <.oh-my-qemu/<task-slug>> |
| Boot path | direct / firmware |
| Final acceptance criterion | <Linux milestone marker> |
| Final status | PASS / FAIL / INCONCLUSIVE |

## Stage evidence

| Stage | Expected marker | Evidence path and line | Reached? | Round gate | Next blocker |
| --- | --- | --- | --- | --- | --- |
| reset / ROM entry | <marker> | <log>:<line> | yes / no | <gate> | <blocker> |
| early loader (SPL/TPL) | <marker> | <log>:<line> | yes / no | <gate> | <blocker> |
| trusted firmware / monitor | <marker> | <log>:<line> | yes / no | <gate> | <blocker> |
| bootloader | <marker> | <log>:<line> | yes / no | <gate> | <blocker> |
| boot media access | <marker> | <log>:<line> | yes / no | <gate> | <blocker> |
| kernel entry | <marker> | <log>:<line> | yes / no | <gate> | <blocker> |
| Linux console / init | <marker> | <log>:<line> | yes / no | <gate> | <blocker> |
| rootfs / shell | <marker> | <log>:<line> | yes / no | <gate> | <blocker> |
| documentation | docs validation | <command output> | yes / no | <gate> | <blocker> |

Delete rows that do not apply to the selected boot path; direct boot normally starts at kernel
entry.

## Inputs and hashes

| Input | Path | SHA-256 | Verified by |
| --- | --- | --- | --- |
| QEMU binary | <path> | <sha256> | <command> |
| kernel / firmware | <path> | <sha256> | <command> |
| DTB / FDT | <path> | <sha256> | <property check and command> |
| initrd / rootfs | <path> | <sha256> | <command> |
| boot media | <path> | <sha256> | <readback command> |

## Limits

| Item | Value |
| --- | --- |
| What the reached marker proves | <stage and handoff claim> |
| What it does not prove | <device, board, or hardware claims> |
| Unexplained differences | <counter or timing differences left open> |
| Unresolved gaps | <missing stage, stale input, guest-side issue, or none> |
