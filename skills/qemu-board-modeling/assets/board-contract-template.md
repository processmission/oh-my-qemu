# Board contract: <board-name>

Copy this template into `.oh-my-qemu/<task-slug>/output/board-contract.md` and fill every
`<placeholder>`. Keep the sources next to the facts they justify; delete sections that do not
apply instead of leaving empty tables.

## Baseline and sources

- Source tree and revision: `<path>` at `<git-rev-or-archive-id>`
- Reference hardware manual: <title>, edition <edition>, page/section <section>
- Vendor SDK / firmware / OS target: <name-and-version>
- Closest upstream QEMU reference board: `<path-to-source>`
- Naming evidence for board and SoC: <vendor documentation or DTS path>

## Machine identity

- QEMU machine type: `<machine-name>` (`-M <machine-name>`)
- Source layout: machine `hw/<arch>/<machine>.c`, SoC `hw/<arch>/<soc>.c`
- SoC/board revision and compatibility target: <revision>
- Machine properties (required/optional/default): <properties>

## CPU and reset

- CPU model(s) and count: <cpu-type>, <count>
- Reset vector, boot exception level, and privilege mode: <values>
- RAM base and size limits: <base>, <size>
- FDT pointer / boot ABI: <value>
- Reset-hook and loader-helper ownership: <machine or SoC>

## Memory map

| Region | Base | Size | Owner | Type | IRQ | Source |
| --- | --- | --- | --- | --- | --- | --- |
| <region-name> | <0xbase> | <0xsize> | <machine/soc/device> | <ram/rom/mmio/alias> | <irq-or-none> | <manual-page-or-dts> |

Explain each region that is not obvious, especially aliases and windows shared by several
devices.

## IRQ graph

| Controller | Context | Sources | Cascade | Source |
| --- | --- | --- | --- | --- |
| <controller> | <cpu-local/global> | <irq-numbers> | <parent-irq-if-any> | <manual-page-or-source> |

State MSI/PCI routing separately when it exists.

## Boot ABI and paths

- Direct kernel boot: entry point <entry>, loader helper <helper>, required flags <flags>
- Firmware boot: firmware entry <entry>, boot media <media>, required flags <flags>
- Allowed/forbidden command-line combinations: <rules>
- High-RAM or FDT adjustments: <rules>

## Unimplemented map summary

- Map file: `<task>/output/unimplemented-map.csv`
- Windows listed: <count>; measured guest-touched: <count>
- Measurement command and log: <command>, <log-path>
- Exclusions and rationale: <covered-by-other-model/firmware-only/secure-only>

## Acceptance checks

- qtest name(s) and bucket: <test-name>, <qtests_arch or qtests_generic>
- Functional or boot markers: <marker>
- Required evidence under `.oh-my-qemu/<task-slug>/`: <paths>
- Result classification: PASS, FAIL, or INCONCLUSIVE with what each proves

## qtest plan

- Test source: `tests/qtest/<board>-test.c`
- Registration: `tests/qtest/meson.build` under `<bucket>`
- Machine instantiation arguments: <minimal-args>
- Probes: RAM/ROM/MMIO bases, unimplemented windows, reset state, IRQ wiring
- Run command: `builds/build-<target>/pyvenv/bin/meson test -C builds/build-<target> qtest-<arch>/<test>`

## Open questions

- <unverified fact and the source that would resolve it>
