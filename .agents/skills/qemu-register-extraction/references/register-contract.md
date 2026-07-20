# Register contract reference

Use this reference to build a source-cited hardware contract. Omit sections that
are genuinely inapplicable, not sections whose evidence is missing.

## Contents

- [Source inventory](#source-inventory)
- [Register and behavior facts](#register-and-behavior-facts)
- [Cross-register feature flows](#cross-register-feature-flows)
- [Search guidance](#search-guidance)
- [Confidence and conflicts](#confidence-and-conflicts)
- [Output schema](#output-schema)
- [Completion checklist](#completion-checklist)

## Source inventory

Record only sources actually used:

- driver path, repository URL, revision, project/version, and relevant lines;
- manual title, edition, date, page/section, and applicable errata;
- firmware or filesystem path, SHA-256, extraction method, and relevant files;
- DTS/DTB path, node name, compatible string, clocks, resets, and IRQs;
- SVD, IP-XACT, SystemRDL, CSV, JSON, YAML, XML, or header path and version;
- runtime dump or trace command, image identity/hash, and capture path.

For proprietary or large sources, record citations and concise technical facts.
Keep copied, extracted, or converted third-party material under task `output/`
and the scripts that produced it under task `scripts/`.

## Register and behavior facts

For each variant and register window, record:

- block aliases, IP version, compatibility strings, base/size, endianness, bus,
  and accepted access widths;
- clock, reset, power, pinctrl, IRQ-controller, and DMA dependencies;
- register offset/width/reset and access type: RO, WO, RW, W1C, W1S,
  clear-on-read, write trigger, or read side effect;
- reserved/unimplemented bits, field shift/width/mask, enumerations, and
  version-dependent meanings;
- valid access sizes/alignment plus behavior for unsupported sizes and unknown
  offsets;
- aliases, indexed/page-selected windows, banked/shadow registers, and FIFOs;
- initialization and shutdown order, unlock/lock sequences, polling/timeouts,
  delays, busy/self-clearing bits, and failure paths;
- IRQ raw/mask/global-enable/status/acknowledge relationships;
- timer/counter clocking, prescale, load, reload, enable, status, and clear;
- FIFO push/pop, watermark, overflow, and underflow behavior;
- DMA addresses, length, descriptors, ownership, start, completion, and errors;
- accelerator command streams, buffers, completion, and error reporting.

Use hex where the authoritative source does. State byte versus sector units and
bit numbering explicitly.

## Cross-register feature flows

Create a named flow whenever software combines registers or fields. Common
patterns include:

- clock gate → reset release → mode enable → start;
- raw IRQ status + mask + global enable → routed IRQ → W1C acknowledge;
- DMA address + length + descriptor ownership + control → completion/error;
- FIFO depth + watermark + push/pop + interrupt enable + overflow status;
- timer load + prescaler + enable + reload + status clear;
- unlock/write-protect sequences that change later write behavior;
- bank/index/page selection controlling another logical register;
- feature/version bits gating the existence or meaning of later fields.

For every flow, record participating fields, required order, coupling semantics,
partial-state/failure behavior, decisive sources, and an end-to-end qtest or
runtime candidate.

## Search guidance

Search by compatible string, register prefix, base address, IRQ/status symbol,
clock/reset name, read/write helper, polling/timeout helper, and probe/init/
reset/suspend/resume call path—not only by filename.

- Linux-like trees: inspect driver, binding, DTS, clock/reset providers, and
  subsystem helpers.
- U-Boot, TF-A, EDK2, Zephyr, RTOS, and SDKs: inspect board initialization and
  low-level HAL accessors.
- Firmware filesystems: inspect DT data, modules, init scripts, blobs, config,
  logs, and userspace register tools.
- Regfiles: verify address-unit assumptions, arrays, reset/access policy, and
  enumerations against driver behavior. Mark regfile-only and driver-only facts.

## Confidence and conflicts

- `HIGH`: independent authoritative sources agree, or runtime evidence confirms.
- `MEDIUM`: one strong source exists without independent confirmation.
- `LOW`: naming, nearby code, incomplete trace, or another inference only.
- `CONFLICT`: sources disagree.

For conflicts, record both exact sources, differing values/semantics, target
relevance, chosen temporary assumption if unavoidable, and the test needed to
resolve it.

## Output schema

```markdown
# <Device/IP> Register Contract

## Target and variants

## Source inventory

## Memory map and dependencies

## Register summary

| Name | Offset | Width | Reset | Access | Side effects | Confidence | Sources |
| --- | --- | --- | --- | --- | --- | --- | --- |

## Field tables

| Register.Field | Bits | Access | Reset | Meaning | Side effects | Confidence | Sources |
| --- | --- | --- | --- | --- | --- | --- | --- |

## Driver and firmware sequences

## IRQ, DMA, FIFO, timer, and command behavior

## Cross-register feature flows

| Flow | Fields | Required order | Coupling | Partial/failure state | Confidence | Sources | Test |
| --- | --- | --- | --- | --- | --- | --- | --- |

## Registerinfo mapping notes

| Register | RegisterAccessInfo facts | Hook needed | Dependencies | qtest coverage |
| --- | --- | --- | --- | --- |

## Unknowns and conflicts

## Consumer checklist
```

## Completion checklist

- All known register offsets and software-touched fields are present.
- Reset values, access types, masks, and reserved bits are known or marked.
- Read/write side effects and complete IRQ-clear behavior are explicit.
- DMA/FIFO/timer/command semantics are present when applicable.
- Cross-register feature flows cover partial as well as success states.
- Each decisive fact cites a source revision and location.
- Conflicts and unknowns remain visible.
- Tests cover reset, masks, W1C, IRQ, timer, DMA, complete feature enablement,
  and unknown/unsupported access behavior as applicable.
