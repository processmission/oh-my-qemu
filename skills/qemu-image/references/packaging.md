# Image packaging and inspection reference

Use this reference for the tables and tool details behind `qemu-image`. Record the filled-in
tables in `audit.md` and the exact commands in `commands.md`.

## Mode selection

| Mode | Default | Allowed actions |
| --- | --- | --- |
| inspect | yes | identify, measure, list, hash, read byte ranges |
| extract | when requested | read-only extraction into task `output/` |
| package | explicit request | create, convert, partition, populate, write |

Inspect and extract never mutate the input. Package mode requires the exact output path and the
authorized changes before the first write.

## Package contract tables

Copy these tables into `audit.md` and fill every row before writing.

| Output | Format | Virtual size | Exists? | Mutation policy |
| --- | --- | --- | --- | --- |

| Region | Start byte | Start sector | Sector size | Size | Type | Source |
| --- | --- | --- | --- | --- | --- | --- |

| Order | Operation | Input | Output region | Offset | Bounds | Readback |
| --- | --- | --- | --- | --- | --- | --- |

## Tool matrix

| Task | Tools | Notes |
| --- | --- | --- |
| Identify format and size | `file`, `qemu-img info` | never infer format from suffix |
| Inspect partitions | `fdisk -l`, `sfdisk --dump` | record logical sector size |
| Inspect partitions (GPT) | `sgdisk -p`, `parted -s print` | record table type and GUIDs |
| Inspect filesystem | `dumpe2fs -h`, `debugfs`, `e2fsck -fn` | read-only forms only |
| Inspect qcow2 | `qemu-img info --backing-chain`, `qemu-img check` | record overlays and backing files |
| Read or verify sectors | `qemu-io -c read`, `dd`, `sha256sum` | hash or byte-compare ranges |
| FAT or EFI content | `mtools`, `mdir`, `mcopy` | read forms first |
| Populate a filesystem | `guestfish`, `virt-copy-in`, `mkfs`, `mount` | task-local copy only |
| Extract firmware | `binwalk`, `unblob`, `7z`, vendor tools | extract mode; record tool version |
| Combine or split images | `qemu-img convert`, `dd`, vendor scripts | record order and readback |

Prompt for missing tools and record the gap. Do not substitute an untested equivalent.

## Readback and verification checklist

- Every material write has a readback command and a recorded result.
- Byte ranges are compared with their source by `cmp` or SHA-256, not by exit status.
- Partition boundaries, sector size, and filesystem contents are verified independently.
- Flush and filesystem checks are read-only unless a repair was authorized.
- Final output hash and any pre-mutation hash are recorded.
- A QEMU boot is not packaging proof; guest writes can mutate the image.

## Extraction and forensics checklist

- Hash the input before extraction and keep it read-only.
- Record tool name and version, extraction depth, and output directory.
- Record every discovered layer: container, compression, archive, filesystem.
- Treat extraction output as untrusted data; do not execute extracted binaries.
- Keep extracted content under task `output/` and name the layer boot inputs come from.
- A filename or string match is a hypothesis, not a hardware contract.

## Cross-repo packaging contract

When another repository or test suite consumes the image or boot files:

- provide separately consumable files the consuming path needs, for example kernel image,
  initramfs, DTB, and firmware, in addition to any combined image;
- pin the artifact hash expected by the consuming test and record both producer and consumer
  hashes; treat a mismatch as stale input, not as a target failure;
- a local HTTP server may serve assets for functional tests; record URL, port, document root,
  and hashes;
- metadata names such as `REQUIRED_IMAGES` or `SUPPORTED_BOOT_MODES` are repository-specific and
  stay in that repository;
- when a test asset hash changes, update the consumer in the same task and record the new hash.

## Rollback and retention

Prefer a new output under `output/` and publish it only after readback. For an existing target,
define the rollback before the first write, keep the backup until handoff, and verify the
restored image's format, layout, size, and hash. State when a disposable image will be removed
and keep the evidence needed to reproduce it.
