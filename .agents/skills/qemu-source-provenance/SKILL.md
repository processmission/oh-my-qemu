---
name: qemu-source-provenance
description: Use as a QEMU workflow primitive to record source trees, revisions, configs, toolchains, containers, build commands, output artifacts, hashes, assumptions, and RLCR round Git checkpoints before builds or during iterative local QEMU work.
---

# QEMU Source Provenance

Use this primitive whenever a QEMU task depends on external source trees or produced artifacts: Linux, U-Boot, TF-A, EDK2, Zephyr, firmware blobs, root filesystems, disk images, DTBs, modules, initramfs files, or vendor SDKs.

## Composition

1. Start from `qemu-flow-plan` for non-trivial work.
2. Write provenance to `build/agent/<task-slug>/source-provenance.md`.
3. Record exact commands in `commands.md`.
4. Feed verified artifacts into `qemu-image-layout`, `qemu-boot-run`, or workflow skills.
5. For RLCR source changes, record the task-tree baseline before round 1 and
   append one checkpoint row after every successful round commit.

## Required Record

Use this structure:

```markdown
# Source Provenance

## Source Roots

| Component | Path/URL | Revision | Dirty state | Purpose |
| --- | --- | --- | --- | --- |

## Task Source Baseline

| Tree | Branch | Baseline revision | Initial dirty paths | Commit pathspecs |
| --- | --- | --- | --- | --- |

## RLCR Round Checkpoints

| Round | Parent | Commit | Tree | Subject | Staged paths | Verification/review | Residual dirty state |
| --- | --- | --- | --- | --- | --- | --- | --- |

## Configurations

| Component | Config path/name | Key options | Notes |
| --- | --- | --- | --- |

## Toolchains and Runtime

| Tool | Version | Path | Notes |
| --- | --- | --- | --- |

## Build Commands

## Output Artifacts

| Artifact | Producer | Path | Size | SHA256 | Verified by |
| --- | --- | --- | --- | --- | --- |

## Assumptions and Gaps
```

## Rules

- Do not trust filenames as provenance. Record revision, config, command, and hash.
- Record whether a source tree is dirty before using its output.
- Treat `git rev-parse HEAD` as the common baseline, not a complete description
  of a dirty source tree.
- For RLCR, record the initial branch, baseline revision, and exact dirty paths
  before source changes. Do not fold those pre-existing paths into a round
  commit.
- After each successful round commit, record its parent, commit and tree IDs,
  subject, staged path list, verification/review evidence, and residual dirty
  state. The commit ID is the reproducible source checkpoint for that round.
- Do not commit external input trees merely because their provenance is
  recorded. Automatic round commits apply only to the task source tree and
  pathspecs approved by `qemu-flow-plan`.
- If Docker or another container is used, record the image name, digest if available, mounted paths, and command.
- Hash final artifacts consumed by QEMU, not only intermediate build directories.
- If an artifact is copied, record both source and destination paths.
- Mark missing or inferred facts as gaps instead of silently guessing.

## Useful Checks

Prefer local source truth:

```bash
git -C <source> rev-parse HEAD
git -C <source> branch --show-current
git -C <source> status --short
git -C <source> diff --cached --name-status
git -C <source> rev-parse HEAD^{tree}
sha256sum <artifact>
file <artifact>
```

Use project-specific version commands when available, such as `make kernelrelease`, compiler `--version`, or firmware build banners.
