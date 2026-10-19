# Unimplemented Device placeholders

Use this reference when a board or SoC needs a window that is not modeled yet.
The Unimplemented Device is a **board-level placeholder**: it makes memory and
boot paths work, keeps the unmodeled window visible, and is removed when the
real device model and its RS-IR rules land.

## Ownership

- **Board/SoC** owns the unimplemented placeholder entry (base, size, name,
  owner, reason, source).
- **Peripheral modeling** owns the real device implementation. The placeholder
  is not a device model and must not grow register behavior.
- The RS-IR `symbol address` with `status=unimplemented` and
  `placeholder=<name>` is the extraction-side input; the board's unimplemented
  map is the implementation-side record. Keep the two names aligned.

## When to create a placeholder

Create a placeholder when all of the following hold:

- the window is guest-reachable and boot or the first workload needs the
  address to exist;
- no real device model exists yet;
- the window is listed in the unimplemented map with a cited base and size;
- the alternative (removing the window) would abort or misroute the guest in a
  way that hides the real first failure.

Do not create a placeholder for a window that is already covered by another
model, for secure-only windows outside the tested privilege level, or for
memory already modeled as RAM/ROM.

## Implementation shape

- One board/SoC-level entry per window with a stable name, base, size, owner,
  reason, and source.
- The backing region logs guest access and returns the documented placeholder
  value (normally zero) with `LOG_UNIMP`; do not pretend it is modeled behavior.
- Emit a trace event for placeholder access when the local board has a trace
  convention; otherwise `LOG_UNIMP` is the minimum visibility.
- Never fake a ready/status bit merely to let firmware continue unless the
  contract explicitly documents the placeholder value and the resulting gap.
- Invalid accesses to a modeled window use `LOG_GUEST_ERROR`; accesses to a
  placeholder use `LOG_UNIMP`. Do not mix the two meanings.
- Keep the placeholder out of device state, VMState, and migration claims.

## Lifecycle

1. **Plan**: add the row to the unimplemented map with source, and reference the
   RS-IR address symbol/`placeholder` if present.
2. **Create**: add the board placeholder, trace/log it, and record what firmware
   or guest path depends on it.
3. **Model**: implement the real device from the RS-IR rules and qtests;
   the new device owns the register behavior, state, IRQ, and migration.
4. **Replace**: point the board at the real device in the same change that makes
   it usable; remove the placeholder row and the placeholder code.
5. **Verify**: rebuild, rerun the affected qtests and boot evidence, confirm the
   trace no longer reports `LOG_UNIMP` for that window, and record the result.

A placeholder that survives past the real device landing is stale topology:
remove it or reopen the map with a source-backed reason.

## RS-IR mapping

| RS-IR input | Unimplemented Device action |
| --- | --- |
| `symbol address ... status=unimplemented placeholder=<name>` | add/keep a board placeholder with that name; record base, size, source |
| rule with `UNSUPPORTED` transition and `log=unimp`/`both` | keep the placeholder and record the gap; do not claim modeled behavior |
| rule with only `LOGGING_ONLY` operations | placeholder/visibility path; gap required; no PASS basis |
| rule with `framework registerinfo` or `manual-mmio` and implemented qtests | replace the placeholder with the real device; remove the map row |
| address symbol `status=modeled` | model owns the window; no placeholder |

Board-level windows and device-level registers are different scopes: a
placeholder covers a window; a device model covers behavior inside it. Do not
put register semantics into the placeholder.

## Error and observability rules

- Guest access to a placeholder: `LOG_UNIMP` (plus a trace event where the board
  has one); never silently return a fabricated ready bit.
- Guest access to a modeled window with an invalid width/field: `LOG_GUEST_ERROR`.
- Internal topology error (overlap with RAM or another device): report at
  realize time, do not boot with an ambiguous map.
- The boot log must make the placeholder visible; if the guest stays silent,
  record that as a limitation rather than as success.

## Verification

- qtest: instantiate the machine and probe the placeholder window; assert the
  unimp log/trace path when the board exposes it.
- Boot evidence: the guest reaches the next real stage; the log shows the
  placeholder rather than a model error.
- After replacement, rerun the same probes against the real device and confirm
  the placeholder log disappears.
- Record the map path, placeholder name, trace/log evidence, replacement commit
  or change, and residual gaps in `audit.md`.

## Anti-patterns

- Placeholder with register behavior, side effects, or IRQ state.
- Placeholder counted as modeled behavior in a PASS claim.
- Duplicated windows at both SoC and board level.
- A "temporary" placeholder that remains after the real device lands.
- Silent zero-return sink with no `LOG_UNIMP`.
- Removing the unimplemented map row without replacing the window.
