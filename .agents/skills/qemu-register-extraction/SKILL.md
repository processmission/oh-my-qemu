---
name: qemu-register-extraction
description: Use as a research flow before qemu-peripheral-modeling to extract register maps, bitfields, side effects, IRQs, DMA behavior, clocks, resets, and driver sequences from drivers, datasheets, firmware filesystems, and regfiles into markdown.
type: flow
license: GPL-2.0-or-later
---

# QEMU Register Extraction

Use this foundational research flow before `qemu-peripheral-modeling` when the source of truth is outside QEMU: OS drivers, bare-metal SDKs, firmware, bootloader code, datasheets/reference manuals, extracted firmware filesystems, device trees, SVD/IP-XACT/SystemRDL/regfiles, generated headers, or runtime register dumps.

The output is a markdown register/function specification for the modeling skill. This flow does not produce QEMU source code.

## Hard policy boundary

Do not produce source code intended for QEMU upstream submission. QEMU currently declines contributions believed to include or derive from AI-generated content. This flow is research and analysis only. Do not add `Signed-off-by`, `Reviewed-by`, `Acked-by`, `Tested-by`, or similar contribution trailers.

## Artifact root rule

All generated artifacts must stay under the task workspace from `qemu-flow-plan`:

```text
build/agent/<task-slug>/
```

Recommended files:

```text
build/agent/<task-slug>/
  register-extraction.md
  source-inventory.md
  conflicts.md
  evidence.md
  logs/
  scratch/
```

Never write notes, converted datasheet excerpts, extracted filesystem files, generated tables, or scratch scripts into QEMU source directories.

## Required inputs

Record every input source in `source-inventory.md`:

- driver source path, repository URL, branch/commit, OS/project, and version;
- datasheet/reference manual title, revision, date, page/section, and errata source;
- firmware filesystem or image path, hash, extraction method, and relevant files;
- device tree/DTS/DTB paths and node names;
- regfile format and path, such as SVD, IP-XACT, SystemRDL, CSV, JSON, YAML, XML, vendor headers, or generated register descriptions;
- runtime dumps or traces, including command, image hash, and capture path.

If a source is proprietary or large, summarize technical facts and cite location. Do not paste large copyrighted sections into the markdown.

## Extraction order

### 1. Identify device variants

Extract:

- block name, vendor name, aliases, and IP version;
- SoC/board variants and compatibility strings;
- register-window count, base addresses, sizes, and endianness;
- bus type and access width requirements;
- clock, reset, power-domain, and pinctrl dependencies;
- interrupt lines and interrupt-controller source numbers;
- DMA channels, stream endpoints, or bus-master capability.

### 2. Build the source cross-reference

For each register or behavior, note which source mentions it:

- datasheet table or section;
- driver macro/header;
- driver read/write path;
- firmware initialization sequence;
- device tree property;
- regfile field;
- runtime trace or dump.

Use source paths and line/page references. When two sources disagree, do not choose silently; record the conflict in `conflicts.md`.

### 3. Extract register facts

For each register, extract:

- offset and width;
- reset value;
- access type: RO, WO, RW, W1C, W1S, clear-on-read, write-only trigger, read-side effect;
- reserved bits and unimplemented bits;
- bitfield name, shift, width, mask, and enumerated values;
- aliasing, banked registers, indexed windows, FIFOs, or shadow registers;
- valid access sizes and alignment behavior;
- behavior on unsupported access size or unknown offset.

Keep numeric values in hex where hardware docs use hex. Normalize units and bit numbering.

### 4. Extract behavior, not only registers

Driver code often reveals semantics absent from datasheets. Extract:

- initialization sequence and required ordering;
- reset/unlock/lock sequences;
- polling loops and timeout conditions;
- IRQ enable, mask, status, clear, and acknowledge flow;
- timer/counter progression and clock dependency;
- DMA descriptor layout, ownership bits, completion status, and error paths;
- FIFO push/pop semantics and overflow/underflow behavior;
- command-stream format for accelerator-like blocks;
- required delays, busy bits, and self-clearing bits;
- feature-detection registers and version-dependent behavior.

Do not assume a register is passive because it is a scalar field. Check driver call paths around every write with side effects.

