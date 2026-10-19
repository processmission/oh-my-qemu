# Register bank framework decision record

Copy this record into `.oh-my-qemu/<task-slug>/audit.md` (or link it from
there), replace every `<placeholder>`, and keep the semantic rule ids with the
implementation mapping.

## Bank

- Device: `<device-name-and-type>`
- Window: `<window-name-base-size>`
- Purpose: `<control-status-or-data>`

## Decision inputs (apply in order, stop at the first decisive input)

| Input | Evidence | Decisive? |
| --- | --- | --- |
| Target-workspace policy | `<path:line>` or `none found` | `<yes/no>` |
| User direction (compatible) | `<quote or request path>` | `<yes/no>` |
| Nearby maintained convention | `<file:line>` | `<yes/no>` |

## Chosen framework

- Implementation: `<RegisterInfo | manual MMIO | helper>`
- Decisive input: `<row from the table above>`
- Rationale: `<one or two sentences>`
- Semantic rule ids mapped here: `<rule-id>, <rule-id>`
- Accepted limits: `<access sizes, side effects, reentrancy>`

## Implementation mapping

| IR trigger and hook | Implementation site |
| --- | --- |
| `<trigger>` / `<hook>` | `<RegisterInfo access hook or callback>` |
| `<transition-operation>` | `<side-effect site>` |

## Unbounded surfaces

- FIFO or data aperture: `<explicit MemoryRegionOps name>` or `none`
- Reentrancy guard: `<explicit flag in device state>` or `core guard only`
- Other manual callback: `<reason>` or `none`

## Evidence links

- Register contract: `.oh-my-qemu/<task-slug>/output/register-contract.md`
- Semantic IR (RS-IR): `.oh-my-qemu/<task-slug>/output/register-semantics.ir`
- IR validation: `<PASS line or log path>`
- Source citations: `<path:line, manual page/section>`
