# QEMU build record

Copy this file under the task directory and fill every field. Keep commands exactly as run and
link the decisive log; delete placeholder rows that do not apply.

## Baseline

| Item | Value |
| --- | --- |
| Source root | <qemu-source-root> |
| Branch / HEAD | <branch-or-none> / <commit-or-none> |
| Dirty state | <git status --short summary, or "not a Git worktree: provenance gap"> |

## Build directory

| Item | Value |
| --- | --- |
| Build directory | <qemu-source-root>/builds/build-<target> |
| Configure command | <configure command exactly as run> |
| Target list | <targets> |
| Decisive options | <option> - <why it was needed> |
| config.log | <build-dir>/config.log |
| Stale check | <config.log source path> = <current source root>: MATCH or MISMATCH |

## Toolchain

Take values from `scripts/preflight.sh` or record them by hand.

| Tool | Absolute path | Version |
| --- | --- | --- |
| ninja | <path> | <version> |
| meson | <path> | <version> |
| python3 | <path> | <version> |
| compiler | <path> | <version> |
| pkg-config / sysroot | <path> | <version> |

## Build

| Item | Value |
| --- | --- |
| Command | <build command exactly as run> |
| Result | PASS / FAIL / INCONCLUSIVE |
| Exit status | <code> |
| Log | <task-dir>/logs/<build.log> |
| Targets built | <binaries and qtests> |

## Gate

| Gate | Result |
| --- | --- |
| Narrow build of affected target | PASS / FAIL / not applicable |
| Matching qtest or focused verification | PASS / FAIL / not run |
| `scripts/checkpatch.pl` | PASS / FAIL / not applicable |
| `git diff --check` | PASS / FAIL |
| `git status --short` reconciled with baseline | yes / no |

## Limits

| Item | Value |
| --- | --- |
| What this build proves | <claim supported by the build> |
| What it does not prove | <runtime, model, or hardware claims it cannot support> |
| Unresolved gaps | <skipped gate, missing tool, stale directory, or none> |