### 5. Use driver search patterns

Search drivers by symbol and behavior, not only file names:

- compatible strings and device names;
- register macro prefixes;
- base-address constants;
- IRQ names and status bit names;
- reset/clock names;
- polling helpers and timeout loops;
- read/write helper wrappers;
- probe/init/remove/reset/suspend/resume paths;
- firmware boot or board init code;
- generated headers imported by the driver.

For Linux-like trees, inspect driver, binding schema, DTS nodes, reset/clock providers, and subsystem helpers. For U-Boot, TF-A, EDK2, Zephyr, RTOS, and bare-metal SDKs, inspect board init plus low-level HAL accessors.

### 6. Use filesystem and firmware evidence

For extracted firmware filesystems or runtime captures, look for:

- `/proc/device-tree` or decompiled DTB equivalents;
- kernel modules and module parameters;
- init scripts that configure the device;
- firmware blobs loaded into the device;
- config files naming MMIO bases, IRQs, clocks, or DMA buffers;
- logs showing initialization order or failure markers;
- userspace tools that poke registers directly.

Store extracted or copied artifacts under `build/agent/<task-slug>/scratch/` only.

### 7. Convert regfiles carefully

For SVD/IP-XACT/SystemRDL/vendor regfiles:

- preserve register grouping and arrays;
- verify address-unit assumptions;
- verify reset values and access policies against drivers;
- extract enumerated field values;
- mark fields present in regfile but unused by software;
- mark driver-used fields missing from regfile.

Generated headers are evidence, not authority. Cross-check them against the manual or driver behavior.

## Confidence and conflict policy

Assign each extracted fact one confidence level:

- **HIGH**: datasheet/regfile and driver agree, or runtime confirms behavior.
- **MEDIUM**: one strong source exists, but no independent confirmation.
- **LOW**: inferred from naming, nearby code, or incomplete traces.
- **CONFLICT**: sources disagree.

For conflicts, record:

- exact conflicting sources;
- the values/semantics that differ;
- which source is newer or closer to the target workload;
- what qtest/runtime check would resolve it;
- chosen modeling assumption, if one is necessary.

## Markdown output template

Write `register-extraction.md` using this structure:

```markdown
# <Device/IP Name> Register Extraction

## Target

## Source Inventory Summary

## Variants and Compatibility

## Memory Map

## Interrupts, Clocks, Resets, and DMA

## Register Summary Table

| Name | Offset | Width | Reset | Access | Side Effects | Confidence | Sources |
| --- | --- | --- | --- | --- | --- | --- | --- |

## Field Tables

### <REGISTER_NAME>

| Field | Bits | Access | Reset | Meaning | Side Effects | Confidence | Sources |
| --- | --- | --- | --- | --- | --- | --- | --- |

## Driver Sequences

## IRQ and Status Flow

## DMA, FIFO, Timer, or Command Behavior

## QEMU RegisterInfo Mapping Notes

| Register | RegisterAccessInfo facts | Hook needed | qtest coverage |
| --- | --- | --- | --- |

## qtest Candidates

## Unknowns and Conflicts

## Handoff Checklist for qemu-peripheral-modeling
```

Do not include C code templates. The downstream modeling skill must inspect the checked-out QEMU registerinfo API and choose the implementation details.

## Handoff requirements

Before handing off to `qemu-peripheral-modeling`, ensure the markdown contains:

- all known register offsets and fields;
- access semantics for every software-touched register;
- reset values or explicit unknowns;
- side-effect registers requiring pre-write, post-write, or post-read hooks;
- IRQ/status clear behavior;
- DMA/FIFO/timer/command semantics when present;
- qtest candidates for reset, masks, W1C, IRQ, timer, DMA, and unknown-offset behavior;
- unresolved conflicts with source references.

If any of these are missing, mark the gap explicitly. Do not hide unknowns by inventing defaults.

## Upstream references

- QEMU code provenance and AI policy: `docs/devel/code-provenance.rst`.
- QEMU registerinfo framework to inspect during handoff: `include/hw/core/register.h`, `include/hw/core/registerfields.h`, and `hw/core/register.c` in the checked-out tree.
- Downstream modeling skill: `qemu-peripheral-modeling`.
