# RS-IR and Translation Targets

> [中文](rs-ir-and-translation.md) · **English**

RS-IR (Register Semantics Intermediate Representation) is the machine-readable
intermediate representation between register extraction and device modeling. It
abstracts register behavior into **Trigger / Condition / Transition** rules and
provides a fixed vocabulary, a validator, and a translation worklist for QEMU
mechanisms.

## Outputs and locations

A complete register extraction produces:

- `output/register-contract.md`: the human behavior contract and the
  authoritative record for review;
- `output/register-semantics.ir`: the RS-IR text companion;
- raw trace/GDB/QEMU debug evidence stays in `logs/` or its original path and is
  not copied into the IR.

Templates, example, vocabulary, validator:

- `skills/qemu-register-extraction/assets/register-semantics-template.ir`
- `skills/qemu-register-extraction/assets/register-semantics-example.ir`
- `skills/qemu-register-extraction/assets/ir-ops.def`
- `skills/qemu-register-extraction/scripts/validate_register_ir.py`

## The triple and the vocabulary

| Primitive | Role |
| --- | --- |
| Trigger | event: register read/write, field write, reset, timer expiry, IRQ input, DMA completion, command, enable change, guest action |
| Condition | pure predicate: all_of/any_of/not, eq/ne/lt/le/gt/ge, bit_set/bit_clear, masked_eq, in_range, fifo_*, counter_cmp |
| Transition | ordered operations: field/state assignment, set/clear/toggle bits, FIFO push/pop, IRQ assert/deassert, timer scheduling, DMA, exception, event, clear_on_read, log_unimp |

Operand classes (DEF signatures):

| Class | Accepts |
| --- | --- |
| B | nested condition expression |
| R | register / field / state symbol |
| S | any symbol |
| I / T / F / E | irq / timer / fifo / event symbol |
| M | symbol or literal |
| V | constant symbol or literal |

Flags:

- `SIDE_EFFECTS`, `PURE`, `GUEST_VISIBLE`, `MIGRATABLE`,
  `RESET_AFFECTING`, `LOGGING_ONLY`, `EXPANDS`, `UNSUPPORTED`.

## Text example

```text
ir 1.0
target ip demo-timer-1.0
target variants demo-soc
target workload "periodic timer interrupt"
source DRV "drivers/demo-timer.c:10-120"
source MAN "Demo Timer TRM, section 4"

symbol register CTRL offset=0x00 width=32 access=rw reset=0x0 source=DRV
symbol field CTRL.EN bits=0 access=rw source=DRV
symbol field CTRL.MODE bits=1..2 access=rw source=MAN
symbol constant MODE_PERIODIC value=1 source=MAN
symbol constant PERIOD value=1000
symbol timer period_timer source=DRV
symbol irq irq0 kind=level source=MAN
symbol address UNMODELED_WINDOW base=0x1000 size=0x100 status=unimplemented placeholder=board_unimpl source=MAN

rule R1 "enable periodic mode schedules the period timer" tier=driver confidence=HIGH sources=DRV,MAN
  trigger register_write CTRL
  condition all_of(bit_set(CTRL.EN), eq(CTRL.MODE, MODE_PERIODIC))
  transition schedule_timer(period_timer, PERIOD)
  framework registerinfo hook=post_write rationale="schedule after write commits"
  observe trace="demo_timer.r1" log="none" error="none"
  qtest "write CTRL with EN=1 and MODE=PERIODIC, then check timer scheduled"

flow init R1
unresolved "PERIOD is not documented"
```

## observe and placeholders

- `observe trace=<event>`: stable trace event for a material transition;
- `observe log=none|unimp|guest_error|both`: QEMU log mask;
- `observe error=none|guest_error|error_report|assert`: policy for invalid
  access or internal invariant failure;
- guest-visible rules must have observe (trace or log);
- `UNSUPPORTED` / `LOGGING_ONLY` must use `log=unimp` (or both) and a gap;
- `symbol address ... status=unimplemented placeholder=<name>`: board-level
  Unimplemented Device placeholder, removed when the real device lands.

## Translation targets

### 1. Peripheral behavior -> RegisterInfo

| RS-IR element | QEMU implementation |
| --- | --- |
| framework registerinfo + trigger/hook | `RegisterAccessInfo` access type and pre/post hook |
| symbol tables | device state + `VMStateDescription` |
| condition | callback guard / pre-write filter |
| transition | post-write/post-read hook, IRQ, timer, FIFO, DMA, exception |
| rule id | model comment / trace event / qtest name |

### 2. Board placeholders -> Unimplemented Device

- `status=unimplemented` address -> board/SoC placeholder with
  base/size/name/owner/source;
- the placeholder only makes the address exist and visible (trace/`LOG_UNIMP`);
  it does not implement register behavior;
- remove the placeholder and its map row in the same change that lands the real
  device;
- a placeholder is not modeled behavior and cannot be a PASS basis.

### 3. Error handling and observability

| Situation | Requirement |
| --- | --- |
| guest writes a read-only/reserved field | ignore write + `LOG_GUEST_ERROR` |
| unsupported width/alignment | reject/handle per contract + `LOG_GUEST_ERROR` |
| guest accesses an unimplemented window/placeholder | trace + `LOG_UNIMP`; never fake ready |
| model invariant broken | `error_report` / assert with the rule id |
| guest-triggered DMA/address error | documented error path + guest error |
| host/resource failure | `error_report` / `error_setg`; never hide it |

## Translation worklist

```bash
python3 skills/qemu-register-extraction/scripts/validate_register_ir.py \
    .oh-my-qemu/<task-slug>/output/register-semantics.ir
python3 skills/qemu-register-extraction/scripts/validate_register_ir.py --translate \
    .oh-my-qemu/<task-slug>/output/register-semantics.ir
```

`--translate` emits TSV:

```text
kind    id               mechanism            hook        trace            log    error        qtests  placeholder
rule    R1               registerinfo         post_write  demo_timer.r1    none   none         1       -
rule    R2               manual-mmio          manual      demo_timer.r2    none   guest_error  1       -
address UNMODELED_WINDOW unimplemented-device -           -                -      -            0       board_unimpl
```

Implement the model and tests from this worklist. See
`skills/qemu-peripheral-modeling/references/ir-to-registerinfo.md` and
`skills/qemu-board-modeling/references/unimplemented-device.md`.

## Relationship to the human contract

- `register-contract.md` is the behavior authority; RS-IR is the machine-readable
  companion;
- both share evidence, rule ids, and unknowns; if they conflict, fix the IR from
  the contract;
- the validator checks structure/references/flags/arity only. It does not prove
  hardware truth; sources still require human verification.

## Boundaries

- Local modeling/verification artifact; never an upstream submission.
- No generated C templates; the agent or human writes the model from the IR.
- Do not treat a logging sink, placeholder, or boot banner as modeled behavior.

## Related docs

- [architecture.md](architecture.md)
- [modeling-workflow.md](modeling-workflow.md)
- `skills/qemu-register-extraction/references/semantic-ir.md`
- `skills/qemu-register-extraction/assets/ir-ops.def`
