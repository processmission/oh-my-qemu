# RS-IR to RegisterInfo translation

Use this reference after the register-semantics IR (RS-IR) validates and before
writing a device model. It defines how each rule becomes QEMU implementation
code, how errors and unimplemented paths are handled, and what trace/log evidence
the model must produce.

The translation is a design step, not code generation. Inspect the checked-out
QEMU tree for the current RegisterInfo API and the local device conventions; do
not copy remembered signatures.

## Translation record

Record one row per rule in `.oh-my-qemu/<task-slug>/audit.md`:

| Rule | Mechanism | Hook | State/migration | Trace event | Log/error policy | qtest |
| --- | --- | --- | --- | --- | --- | --- |

- **Mechanism** comes from the rule's `framework` line: `registerinfo`,
  `manual-mmio`, or `helper`.
- **Hook** comes from the same line: `pre_write`, `post_write`, `post_read`,
  `manual`, or `reset`.
- **Trace event** and **log/error policy** come from the rule's `observe` line.
- **qtest** names the narrow test that proves the rule; the rule id is kept in a
  comment or the test name.

## RegisterInfo mapping

For a `registerinfo` rule:

1. Define register offsets, field macros, and reset values in the device `.c`
   file from the RS-IR symbols; do not put them in a header.
2. Build the `RegisterInfo` array and `RegisterAccessInfo` entries for the
   bank, using the checked-out tree's current API and nearby devices.
3. Map the trigger:
   - `register_read` / `register_write`: the access type and allowed widths;
   - `field_write`: the field mask and `pre_write` decode where needed;
   - `register_read` with read side effects: `post_read`, never a pre-read
     mutation;
   - `reset`: reset hook or `register_reset`.
4. Map each condition to the guard that must hold before the transition, using
   the same operand order as the rule. A condition that cannot be evaluated in
   the hook is a gap, not an invented assumption.
5. Map each transition operation to its side-effect site:
   - field/state updates: post-write or reset hook;
   - IRQ raise/lower: after updating status, through the wired `qemu_irq`;
   - timers: the checked-out timer API;
   - FIFO/data apertures: explicit `MemoryRegionOps`, not the RegisterInfo
     array;
   - DMA: address-space helpers with validated ranges;
   - exceptions/events/logging: the documented device path.
6. Put guest-visible state in `VMStateDescription` when the rule declares
   `MIGRATABLE`; keep local caches out of migration.

## Manual MMIO mapping

For a `manual-mmio` or `helper` rule:

- One `MemoryRegionOps` per register window or data aperture; reject
  unsupported access widths explicitly.
- Keep callbacks allocation-free and bounded; long work belongs in timers,
  bottom halves, or workers.
- Reentrancy: a leaf region owned by `RegisterInfoArray` may not expose a
  `DeviceState` through `mr->dev`; use an explicit reentrancy guard in device
  state for FIFO or DMA callbacks.
- A FIFO or streaming aperture is always an explicit `MemoryRegionOps`
  aperture even when the control/status bank uses `RegisterInfo`.

## Error handling matrix

Classify every error path before writing code:

| Situation | Required handling |
| --- | --- |
| Guest writes a read-only or reserved field | ignore the write and `qemu_log_mask(LOG_GUEST_ERROR, ...)` with the access details |
| Guest uses an unsupported access width or alignment | reject or handle per the register contract; log `LOG_GUEST_ERROR` |
| Guest reaches an unimplemented window or placeholder device | trace the access and `LOG_UNIMP`; never fake ready status silently |
| Model invariant violated (corrupt state, impossible FIFO transition) | `error_report` or assert with the rule id; do not continue with corrupted state |
| Guest-triggered DMA/address error | report through the documented device error path and log the guest error |
| Internal host/resource failure | `error_report` / `error_setg`, return the failure; never hide it |

- `LOG_UNIMP` means "this path is deliberately not modeled"; it is visibility,
  not modeled behavior.
- `LOG_GUEST_ERROR` means "the guest did something the hardware would reject";
  use it for invalid access, not for internal model errors.
- A diagnostic sink that returns zeros or a fake status to keep boot moving is a
  placeholder. Record it as a gap and never count it as a PASS basis.

## Trace events

The `observe` line names the evidence path. For a material rule:

- define a stable trace event named from the device and rule id, for example
  `<device>.<rule-id>` or the local subsystem's naming convention;
- place the event at the side-effect site, after status is updated and before
  the IRQ line change when ordering matters;
- emit one event per material transition, not per byte or per poll unless the
  trace contract says otherwise;
- correlate the event with guest-visible output in the qtest or runtime
  evidence; trace counts alone are not correctness proof;
- keep the trace-event definition in the device's trace-events file and record
  the event name in the translation table.

If a rule is guest-visible and has no trace event, record `log=...` and the qtest
that proves it; if neither trace nor log exists, add a `gap` entry.

## qtest mapping

Each rule gets at least one narrow qtest assertion:

- reset value and access masks first;
- condition false/true boundaries;
- each material transition (IRQ, timer, FIFO, DMA, clear-on-read);
- invalid-access and unimplemented-path behavior when the rule declares it;
- rule id in a comment or test name so the test can be traced back to the
  contract.

Do not treat a boot banner or trace count as a substitute for the rule qtest.
Add tests only within the requested scope; if the user removes a requested test,
remove its registration cleanly and record the change.

## Translation checklist

- [ ] Every rule has a mechanism, hook, and qtest row.
- [ ] Every guest-visible rule has an `observe` line naming a trace event or log.
- [ ] Every `UNSUPPORTED` or `LOGGING_ONLY` transition has `log=unimp` (or
      `both`) and a gap.
- [ ] Every unimplemented address symbol has a board-level placeholder name.
- [ ] Register layout, storage, tables, and hooks live in the device `.c` file.
- [ ] Error paths follow the matrix above; no silent sink is counted as modeled.
- [ ] The RS-IR validation result and translation table are recorded in the audit.

## Worked mapping (fictional demo timer)

From `register-semantics-example.ir`:

| Rule | Mechanism | Hook | Trace | Log/error | qtest |
| --- | --- | --- | --- | --- | --- |
| R1 | registerinfo | post_write | demo_timer.r1 | none | write CTRL with EN=1 and MODE=PERIODIC, then check the timer is scheduled |
| R2 | manual-mmio | manual | demo_timer.r2 | error=guest_error | advance the virtual clock past PERIOD; check counter and irq0 |

The address symbol `UNMODELED_WINDOW` is `status=unimplemented` with
`placeholder=board_unimpl`; the board-level placeholder is handled by
`qemu-board-modeling/references/unimplemented-device.md`, and it must be removed
when the real device replaces it.

## Boundaries

- Local-only modeling and verification; do not prepare upstream-ready code,
  commit messages, or patches from this translation.
- Do not generate C templates or upstream patches. The consumer writes the model
  by hand and keeps the translation table as the reviewable mapping.
