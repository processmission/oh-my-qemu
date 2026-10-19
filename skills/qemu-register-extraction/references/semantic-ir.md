# Register Semantics IR (RS-IR, v1)

Use this reference when the extracted register contract must be handed to a
model, a reviewer, or a test generator in machine-consumable form. The IR is
the structured companion of the human contract: same evidence, same rule ids,
same unknowns. It is text, not JSON, and it is not generated code.

## Name and scope

RS-IR stands for **Register Semantics Intermediate Representation**: "register
semantics" is the extracted fact set (symbols, fields, state, events) and "IR"
is its role as the reviewable, machine-readable artifact exchanged between
register extraction and device modeling. The rule grammar keeps the
Trigger / Condition / Transition structure; the file extension is `.ir`.

RS-IR is a small domain-specific notation for *register behavior*, not an
execution language: it describes what a register block does under a trigger,
not how QEMU executes it. It is validated, diffed, and cited, and it never
replaces the human contract, the model source, or the evidence logs.

## Outputs

A complete extraction writes under `.oh-my-qemu/<task-slug>/output/`:

- `register-contract.md` — the human register behavior contract and the
  authoritative behavior record for review;
- `register-semantics.ir` — this RS-IR file, copied from
  [the template](../assets/register-semantics-template.ir) or adapted from
  [the example](../assets/register-semantics-example.ir).

Raw trace, execlog, QEMU `-d` output, GDB/RSP transcripts, and static-analysis
reports stay at their original paths under `logs/`; the IR and the contract
contain only register-shaped conclusions with provenance.

Validate the IR with [the validator](../scripts/validate_register_ir.py):

```bash
python3 scripts/validate_register_ir.py output/register-semantics.ir
python3 scripts/validate_register_ir.py --dump output/register-semantics.ir
python3 scripts/validate_register_ir.py --translate output/register-semantics.ir
python3 scripts/validate_register_ir.py --list-ops
```

`--dump` prints the canonical text form for `audit.md`; `--translate` prints
the QEMU translation worklist (rule -> mechanism/hook/trace/log/error/qtest, plus
unimplemented address placeholders); `--list-ops` prints
the vocabulary. The validator checks shape, arity, operand kinds, references,
flags, and cross-file consistency; it does not prove hardware truth.

## Why this shape

The high-level unit is the Trigger / Condition / Transition triple:

- **Trigger** — the event that starts a rule (a register access, reset, timer,
  IRQ input, DMA completion, command, enable change, or guest action);
- **Condition** — a pure predicate over symbols and literals that must hold at
  the trigger;
- **Transition** — an ordered list of hardware effects (state assignment, FIFO
  operations, IRQ assert/deassert, timer scheduling, DMA, exception, event).

The vocabulary is organized like QEMU's own TCG IR opcode table
(`include/tcg/tcg-opc.h` uses `DEF(name, oargs, iargs, cargs, flags)` with a
`TCGOpDef` arity/flags record): one table, fixed arity, typed operands, and
explicit side-effect flags. The IR borrows that engineering discipline, not the
TCG execution model (no basic blocks, temps, liveness, or register allocation).

## File grammar

One directive per line. Blank lines are ignored. A line whose first non-space
character is `#` is a comment; inline comments are not supported. Rule bodies
are indented and belong to the preceding `rule`. Quoted strings use double
quotes, may contain spaces, and cannot contain a double quote.

```text
ir 1.0
target ip <token>
target variants <token>[,<token>...]
target workload <text>
source <ID> <citation text>
symbol <kind> <name> [key=value ...]
rule <ID> "<summary>" tier=<tier> confidence=<confidence> sources=<ID[,ID...]>
  trigger    <kind> [<subject>] [key=value ...]
  condition  <expression>
  transition [FLAG[,FLAG...]] <operation>(<args>)
  framework  <implementation> hook=<hook> rationale="<non-empty>"
  observe    trace=<event>|none log=<none|unimp|guest_error|both> error=<none|guest_error|error_report|assert>
  qtest      "<assertion>"
  gap        "<unknown>"                # "unknown" is accepted as an alias
  expansion  "<lowering expansion note>"
flow <ID> <rule-id> [ -> <rule-id> ...]
unresolved "<text>"
```

- IDs use letters, digits, and underscores; source citations and summaries are
  quoted when they contain spaces.
- Numbers are decimal or `0x`-hex; bit ranges are `N` or `N..M`.
- Attributes are `key=value`; list values are comma-separated.
- Unknown attributes are allowed on `symbol` and `trigger` (recorded as
  qualifiers) and are errors on `rule`/`framework`.

