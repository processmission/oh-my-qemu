# Linux kernel build record

Copy this file under the task directory and fill every field. Hash the exact artifacts that QEMU
or a packaging step consumes.

## Source and configuration

| Item | Value |
| --- | --- |
| Kernel source | <linux-source-root> |
| Revision / dirty state | <commit> / <clean or dirty paths> |
| Architecture | <arch> |
| Defconfig | <defconfig> |
| Config fragments | <fragment-file-1>, <fragment-file-2> |
| Merge command | <scripts/kconfig/merge_config.sh or documented command> |
| `.config` SHA-256 | <sha256 of .config> |

## Toolchain and output

| Item | Value |
| --- | --- |
| Cross compiler prefix | <prefix> |
| Absolute compiler path / version | <path> / <version> |
| Output directory (O=) | <absolute-task-output>/linux-<arch> |
| Build command | <make command exactly as run> |
| Parallelism | <-j number> |
| Build log | <task-dir>/logs/<kernel-build.log> |

## Artifacts

| Artifact | Path | SHA-256 | Consumed by |
| --- | --- | --- | --- |
| Kernel image | <path>/Image | <sha256> | <QEMU option or packaging step> |
| DTB(s) | <path>/<dtb> | <sha256> | <QEMU option or firmware media> |
| initramfs | <path>/<initramfs> | <sha256> | <QEMU option or boot media> |
| External module | <path>/<module>.ko | <sha256> | <guest module tree> |

## Module release check

| Item | Value |
| --- | --- |
| Kernel release | `include/config/kernel.release` |
| Installed module directory | <path>/lib/modules/<release> |
| Match | yes / no |
| External module build note | <KBUILD_MODPOST_WARN=1 rationale / modules_prepare scope> |

## Initramfs and rootfs

| Item | Value |
| --- | --- |
| Contract used | initramfs / block rootfs |
| Generator or script | <path> |
| File list policy | <what was included and excluded> |
| Compression | <none/gzip/other> |
| Verification | <boot marker or planned check> |

## Limits

| Item | Value |
| --- | --- |
| What this build proves | <claim supported by the artifacts> |
| What it does not prove | <boot, driver, or hardware claims it cannot support> |
| Unresolved gaps | <missing dependency, weakened symbol check, or none> |
