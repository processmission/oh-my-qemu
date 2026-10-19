# Qtest plan: <test-name>

Copy this plan into `.oh-my-qemu/<task-slug>/audit.md` (or keep it beside the
test) and fill every placeholder before writing code. One plan covers one test
file; split unrelated claims into separate plans.

## Claim

- Claim: <one falsifiable sentence about guest-visible behavior>
- Evidence source: <register contract, model source, or TRM page/section>
- Semantic IR rule ids (optional): <rule ids>

## Placement

- Test source: `tests/qtest/<test-name>.c`
- Registration bucket: <qtests_<arch> | qtests_generic>
- Machine and options: `-machine <machine> <extra options>`
- Fixture: <qtest_init extra arguments or qgraph nodes>
- Lifecycle: `qtest_init*` at <setup point>, `qtest_quit` at <teardown point>

## Accesses and assertions

| # | Kind | Address / object | Write value | Expected result | Expected-value source |
|---|------|------------------|-------------|-----------------|-----------------------|
| 1 | MMIO read/write | <0x...> | <value> | <value> | <source> |
| 2 | IRQ assert/deassert | <line> | - | <level> | <source> |
| 3 | Virtual-clock step | <nanoseconds> | - | <timer state> | <source> |
| 4 | DMA / QMP / other | <descriptor or command> | - | <effect> | <source> |

- Reset values checked: <list>
- Masks and reserved bits checked: <list>
- Read-only / write-only / W1C behavior checked: <list>
- Negative cases: <invalid command, unsupported width, error path>
- Must not depend on: <model-internal framework, private state>

## Run and evidence

From the QEMU source root:

```bash
builds/build-<target>/pyvenv/bin/meson test \
  -C builds/build-<target> qtest-<arch>/<test-name>
```

- Registration check from the installed skill directory:
  `bash scripts/check-registration.sh --meson tests/qtest/meson.build` with
  `--source tests/qtest/<test-name>.c --arch <arch>`.
- Log: `.oh-my-qemu/<task-slug>/logs/<test-name>.log`
- Verdict vocabulary: PASS | FAIL | INCONCLUSIVE
- What this test does not prove: <remaining gap>
