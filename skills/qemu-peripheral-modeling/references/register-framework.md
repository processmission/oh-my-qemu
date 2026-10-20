# Register bank framework reference

Read this when designing or reviewing a guest-visible control/status register
bank. The skill keeps the ordered summary; this file holds the decision record,
the checked-out-tree inspection steps, reference families, `.c` ownership, and
known framework limitations.

## Decision gate

Apply these inputs in order and stop at the first decisive one:

1. Policy present in the target QEMU workspace. Treat checked-out `docs/devel/`
   pages that govern device modeling (for example `qom.rst`, `memory.rst`,
   `secure-coding-practices.rst`, and `style.rst`), a repository-local
   `AGENTS.md` or `README`, and subsystem documentation as candidate policy.
   Record the exact `path:line` you treated as decisive. A MAINTAINERS entry
   names reviewers; it does not decide a modeling framework.
2. The user's explicit compatible framework direction. Record the quote or
   request reference and why it is compatible. Conflicting direction is not
   decisive.
3. A clear maintained convention in a nearby device of the same subsystem.
   Cite `path:line` and prefer recently maintained code.

When none decides, use `RegisterInfo` from the checked-out tree. A nearby
convention is decisive only when it is the **same subsystem**, actively
maintained, and has a comparable **control/status** bank; cite the exact
`path:line` and explain the semantic match. "Most nearby devices use manual
MMIO" is not a decision input.

Manual MMIO for a control/status bank is exceptional. It is permitted only when
the bank has a command, FIFO, DMA, timing, or reentrant structure that
`RegisterInfo` cannot express without distortion. Split hybrid models instead
of choosing manual for the whole window: control/status fields on
`RegisterInfo`, plus explicit `MemoryRegionOps` for the command/data aperture.
Time pressure, round budget, register count, and "every register has side
effects" are not decisive inputs.

A missing, vague, or unsupported framework decision is a review BLOCKER. The
decision must state the bank kind, the decisive input (or "none, default"),
whether the bank is hybrid, and the structural reason when manual MMIO is
selected.

## Decision record for `audit.md`

Record one row per bank, for example:

| Field | Value |
| --- | --- |
| Bank | `<device> <window name/base>` |
| Purpose | `<control/status or data>` |
| Target-workspace policy | `<path:line>` or `none found` |
| User direction | `<quote or request path; compatible?>` |
| Nearby convention | `<file:line of maintained sibling>` |
| Selected framework | `RegisterInfo` or `manual MMIO` |
| Accepted limits | `<access sizes, side effects, reentrancy>` |
| Rationale | `<one or two sentences>` |
| Verification | `<qtests or trace evidence>` |

## From semantic IR to the model

When qemu-register-extraction hands off a validated RS-IR
`.oh-my-qemu/<task-slug>/output/register-semantics.ir`, use it as the model
worklist: each rule names one trigger, condition, and transition to implement and
verify. The rule/operation vocabulary is that skill's `assets/ir-ops.def`
(DEF table with arity and flags); read its semantic IR reference for the grammar
and operand classes. This section maps the DSL vocabulary to the checked-out
QEMU model. Do not generate C from the IR: write the model by hand in the device
`.c` file and keep the IR as the reviewable mapping source.

### Trigger and hook mapping

| IR trigger | `RegisterInfo` access or implementation site |
| --- | --- |
| `register_read` | read access; `post_read` only for guest-visible read side effects |
| `register_write` | write access with mask/reserved-bit handling; `pre_write` filters, `post_write` applies side effects |
| `field_write` | write access with field mask; `pre_write` decodes the field |
| `reset` | device reset hook or `register_reset` |
| `timer_expiry` | timer callback, not a register access |
| `irq_in` | `qemu_irq` input handler, not `RegisterInfo` |
| `dma_complete` | DMA completion callback or bottom half |
| `command` | manual `MemoryRegionOps` callback or a helper entry point |
| `enable_change` | `pre_write`/`post_write` on the enable register |
| `guest_action` | branch in the manual MMIO callback or device helper |

### Operation mapping

| IR operation | Side-effect site |
| --- | --- |
| `assign_field`, `set_bits`, `clear_bits`, `toggle_bits`, `inc_field`, `dec_field` | post-write hook or backing-storage update |
| `fifo_push`, `fifo_pop` | explicit `MemoryRegionOps` data aperture plus FIFO state |
| `assert_irq`, `deassert_irq` | post-write or timer/DMA callback; update status first |
| `schedule_timer`, `cancel_timer` | timer API from the checked-out tree |
| `dma_read`, `dma_write` | address-space or DMA helper |
| `raise_exception` | documented device error path |
| `emit_event`, `log_unimp` | trace event or `LOG_UNIMP`; logging only, not modeled behavior |
| `set_state` | device state field, included in `VMState` when migratable |
| `clear_on_read` | post-read hook, guest-visible only |

