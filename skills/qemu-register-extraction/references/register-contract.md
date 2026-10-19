# Register contract reference

Use this reference to build a source-cited hardware contract. Omit sections that
are genuinely inapplicable, not sections whose evidence is missing.

## Contents

- [Source inventory](#source-inventory)
- [Register and behavior facts](#register-and-behavior-facts)
- [Cross-register feature flows](#cross-register-feature-flows)
- [Search guidance](#search-guidance)
- [Confidence and conflicts](#confidence-and-conflicts)
- [Evidence tiers](#evidence-tiers)
- [Premise verification](#premise-verification)
- [QEMU framework decision](#qemu-framework-decision)
- [Output schema](#output-schema)
- [Register-only evidence projection](#register-only-evidence-projection)
- [Worked example template](#worked-example-template)
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

## Evidence tiers

Classify every fact by the evidence that establishes it before assigning
confidence:

- **driver-defined**: the field or sequence is used by a driver, firmware, or
  other software that runs on the target; cite the exact access path;
- **companion-test expectation**: a test, validation script, or boot log expects
  a value or order but does not define the hardware; useful as a cross-check,
  never as the only source for an access policy;
- **full hardware semantics**: the manual or regfile specifies the complete
  register map, reset, access, and side-effect behavior.

Model at least the driver-defined tier for every register that software touches.
Mark facts that only have a companion-test expectation, and do not claim
full-semantics coverage from driver usage or a test expectation. Record the tier
next to the confidence and sources in the contract tables.

## Premise verification

When the user supplies a register address, field value, reset value, or bit
meaning, verify it before modeling or writing a test:

1. locate the cited manual page and section, or the driver access that proves
   the claim;
2. compare the claimed value or encoding with the field width, shift, and reset
   from the source;
3. if the premise is wrong, state the correction and record both the reported
   and the verified value;
4. use the verified configuration as the regression target and the reported
   value as a rejected hypothesis.

A wrong premise propagated into a model or a test is a false-positive generator.
Example: a configuration reported as 1-4-4 was in fact the 1-1-1 encoding of the
same field; the modeling target changed before any implementation was written.

## QEMU framework decision

- Record policy present in the target QEMU workspace, explicit user direction
  and whether it is compatible, and any clear maintained nearby subsystem
  convention for every guest-visible control/status register bank.
- Apply those inputs in order, treat only compatible user direction as
  decisive, and stop at the first decisive one. Use `RegisterInfo` as the
  default when none decides.
- Permit manual MMIO callbacks when this decision justifies them. Record the
  selected framework and rationale instead of treating either framework as a
  hardware fact.
- Keep register offsets, register field macros, backing storage,
  framework-specific tables, and register-local callbacks in the device `.c`
  file.
- Do not put register layout, backing storage, or semantics in a header. A
  header may expose only non-register-layout declarations genuinely required
  outside the translation unit, such as a public QOM type or cross-unit helper
  prototype.

## Output schema

The extraction has two outputs from the same evidence: this human-readable
contract at `.oh-my-qemu/<task-slug>/output/register-contract.md` and the
machine-consumable [register semantics IR (RS-IR)](semantic-ir.md) at
`.oh-my-qemu/<task-slug>/output/register-semantics.ir` (valid skeleton:
`../assets/register-semantics-template.ir`, fictional worked example:
`../assets/register-semantics-example.ir`, vocabulary:
`../assets/ir-ops.def`, validator: `../scripts/validate_register_ir.py`).
The register-only projection feeds both; keep symbol names and rule ids
consistent between them. There is no JSON intermediate representation.

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

## Register bank framework decision

| Bank | Choice | Target-workspace policy | User direction and compatibility | Maintained nearby convention | Rationale |
| --- | --- | --- | --- | --- | --- |

## Implementation mapping notes

| Register | Framework facts | Hook/callback needed | `.c` placement | Dependencies | qtest coverage |
| --- | --- | --- | --- | --- | --- |

## Unknowns and conflicts

## Consumer checklist
```

## Register-only evidence projection

`register-contract.md` is a register behavior contract, not a diagnostic log.
Trace, execlog, QEMU `-d` output, GDB/RSP transcripts, static-analysis reports,
and runtime reviews are input sources; keep them at their original paths.
Extract only register-shaped conclusions into the contract:

- address or base and offset, width, alignment, endianness, and accepted access
  sizes;
- observed read/write operations and values, including ordered sequences;
- reset values, access policy, masks and fields, reserved bits, aliases, and
  read/write side effects;
- register-specific IRQ, DMA, FIFO, timer, command, or cross-register
  relationships;
- explicit unknowns and conflicts with confidence and source locations.

Do not paste complete trace lines, instruction logs, CPU register dumps,
exception reports, or unrelated boot or debug output into the contract. A
source may be cited as provenance (`path:line`, trace event, GDB command), but
its non-register content belongs in the source artifact.

The structured projection is the RS-IR `.ir` file described in
[semantic-ir.md](semantic-ir.md): symbols and rules carry the register facts,
rule ids carry the behavior, and `gap`/`unresolved` entries carry unknowns.
Do not create a separate JSON or raw dump; the raw evidence stays in its
original log/trace artifact and is cited as provenance.

Rules:

- Re-render after each new trace or GDB round; preserve provenance and
  confidence for every field.
- If a source only proves that an address was touched, record an observation and
  leave reset and side effects unknown; do not promote a guessed register map.
- Keep non-register content in the source artifact; the contract may cite it as
  provenance.
- The Markdown contract remains authoritative for behavior; the `.ir` file is
  its machine-readable companion for modeling, tests, and automation.

## Worked example template

Do not invent a fictional device to demonstrate the schema. Fill the generic
template below from real sources and replace every placeholder:

```markdown
# <IP block> Register Contract

## Target and variants
- IP: <name and version>
- Variants: <SoC or board variants and their differences>
- Compatibility strings: <compatible strings>
- Intended workload: <firmware or OS and use case>

## Decisive sources
| Source | Revision or edition | Location | Tier | Notes |
| --- | --- | --- | --- | --- |
| <driver path> | <commit or release> | <file:line> | driver-defined | <access path> |
| <manual title> | <edition> | <page/section> | full-semantics | <what it proves> |
| <test or log> | <version or hash> | <path:line> | companion-test | <expectation> |

## Register row
| Name | Offset | Width | Reset | Access | Side effects | Tier | Confidence | Sources |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| <NAME> | <0x...> | <n> | <0x...> | <RO/RW/W1C/...> | <observed side effect> | <tier> | <HIGH/MEDIUM/LOW/CONFLICT> | <path:line> |

## Feature flow
Flow: <name>. Fields: <participating fields>. Required order: <order>.
Partial/failure state: <behavior>. Test: <qtest or runtime candidate>.

## Unknowns
- <question> - <source gap> - <check that would resolve it>

## Framework decision
| Bank | Choice | Policy | User direction | Nearby convention | Rationale |
| --- | --- | --- | --- | --- | --- |
| <bank> | <RegisterInfo or manual MMIO> | <file:line> | <quote and compatibility> | <file:line> | <reason> |
```

Keep the template unlabeled as hardware: angle-bracket placeholders mark facts
that still need a source. A filled contract replaces every placeholder with a
cited value or an explicit unknown.

## Completion checklist

- All known register offsets and software-touched fields are present.
- Reset values, access types, masks, and reserved bits are known or marked.
- Read/write side effects and complete IRQ-clear behavior are explicit.
- DMA/FIFO/timer/command semantics are present when applicable.
- Cross-register feature flows cover partial as well as success states.
- Each decisive fact cites a source revision and location.
- Conflicts and unknowns remain visible.
- Every guest-visible control/status register bank records its framework
  decision, inputs, and rationale.
- The selected framework was inspected in the current QEMU tree, including the
  current `RegisterInfo` API when applicable.
- The contract records that register definitions, tables, and local hooks stay
  in the device `.c` file rather than a header.
- Tests cover reset, masks, W1C, IRQ, timer, DMA, complete feature enablement,
  and unknown/unsupported access behavior as applicable.
- Every decisive fact records an evidence tier (driver-defined, companion-test,
  or full-semantics) and a confidence.
- User-supplied register or field premises were verified against a manual page
  and section, and any correction is recorded.
- The `.ir` file was re-rendered from current evidence and contains only
  register-shaped findings with provenance.
- The semantic IR validates with `../scripts/validate_register_ir.py`, and its
  symbols, rule ids, and unknowns agree with this human contract.
