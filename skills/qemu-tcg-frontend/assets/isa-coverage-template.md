# ISA coverage: <target-name>

Copy this template into `.oh-my-qemu/<task-slug>/output/isa-coverage.md` and fill every
`<placeholder>`. One row per instruction group or encoding family; record unknowns instead of
marking them covered.

## Target

- Target directory: `target/<arch>/`
- ISA name/version and endianness: <isa-version>, <endianness>
- QEMU revision inspected: <git-rev>
- Decode table: `<decode-file>`; translation: `<translate-file>`
- Privilege/feature model: <modes-and-gates>

## Coverage

| Instruction | Encoding | Operands | Feature/privilege gates | Decode/trans | TCG ops/helpers | Invalid cases | Tests | Evidence | Unknowns |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| <ADD-like-name> | <encoding-pattern> | <operands> | <gates> | <trans-function-or-pattern> | <tcg-ops-or-helpers> | <reserved-bits/invalid-widths> | <functional/qtest-name> | <log-or-report-path> | <unresolved> |

## Summary

- Instruction groups implemented: <count>; partial: <count>; not implemented: <count>
- Encodings tested valid/invalid: <counts>
- Test run and result: <command>, <result>
- Unknowns and conflicts: <list>

## Notes

- Keep the encoding table in the checked-out tree authoritative; do not copy values from a
  different QEMU version.
- Record helper flags and TB-end behavior when an instruction raises an exception.
- Link the functional test asset hash when the test binary is external.
