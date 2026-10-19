# TCG backend change: <host-arch>

Copy this template into `.oh-my-qemu/<task-slug>/output/backend-change.md` and fill every
`<placeholder>`. Keep the evidence next to the claim it supports.

## Category

<new host instruction encoder | native emission for existing op | optional op enablement |
constraint or register allocation fix | qemu_ld/st or atomic path | vector op support |
host feature gating | code generation bug investigation>

## Host and toolchain

- Host architecture and features: <arch>, <features>
- Compiler and version: <compiler>, <version>
- QEMU revision inspected: <git-rev>
- Build directory: `builds/build-<target>/`

## IR and op

- Op(s) and semantics source: <op-name>, <tcg-opc.h-and-tcg-ops.rst-section>
- Host support flag: `TCG_TARGET_HAS_<feature>` -> <enabled/disabled>
- Fallback path: <generic expansion or helper>

## Constraints

- `tcg-target-con-str.h`: <added/changed REGS or CONST letters>
- `tcg-target-con-set.h`: <added/changed C_O<n>_I<m> sets>
- Register classes and reserved registers: <changes>

## Emission

- Emission site: `tcg-target.c.inc` <function/area>
- Immediates, sign extension, endianness, clobbers: <notes>
- Branch displacement / relocation / pool handling: <notes>
- Instruction-cache flush needs: <notes>

## qemu_ld/st, atomics, vectors

- MemOp size/sign/endianness: <notes>
- TLB fast/slow path: <notes>
- i128 pairing, atomics, unaligned behavior: <notes>
- Vector coverage and fallback: <notes>

## Tests and logs

- Build command and result: <command>, <result>
- Test coverage: <tests/tcg or other test>, <result>
- TCG IR / host-code logs: <paths>
- Cross-host validation or limitation: <environment or gap>

## Unsupported features

- `TCG_TARGET_HAS_*` still disabled: <list and reason>
- Follow-ups: <next op or constraint work>

## Open questions

- <unverified assumption and the source or test that would resolve it>
