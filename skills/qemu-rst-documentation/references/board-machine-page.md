# Board and machine page requirements

Use this reference with [the board page template](../assets/board-machine-page-template.rst)
before writing or reviewing a QEMU board or machine page. It states what a page must prove and
what must be checked before handoff.

## Source first

- Every supported device, memory window, IRQ, machine property, and boot option must trace to
  the checked-out implementation, a test, or the authoritative TRM/manual. Record the source in
  `audit.md`; do not document a behavior from a name or a boot banner.
- Document only behavior that is implemented and verified, or that is explicitly marked as a
  limitation or unimplemented window.
- Cross-check facts against `hw/`, `target/`, `tests/qtest/`, and `tests/functional/` before
  writing. A claim you cannot check is a limitation note or an unresolved gap.

## Length and order

- Follow the nearest sibling page in the same directory; match its section order and length.
  A short SoC board page is usually near 80-120 lines, not a chapter.
- Keep machine-specific prose focused: what the machine is, what it models, how to boot it, and
  what it does not model.
- No out-of-tree repository links, image recipe paths, private build-system details, or internal
  task/provenance chatter in the page. Use checked-out-tree paths and public manual citations.
- Omit sections that carry no useful information instead of adding placeholder prose.

## Required facts

- Exact machine type as used by `-M`, and the architecture directory it belongs to.
- Supported boot paths and the exact commands for each; state when the paths are exclusive.
- Console/UART choice and serial routing used by the boot commands.
- Memory layout: RAM base/size limits, ROM/flash windows, and any fixed load addresses.
- Unimplemented regions the guest may reach, and why the supported workload is safe.
- Machine properties: required and optional properties, defaults, and validation behavior.
- Test commands for the registered qtest and functional tests.
- Known limitations, including fidelity deviations and unmodeled hardware.

Commands must be copy-pasteable, use `<placeholder>` file names rather than local absolute
paths, and pass the same line-length and literal-block checks as prose.

## Toctree registration

- Add the page to the architecture `index.rst` or the nearest local toctree; a standalone file
  is not documented.
- Sort entries by title as the local index does; do not append the new entry at the end when the
  index is alphabetical.
- Keep the document name and the file name consistent with nearby pages.

## Style

- Use the heading hierarchy and adornment characters of nearby docs; title underline length must
  be at least the title length.
- Use double backticks for inline literals, literal blocks (`::`) for shell commands unless
  nearby docs prefer `.. code-block::`, and blank lines around directives.
- Keep prose near 80 columns and wrap long command examples with backslash continuations.
- Do not use Markdown fences, Markdown headings, or Markdown emphasis.

## Validation

- Parse with docutils or build with Sphinx; a docs build that reports HTML output is not
  required for every local page. Use the validation ladder in
  [docs-validation.md](docs-validation.md) and record the tool, version, and limitation.
- Run the skill's gate script against the page and the QEMU tree, resolving the script
  relative to the installed skill directory:
  `"$SKILL_DIR/scripts/rst-gates.sh" --repo-root <qemu-root> <page>.rst`.
  It checks underlines, toctree presence, out-of-tree repository links, local absolute paths,
  line length, literal blocks, and docutils parsing when available.
- Run `git diff --check` and inspect the rendered structure for heading hierarchy, toctree
  inclusion, literal-block indentation, and command wrapping.
- Fact cross-check: confirm each device, window, IRQ, boot command, and machine property against
  the implementation and tests. Record the sources and any cuts in `audit.md`.

## When trimming an existing page

Record in `audit.md` what was removed and why: out-of-tree links, internal recipe details,
undecided internals, duplicated background, or unverified claims. Remove a claim that cannot be
verified instead of explaining it.