A rule whose only side effect is `logging_only` provides visibility, not
behavior; do not count it as modeled success or as qtest coverage.

### Traceability

Preserve each rule id when implementing: use it in a comment beside the
`RegisterAccessInfo` entry or callback, in the trace event name or payload, and
in the qtest that asserts the rule. A model change that has no matching rule id
either needs a new IR rule or is implementation detail outside the contract. When
the IR and the code disagree, fix one deliberately and record the change in
`audit.md`.
## Inspect the checked-out tree

Do not use remembered API signatures. In the tree under test:

- `include/hw/core/register.h` for the current `RegisterAccessInfo`,
  `RegisterInfo`, `RegisterInfoArray`, and `register_init_block*` API;
- `include/hw/core/registerfields.h` for the register and field macros;
- `hw/core/register.c` for ownership and reset behavior;
- search the tree by symbol for `RegisterAccessInfo`, `register_init_block8`,
  `register_init_block32`, `register_init_block64`, `register_read_memory`,
  `register_write_memory`, `register_reset`, and `register_array_get_owner`.

Inspect same-subsystem examples before generic ones. Reference families to
start from:

- simple register bank with callbacks and VMState:
  `hw/dma/xlnx-zynq-devcfg.c`;
- IRQ/status register side effects: `hw/intc/xlnx-zynqmp-ipi.c`;
- wrapped read/write handlers that still delegate to `RegisterInfo`:
  `hw/misc/xlnx-versal-trng.c`;
- broader banks: search `hw/misc`, `hw/dma`, `hw/intc`, `hw/nvram`, and
  `hw/rtc` for `register_init_block32`.

If a named path is absent in another QEMU version, re-search by symbol instead
of assuming the old path. Record the version or commit inspected.

## `.c`-file ownership

Keep the complete register definition in the device `.c` file:

- register offsets and field definitions from the registerfields macros;
- backing storage sized from the register map;
- the matching `RegisterInfo` array and `RegisterAccessInfo` table when selected;
- manual read/write callbacks and `MemoryRegionOps` when selected;
- register-local read, write, and reset hooks;
- reset logic for the selected framework;
- `VMState` for guest-visible register storage and other migratable state.

Do not put register offsets, field macros, access tables, backing storage, or
register semantics in a header. A header may expose only non-register-layout
declarations genuinely required outside the device translation unit, such as a
public QOM type or a cross-unit helper prototype.

When using `RegisterInfo`, use its hooks deliberately:

- pre-write hooks filter or transform a write before storage;
- post-write hooks apply IRQ, status, timer, or DMA side effects after storage;
- post-read hooks are only for guest-visible read side effects;
- register reset can run write hooks, so callbacks must be reset-safe.

## Known framework and device limitations

Verify each in the checked-out tree before relying on it.

- `RegisterInfoArray` leaf ownership: `register_init_block*` creates an
  internal `TYPE_REGISTER_ARRAY` child and initializes the access
  `MemoryRegion` with that object as owner. `MemoryRegion.dev` therefore is not
  the `DeviceState`, so the generic memory reentrancy guard in
  `system/memory.c` (which checks `mr->dev`) does not cover these callbacks.
  Guard reentrancy explicitly in the callback when it can re-enter.
- FIFO, queue, and other streaming data apertures need explicit
  `MemoryRegionOps`; `RegisterInfo` tables fit indexed control/status storage.
- Block-device permissions: `BLK_PERM_ALL` includes `BLK_PERM_RESIZE`
  (`include/block/block-common.h`). If capacity is fixed, exclude
  `BLK_PERM_RESIZE` from the permissions you request so an online resize cannot
  silently diverge from cached state.
- Cached capacity: many devices cache capacity at initialization, reset, or on
  a capacity query (a SCSI disk's `max_lba` is refreshed by READ CAPACITY and
  reset). If the model can hold stale capacity, decide whether resize is
  supported and reject it when it is not; cover the boundary with a qtest.
- 32-bit LBA: the LBA field in 10-byte and 12-byte READ/WRITE CDBs is 32 bits
  (`scsi_cmd_lba` masks to 32 bits in `scsi/utils.c`). With 512-byte sectors
  that caps usable capacity at 2 TiB; 16-byte CDBs carry the 64-bit LBA. Claim
  only the capacity the CDB set can address in the tree under test.

## When manual MMIO is the right choice

Prefer manual `MemoryRegionOps` only for streaming, command, configuration
view, or timing apertures whose access semantics the register framework cannot
express without distortion, or where explicit reentrancy control is required.
Record the **structural reason** in the decision record: which behavior cannot
be expressed by `RegisterAccessInfo` hooks, and which limits are accepted.

For a mixed block, keep control/status registers on `RegisterInfo` and put the
command/FIFO/data aperture in manual `MemoryRegionOps`. A whole-window manual
choice needs an explicit reason why splitting is not possible. "Neighboring
devices are manual", "the register bank is large", and "we are in a hurry" are
not structural reasons.
