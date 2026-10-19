# Image packaging plan

Copy this file under the task directory and fill it before the first write. Use the selected mode
(`inspect`, `extract`, or `package`) and record the exact authorization for any mutation.

## Authorization

| Item | Value |
| --- | --- |
| Mode | inspect / extract / package |
| Target path or device | <path> |
| Authorization source | <user request reference or "inspection only"> |
| Allowed changes | <exact changes or none> |
| Task directory | <.oh-my-qemu/<task-slug>> |

## Outputs

| Output | Format | Virtual size | Exists? | Mutation policy |
| --- | --- | --- | --- | --- |
| <output-path> | <raw/qcow2/...> | <bytes> | yes / no | immutable / working copy / disposable / reusable |

## Regions

| Region | Start byte | Start sector | Sector size | Size | Type/filesystem | Source |
| --- | --- | --- | --- | --- | --- | --- |
| <region-name> | <byte> | <sector> | <512 or 4096> | <size> | <type> | <input path> |

## Operations

| Order | Operation | Input | Output region | Offset/seek | Block size | Bounds | Readback |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | <copy/dd/convert> | <input> | <region> | <offset unit> | <bs> | <bounds> | <readback> |

## Backup and rollback

| Item | Value |
| --- | --- |
| Backup or clean base | <path> and SHA-256 |
| Rollback steps | <remove incomplete output / restore backup> |
| Rollback verified | yes / no / not needed |

## Readback hashes

| File or range | Before | After | Verification command |
| --- | --- | --- | --- |
| <output> | <sha256> | <sha256> | <cmp or sha256 command> |

## Cross-repo asset contract

| Asset | Consumer | Expected hash | Local server URL |
| --- | --- | --- | --- |
| <boot-file> | <consumer repo or test> | <sha256> | <http://host:port/path> |

## Limits

| Item | Value |
| --- | --- |
| What this packaging proves | <byte placement and identity claims> |
| What it does not prove | <boot, guest, or hardware claims> |
| Unresolved gaps | <missing tool, partial write, failed readback, or none> |