Symbol kinds and required attributes:

| Kind | Required | Optional |
| --- | --- | --- |
| register | `offset`, `width` | `access`, `reset`, `source` |
| field | `bits` (`N` or `N..M`) | `access`, `reset`, `source` |
| constant | `value` | `source` |
| state | `type` | `range`, `source` |
| event | — | `kind`, `source` |
| irq | — | `kind` (`level` or `edge`), `source` |
| timer | — | `source` |
| fifo | `depth`, `width` | `source` |
| address | `base`, `size` | `status` (`modeled`/`unimplemented`/`reserved`), `placeholder` (required when unimplemented), `source` |

A field name must be `<REGISTER>.<FIELD>`; the register must be declared and
the bit range must fit its width. Every `source=<ID>` must reference a declared
source line. A rule with a guest-visible transition must carry an `observe`
line naming a trace event or a QEMU log mask; a rule with an unimplemented or
logging-only transition needs `log=unimp` (or `both`) and a gap.

### Observability and translation metadata

- `observe trace=<event>`: stable trace event for the rule's material
  transition; used by the model's trace-events file and the qtest evidence.
- `observe log=none|unimp|guest_error|both`: QEMU log mask for the path;
  `unimp` is required for unimplemented/logging-only behavior.
- `observe error=none|guest_error|error_report|assert`: policy for an invalid
  guest access or a model invariant failure.
- `symbol address ... status=unimplemented placeholder=<name>`: the
  board-level placeholder that must exist until the real device lands; the
  board modeling reference owns its lifecycle.

`--translate` renders the validated IR into a TSV worklist:
`kind, id, mechanism, hook, trace, log, error, qtests, placeholder`. The
translation references in `qemu-peripheral-modeling` (RegisterInfo/MMIO,
error handling, trace) and `qemu-board-modeling` (unimplemented device) expand
that worklist into the implementation.

## Vocabulary: assets/ir-ops.def

[ir-ops.def](../assets/ir-ops.def) is the single source of truth for allowed
operations, arity, flags, and operand classes. Each line is:

```text
# DEF(kind, name, arity, flags, signature)
DEF(trigger,   register_write, 1, SIDE_EFFECTS, R)
DEF(condition, all_of,         -1, PURE,         B...)
DEF(operation, assert_irq,      1, SIDE_EFFECTS|GUEST_VISIBLE, I)
```

`kind` is `trigger`, `condition`, or `operation`; `arity` is a fixed operand
count or `-1` for a variadic signature ending in `...`; `flags` is `NONE` or a
`|`-separated union; `signature` is a comma-separated operand-class list (`-`
for no operands).

Operand classes:

| Class | Accepts |
| --- | --- |
| `B` | a nested condition expression |
| `R` | register, field, or state symbol |
| `S` | any symbol |
| `I` | irq symbol |
| `T` | timer symbol |
| `F` | fifo symbol |
| `E` | event symbol |
| `M` | any symbol or a literal |
| `V` | constant symbol or a literal |

## Flags

| Flag | Meaning |
| --- | --- |
| `SIDE_EFFECTS` | the effect is not removable and may be guest-observable |
| `PURE` | a condition predicate; no state change |
| `GUEST_VISIBLE` | the guest can observe the effect |
| `MIGRATABLE` | the touched state belongs in migration state |
| `RESET_AFFECTING` | the effect changes reset-visible state |
| `LOGGING_ONLY` | visibility-only effect; never modeled behavior |
| `EXPANDS` | the operation must be lowered into several implementation steps |
| `UNSUPPORTED` | contextual transition flag: the current model does not implement it |

A transition may declare an explicit comma-separated flag list before the
operation. Explicit flags must be a subset of the operation's DEF flags, except
`UNSUPPORTED`, which is always allowed. Effective flags are the explicit list
when present, otherwise the DEF flags. Rules fail validation when:
`PURE` is used on a transition; `GUEST_VISIBLE`/`MIGRATABLE`/
`RESET_AFFECTING` is used without `SIDE_EFFECTS`; `LOGGING_ONLY` and
`GUEST_VISIBLE` are combined; `EXPANDS` lacks an `expansion` note;
`UNSUPPORTED` lacks a `gap` note; or a rule is logging-only without a `gap`.

## Expressions

Conditions and operation arguments use a small expression grammar:

```text
expr  := call | symbol-ref | number | string
call  := IDENT "(" [expr ("," expr)*] ")"
```

