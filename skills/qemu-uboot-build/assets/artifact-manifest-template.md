# U-Boot artifact manifest

Copy this file under the task directory and fill one row per boot stage. Hash each stage
separately; a combined image does not prove its contents.

## Per-stage artifacts

| Stage | Artifact | Path | Load offset | SHA-256 | Packaging command | Verified by |
| --- | --- | --- | --- | --- | --- | --- |
| SPL / TPL | <artifact> | <path> | <offset> | <sha256> | <command> | <file/dumpimage> |
| U-Boot proper | <artifact> | <path> | <offset> | <sha256> | <command> | <file/dumpimage> |
| FIT / ITB | <artifact> | <path> | <offset> | <sha256> | <mkimage command> | <dumpimage -l> |
| Combined image | <artifact> | <path> | <offset> | <sha256> | <command> | <command and result> |

## Artifact inspection

| Check | Command | Result |
| --- | --- | --- |
| Identify SPL / U-Boot proper | file <artifact> | <result> |
| List FIT components | dumpimage -l <artifact> | <components, load addresses, hashes> |
| Metadata | mkimage -l <artifact> | <result> |
| Stage bytes match the source artifact | cmp <source> <extracted-range> | match / mismatch |

## External dependencies

| Dependency | Source (built or blob) | Revision | SHA-256 | Consumed by |
| --- | --- | --- | --- | --- |
| TF-A / BL31 | <built or vendor blob> | <revision> | <sha256> | <packaging step> |
| TEE / OP-TEE | <built or vendor blob> | <revision> | <sha256> | <packaging step> |
| DDR init / device tree | <source> | <revision> | <sha256> | <packaging step> |

## Packaging into a firmware or flash image

| Item | Value |
| --- | --- |
| Source media (read-only) | <vendor-image-path> |
| Output image | <task-dir>/output/<image> |
| Documented destination offset | <offset> |
| Embedded bytes compared at offset | match / mismatch |
| Container hash | <sha256 of output> |
| Packaging command | <command exactly as run> |

## Limits

| Item | Value |
| --- | --- |
| What this manifest proves | <stage placement and identity claims> |
| What it does not prove | <runtime handoff, hardware, or signing claims> |
| Unresolved gaps | <unsigned FIT, missing dependency, mismatch, or none> |
