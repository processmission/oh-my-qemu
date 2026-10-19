# Peripheral modeling patterns

Reusable patterns and review checklists for device models. Verify every API and
path in the checked-out tree; this file deliberately avoids version-specific
signatures.

## Unimplemented register block with logging

Use one placeholder region per unimplemented hardware block:

- read callback: emit `qemu_log_mask(LOG_UNIMP, ...)` with device name, address,
  and access size, then return zero;
- write callback: emit `qemu_log_mask(LOG_UNIMP, ...)` and ignore the value;
- invalid width or out-of-range access: `LOG_GUEST_ERROR`;
- do not store register values, do not fake status bits, and do not raise IRQs;
- keep the region out of modeled-register qtests and list it in the
  unimplemented map with the log mechanism noted.

A placeholder that satisfies a guest poll loop is a false positive: the guest
sees a completed operation the hardware never performed.

## Trace-event split for wide summaries

Use two event classes instead of one mixed event:

- a summary event for state transitions and aggregate counters (command,
  descriptor count, total bytes, completion status);
- a detail event for individual operations worth keeping in bounded volume;
- never emit one event per payload byte or per DMA beat;
- include the instance id in the event name or payload;
- keep guest-visible state in device state, and treat trace output as evidence,
  not as the source of truth.

## IRQ wiring table

Record the wiring in `audit.md` before coding:

| Output | Source register/bit | Level or edge | Mask/enable | Clear path | Routed to |
| --- | --- | --- | --- | --- | --- |

- one `qemu_irq` per real output line; do not merge unrelated sources;
- update status before raising or lowering the line;
- clear or acknowledge in the documented order (status, mask, controller);
- cover assert, mask, and W1C-clear paths in qtests.

## Multi-instance devices

- keep per-instance state in the device structure; no file-scope mutable state;
- expose an instance id or count property only when the hardware varies;
- one `MemoryRegion` per instance, named from the instance id;
- prefix trace events with the instance id;
- qtest with two instances to catch shared-state bugs.

## FIFO, queue, and status patterns

- data aperture through explicit `MemoryRegionOps`; control/status registers
  may stay in the selected register framework;
- keep occupancy, full, empty, and overflow bits derived from one source of
  truth, not mirrored ad hoc;
- watermark IRQ updates after every push or pop; overflow and underflow have
  explicit clear behavior;
- qtest: fill, drain, overflow, underflow, watermark IRQ, reset while busy.

## Reentrancy

- MMIO callbacks can trigger DMA, timers, or bottom halves that re-enter the
  same device region; set a guard flag in device state and document the
  allowed reentrant paths;
- do not rely on the generic memory reentrancy guard for `RegisterInfo` leaf
  regions; their owner is the internal register array, not the device;
- avoid long synchronous backend operations inside a callback; defer to a
  bottom half or coroutine;
- qtest: issue the trigger write while an operation is in flight and verify
  state integrity.

## Block permission and capacity review checklist

- permissions and shared permissions are explicit, not `BLK_PERM_ALL` by
  default; verify the constant set in `include/block/block-common.h`;
- capacity fixed after initialization? then do not hold `BLK_PERM_RESIZE`;
- capacity dynamic? implement the resize path and test it, including cached
  size fields;
- 32-bit LBA CDBs cap capacity at 2 TiB with 512-byte sectors; use 16-byte
  CDBs when the model must address more;
- test a sparse backend beyond the advertised boundary and confirm the device
  rejects or exposes it deliberately;
- record backend format, permissions, and boundary cases in `audit.md`.

## DMA and address validation

- validate guest DMA addresses with QEMU address-space or DMA helpers before
  use;
- record descriptor ownership and completion order;
- qtest: program a DMA window, verify guest memory effects, and verify an
  invalid address produces the documented error, not a host abort.

## qtest candidates per pattern

| Pattern | Candidate coverage |
| --- | --- |
| Unimplemented block | read/write logs under `-d unimp`; no fake success |
| Trace split | summary counters match guest-visible status |
| IRQ wiring | assert, mask, W1C clear, controller route |
| Multi-instance | two instances stay independent |
| FIFO/queue | fill, drain, overflow, watermark IRQ |
| Reentrancy | trigger during in-flight work, no corruption |
| Block capacity | sparse boundary, permission rejection, resize path |
| DMA | guest-visible memory effects and invalid-address error |

Add only the tests the requested scope needs; remove one only with a recorded
reason.

## From IR conditions and transitions to qtest assertions

When the RS-IR (`register-semantics.ir`) is available, each rule gives the test list: one
narrow assertion per material condition and transition. Name the rule id in the
test comment or evidence note so the model comment, trace event, and test can be
cross-checked without reading the IR.

| IR condition or transition | qtest assertion |
| --- | --- |
| W1C condition (`bit_set` on status with masked enable) | write the trigger, read status, verify clear and line state |
| RO or reserved field (`eq`/`ne`) | write is ignored, read returns the documented value, reset value is checked |
| FIFO status (`fifo_empty`, `fifo_full`, `fifo_level`) | fill and drain to each boundary, read the status bits |
| Timer expiry (`timer_expiry`, `counter_cmp`) | program the timer, advance the virtual clock, check expiry status and IRQ |
| IRQ assert/deassert (`assert_irq`, `deassert_irq`) | intercept the line and verify assert, mask, and W1C clear paths |
| DMA effect (`dma_read`, `dma_write`) | program the DMA, verify guest memory effects and completion |
| Clear-on-read (`clear_on_read`) | read twice and verify the documented one-shot behavior |
| Logging only (`log_unimp`, `logging_only`) | guest access logs under `-d unimp`; never accepted as modeled success |

Traceability rule: keep the rule id in the qtest comment and the evidence path.
A test that cannot name the rule it proves is probably testing an implementation
detail; add the rule to the IR or drop the assertion.
