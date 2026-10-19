.. Copy this file to docs/system/<arch>/<board>.rst and replace every
   <placeholder>. Keep only sections that carry useful information.

<Board or Machine Name>
=======================

.. State the QEMU machine type here so it matches the command line, for example
   `-M <machine-type>`.

Overview
--------

<One paragraph: the board, the SoC, the QEMU machine type, and the reference
SDK or hardware manual used as the source of truth. Do not link out-of-tree
repositories or local recipe paths.>

Supported devices
-----------------

<List the modeled devices and their QEMU device models. Note devices that are
deliberately stubbed or unimplemented.>

* <Device name>: <QEMU device model and connection>
* <Device name>: <QEMU device model and connection>

Boot options
------------

<State which boot paths the machine supports and whether they are exclusive.
Reference the boot ABI and the required artifacts.>

Direct Linux boot
~~~~~~~~~~~~~~~~~

<Describe the direct-boot contract, then give a copy-pasteable command with
placeholder file names.>

::

   qemu-system-<arch> -M <machine-type> -m <size> \
       -kernel <path/to/Image> -dtb <path/to/board.dtb> \
       -append "console=<console>,115200" -nographic

Firmware boot
~~~~~~~~~~~~~

<Describe the firmware/bootloader chain and the required artifacts, then give a
copy-pasteable command.>

::

   qemu-system-<arch> -M <machine-type> -m <size> \
       -bios <path/to/firmware.bin> -nographic

Machine properties
------------------

<Required and optional machine properties, defaults, and validation rules.>

Memory map
----------

<Optional section: guest-visible windows. Every base and size needs a cited
source in the audit record.>

.. list-table:: Guest-visible windows
   :header-rows: 1

   * - Window
     - Base
     - Size
     - Source
   * - <name>
     - <base>
     - <size>
     - <manual section or source file>

Interrupts
----------

<Optional section: interrupt controller, number of lines, and routing summary.>

Known limitations
-----------------

* <Unimplemented window or unsupported behavior and how the workload avoids it>
* <Known deviation from the hardware manual>

Running tests
-------------

<Name the registered tests and give copy-pasteable commands run from the QEMU
source root.>

::

   builds/build-<target>/pyvenv/bin/meson test \
       -C builds/build-<target> qtest-<arch>/<test-name>

References
----------

<Optional section: checked-out-tree documentation or public hardware manual
citations used to verify the facts above.>