A condition root must be a condition call; nested `B` operands must also be
condition calls. Operation arguments must be atoms (symbol reference, number, or
quoted string), not calls. Every symbol reference must resolve.

## Rule semantics

- **Trigger sampling**: the trigger names the access or event at which the rule
  is evaluated. For a write-triggered rule the condition observes the value
  being written; for a read-triggered rule it observes the state before the
  read effect. Record any exception to this convention in the rule summary or a
  gap.
- **Condition purity**: conditions are side-effect free and read a consistent
  snapshot of the symbols taken at the trigger; a condition must not depend on
  another rule's transition within the same trigger evaluation unless a flow
  states the order.
- **Transition order**: transition operations are applied top to bottom. Effects
  that a guest could observe together are ordered explicitly; do not rely on
  callback registration order.
- **Read versus write side effects**: read side effects are only those the
  hardware performs on a read (clear-on-read, FIFO pop, status latch). Writes
  use post-write hooks or explicit callbacks after storage unless the source
  proves pre-write filtering.
- **Undefined versus unspecified behavior**: record unsupported accesses as
  explicit gaps; do not invent a value for a reserved bit or an unimplemented
  window. If two sources disagree, both stay visible (CONFLICT) until a check
  resolves them.
- **Logging only**: an unimplemented path that logs and returns zeros is a
  placeholder, not modeled behavior, and cannot be the sole basis of a PASS.

## Mapping to a QEMU model

The IR is implementation-neutral; the consumer records the mapping in the
framework decision:

| IR element | QEMU mapping |
| --- | --- |
| trigger + hook | `RegisterAccessInfo` access type + pre/post hook, or a manual `MemoryRegionOps` callback |
| symbol tables | device state fields/arrays and `VMStateDescription` coverage |
| condition predicate | guard inside the callback or pre-write filter; per-rule qtest assertion |
| transition operation | post-write/post-read hook, IRQ line, timer, FIFO, DMA helper, or explicit manual callback |
| `EXPANDS` operation | named expansion sequence in the model (for example DMA -> memory read + state + IRQ), recorded in `expansion` |
| `UNSUPPORTED` / `LOGGING_ONLY` | visible placeholder plus a `gap`; never counted as modeled behavior |
| `observe trace` | trace-event definition and emission at the side-effect site; qtest/runtime evidence links to it |
| `observe log` | `LOG_UNIMP` for unimplemented/logging paths, `LOG_GUEST_ERROR` for invalid guest access |
| `observe error` | error-response policy for the invalid-access or invariant path |
| `status=unimplemented` address | board-level Unimplemented Device placeholder with the named `placeholder`; remove it when the real device lands |
| rule id | comment or trace-event name so tests and trace logs point back to the contract |

Use the framework decision in
[register-contract.md](register-contract.md) and
[the decision template](../assets/framework-decision-template.md); inspect the
checked-out QEMU tree for the current `RegisterInfo` API. Do not generate C
templates from the IR.

## Example

[register-semantics-example.ir](../assets/register-semantics-example.ir) is a
complete fictional demo-timer contract that validates. A rule looks like:

```text
rule R1 "enable periodic mode schedules the period timer" tier=driver confidence=HIGH sources=DRV,MAN
  trigger register_write CTRL
  condition all_of(bit_set(CTRL.EN), eq(CTRL.MODE, MODE_PERIODIC))
  transition schedule_timer(period_timer, PERIOD)
  framework registerinfo hook=post_write rationale="schedule after the register write commits"
  observe trace="demo_timer.r1" log="none" error="none"
  qtest "write CTRL with EN=1 and MODE=PERIODIC, then check the timer is scheduled"
```

## Invariants

- Every rule has one trigger, at least one transition, one framework decision
  with a rationale, and at least one qtest assertion.
- Every guest-visible rule has an `observe` line naming a trace event or log;
  every unimplemented/logging rule uses `log=unimp` (or `both`) and a gap.
- Every unimplemented address carries a placeholder name and a source; the
  translation worklist is produced with `--translate`.
- Every referenced symbol, source, rule id, and operand is declared; every
  condition is pure; every transition operation is in the vocabulary.
- Rule ids are stable across revisions; keep them aligned with qtest names and
  trace events.
- Unknowns stay visible as `gap` or `unresolved` entries; confidence never
  hides a conflict.
- The human contract and the IR carry the same evidence, rule ids, and
  unknowns; when they disagree, the contract is authoritative for behavior and
  the IR must be corrected.
