# QEMU qtest patterns

Copy the shape, then verify every address, API name, and command against the
checked-out tree. Placeholders use `<...>`.

## Registration checklist

- Source in `tests/qtest/<name>.c`; include `qemu/osdep.h` then `libqtest.h`.
- Register in `tests/qtest/meson.build` under `qtests_<arch>`
  (`qtests_generic` only when truly architecture-independent); guard optional
  devices with `(config_all_devices.has_key('CONFIG_<DEV>') ? ['<name>'] : [])`.
- Entry point: `g_test_init()`, `qtest_add_func("/<group>/<case>", fn)`,
  `g_test_run()`.
- Syntax-check with a sibling's flags from
  `builds/build-<target>/compile_commands.json` and `-fsyntax-only` before the
  machine builds.

## Machine-test skeleton

```c
#include "qemu/osdep.h"
#include "libqtest.h"

#define DEV_BASE 0x10000000
#define DEV_CTRL 0x00

static void test_reset_value(void)
{
    QTestState *qts = qtest_init("-machine <machine>");

    g_assert_cmphex(qtest_readl(qts, DEV_BASE + DEV_CTRL), ==, 0);
    qtest_quit(qts);
}

int main(int argc, char **argv)
{
    g_test_init(&argc, &argv, NULL);
    qtest_add_func("/<name>/reset", test_reset_value);
    return g_test_run();
}
```

One `qtest_init()`/`qtest_quit()` pair per test; a failure must not leak state.

## IRQ level

Observe the line where it reaches the interrupt controller, not internal state:

```c
qtest_irq_intercept_out(qts, "/machine/<soc-path>");
qtest_writel(qts, DEV_BASE + DEV_IRQ_EN, 1);
qtest_writel(qts, DEV_BASE + DEV_IRQ_RAISE, 1);
g_assert_true(qtest_get_irq(qts, 0));
qtest_writel(qts, DEV_BASE + DEV_IRQ_CLEAR, 1);
g_assert_false(qtest_get_irq(qts, 0));
```

`qtest_set_irq_in()` drives input GPIO lines of the model.

## Virtual clock

Do not sleep; advance `QEMU_CLOCK_VIRTUAL` (`qtest_clock_step` takes ns,
`qtest_clock_step_next` jumps to the next deadline, `qtest_clock_set` sets
absolute virtual time):

```c
qtest_writel(qts, DEV_BASE + DEV_TMR_LOAD, 1000);
qtest_writel(qts, DEV_BASE + DEV_TMR_CTRL, 1);
qtest_clock_step(qts, 1001);
g_assert_cmphex(qtest_readl(qts, DEV_BASE + DEV_TMR_STATUS), ==, FIRED);
```

## QMP management path

Use QMP for management behavior instead of a private register poke; check the
schema in the checked-out `qapi/` first:

```c
qtest_qmp_assert_success(qts,
    "{ 'execute': 'block_resize', "
    " 'arguments': { 'device': 'drive0', 'size': %d } }", new_size);
```

Use `qtest_qmp_eventwait()` after an action that emits an event.

## PCI hotplug

The root bus has no hotplug slot; create a `pcie-root-port` and attach below
it (see `tests/qtest/device-plug-test.c`):

```c
qts = qtest_initf("-machine q35 "
                  "-device pcie-root-port,id=p1 "
                  "-device virtio-mouse-pci,bus=p1,id=dev0");
```

For unplug with no running guest: send `device_del`, call
`qtest_system_reset_nowait()`, wait for `DEVICE_DELETED`; skip with
`qtest_has_device()` when the device is not built.

## SMMUv3 multi-page DMA

Single-page transfers miss per-translation and reentrancy bugs. Map more than
one IOVA page to distinct GPAs, run one DMA crossing the pages, and assert each
destination page. Base: `tests/qtest/iommu-smmuv3-test.c` and
`tests/qtest/libqos/qos-smmuv3.h`; use the tree's `QSMMU_*` helpers.

## Sparse capacity boundary

Probe the device's addressable limit and the first rejected size with a sparse
image, then assert guest-visible capacity and the error path. A command
interface with a 32-bit sector/address field caps usable capacity by that
field. Verify the cap in the checked-out model before asserting a number and
record image format, size, and hashes.

## Ephemeral reproducers

Record path, command, and result in `commands.md`. Delete the reproducer and
its registration before handoff unless the user requested it as scope. Never
revert unrelated edits while cleaning up.

## Command buffers and stubs

For DMA/queue devices, write a command buffer or descriptor list into guest
memory, kick the channel, then assert status and destination memory:

- place descriptors with `qtest_memwrite()`/`qtest_writel()` at guest addresses;
- use `offsetof()` on the device descriptor struct when a header exposes it;
- step the virtual clock or poll a status register for completion;
- read destination memory with `qtest_memread()` and compare the payload;
- test an invalid command and the error/status path too.

A stub that only flips a status bit is smoke coverage, not command-buffer
behavior.

## macOS TMPDIR

libqtest sockets live under `$TMPDIR` (`qtest-<pid>.sock`). A long macOS
per-user TMPDIR can exceed the socket-path limit and abort tests; use a short
directory and one process:

```bash
TMPDIR=/tmp builds/build-<target>/pyvenv/bin/meson test \
  -C builds/build-<target> -j 1 qtest-<arch>/<test>
```

## A qtest can hide a wrong-address bug

- Derive every asserted address from the model register map, the device
  binding/DTS, or a register contract, and cite the source in a comment.
- Compare test addresses against driver-visible addresses before trusting a
  PASS.
- Mutate the asserted register or mask temporarily and confirm the test fails,
  then restore it.
- Record what the test does not cover next to the PASS line.
