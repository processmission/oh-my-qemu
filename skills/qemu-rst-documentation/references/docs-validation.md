# QEMU documentation validation

Use this reference when a documentation change must be validated in a checked-out QEMU tree.
QEMU's Meson build configures documentation only when Sphinx is found and docs are enabled, so a
page can otherwise look fine while the docs build would fail.

## Validation ladder

Use the first available gate and record the command, tool version, and result in
`audit.md`/`commands.md`. Store generated output under the task's `output/` and logs under
`logs/`.

1. **Native docs target (preferred).** Configure a named build directory and run:

   ```bash
   mkdir -p builds/build-docs
   (cd builds/build-docs && ../../configure -Ddocs=enabled)
   ninja -C builds/build-docs sphinxdocs
   ```

   Run all three lines from the QEMU source root. The `sphinxdocs` alias target comes from
   `docs/meson.build` and exists only when Sphinx is available; if it is missing, inspect
   available targets with `ninja -C builds/build-docs -t targets` and install Sphinx into the
   build's Python environment before retrying.

2. **Direct Sphinx fallback.** When the native target cannot be configured, install `sphinx` and
   `sphinx_rtd_theme` into the build's Python environment and invoke the checked-out
   `docs/conf.py`. QEMU uses extensions under `docs/sphinx/`; if they cannot be loaded, record
   the failure as a validation gap instead of claiming a PASS. Write output to a throwaway
   directory under the task's `output/`.

3. **docutils syntax fallback (no Sphinx).** A syntax-only parse still catches the most common
   failures, especially title underlines:

   ```bash
   python3 -m venv .oh-my-qemu/<task-slug>/output/docutils-venv
   .oh-my-qemu/<task-slug>/output/docutils-venv/bin/pip install docutils
   .oh-my-qemu/<task-slug>/output/docutils-venv/bin/python - docs/system/arm/<page>.rst <<'PY'
   import pathlib, sys
   from docutils.core import publish_doctree

   path = pathlib.Path(sys.argv[1])
   publish_doctree(path.read_text(), source_path=str(path),
                   settings_overrides={"report_level": 2, "halt_level": 2})
   print("docutils parse OK:", path)
   PY
   ```

   Limitations to record: plain docutils does not know Sphinx directives such as `toctree`, does
   not resolve references, and cannot validate `.hx`/SRST files or index pages. Parse content
   pages only. If package installation is unavailable, record that and rely on
   `git diff --check` plus a manual RST review.

## Page gates script

The skill ships a portable gate script. Run it from the QEMU source root before handing off a
board or machine page:

```bash
SKILL_DIR=<path-to-this-skill>
"$SKILL_DIR/scripts/rst-gates.sh" --repo-root <qemu-root> <page>.rst
```

Resolve `SKILL_DIR` relative to the installed skill directory so the command also works when
the skill is installed alone.

It checks heading underlines, toctree membership under `docs/**/index.rst`, out-of-tree
repository links, local absolute paths, line length (`--max-line N`), literal-block indentation,
and a docutils parse when docutils is importable. It prints one PASS/FAIL line per check and exits
nonzero on failure; a docutils SKIP is a validation limitation to record. The script checks page
mechanics, not whether the documented facts are true.

## Board-page checklist

For a board or machine page, also apply [the page requirements](board-machine-page.md):

- every device, memory window, IRQ, machine property, and boot command has a source in
  `audit.md`;
- the machine type, console/UART, memory layout, unimplemented regions, and known limitations
  are stated;
- boot commands are copy-pasteable and use `<placeholder>` paths, not local absolute paths;
- the page is registered in the architecture toctree and sorted by title;
- the page follows a short sibling page's section order and length;
- the audit record lists what was cut and why, plus any unverified behavior left undocumented.

## Common RST pitfalls

- **Title underline too short.** The adornment line must be at least as long as the title; use
  the same character as nearby pages and keep the hierarchy consistent.
- **Adornment hierarchy.** Match the section levels used by sibling pages; do not introduce a new
  adornment character order in one page.
- **Literal blocks.** A `::` line must end the introducing paragraph; the block is indented and
  separated by a blank line. Use `.. code-block::` only when nearby docs do.
- **Toctree placement.** Add the page to the correct `index.rst` and sort entries by title as the
  local index does; a standalone page is not reachable.
- **Overlong command examples.** Wrap long QEMU command lines with backslash continuations and
  tests, and keep options copy-pasteable.
- **Inline literals.** Use double backticks; single backticks are interpreted as references and
  can fail the build.
- **Duplicate labels and unresolved references.** Verify labels, references, and substitutions
  resolve in the local build; remove them when they cannot be verified.
- **Markdown syntax.** Do not use Markdown fences, headings, or emphasis in `.rst` files.
- **`.hx` files.** Command-line and HMP documentation lives in `.hx` files; only `SRST` sections
  are reStructuredText and they are included into other documents.

## What to record in the audit

- docs files changed and toctree entries added or moved;
- validation path used (native Sphinx, direct Sphinx, or docutils) with command and version;
- result and the exact limitation of that validation path;
- source evidence for every support statement and command example;
- when trimming a page: what was removed and why;
- any behavior left undocumented because it is unverified.
