# Provenance

Use this reference when a claim depends on a source tree, configuration,
toolchain, container, firmware component, disk image, kernel, DTB, root
filesystem, or other produced artifact. Record provenance in `audit.md` and
command execution in `commands.md`.

## Capture relevant inputs

Record each source or input that can change the result:

| Component | Path or URL | Revision or version | Dirty state | Purpose |
| --- | --- | --- | --- | --- |

- Treat `git rev-parse HEAD` as a revision, not proof of a clean tree; record
  relevant dirty paths separately.
- Record configuration paths and decisive options rather than copying entire
  generated configurations.
- Record tool and compiler versions plus the resolved executable path when the
  environment could select more than one.
- For containers, record the image reference, digest when available, mounts,
  working directory, and effective command.
- Mark unavailable, inferred, or user-supplied facts explicitly. Do not fill a
  gap from a filename or assumption.

## Record production and consumption

For every artifact consumed by QEMU or used as decisive evidence, record:

| Artifact | Producer/source | Effective path | Size | SHA-256 | Verified by |
| --- | --- | --- | --- | --- | --- |

Record the command that produced it, the source and destination when copied,
and any mutation after creation. Hash final consumed artifacts, not only build
directories or intermediates. If hashing is unavailable or disproportionate,
state that as a gap and identify the weaker evidence used instead.

Keep third-party dependency outputs and non-QEMU build binaries under
`.oh-my-qemu/<task-slug>/output/`. Record QEMU build outputs from the source-root
`builds/build-<target>/` directory; do not copy them into `output/` merely for
bookkeeping.

## Keep commands reproducible

For each decisive command, put a row or short block in `commands.md` containing:

- purpose and working directory;
- command with credentials and private tokens redacted;
- relevant environment, configuration, and input paths;
- exit status and concise result;
- log path under `.oh-my-qemu/<task-slug>/logs/`, when output matters.

Do not copy secrets into audit artifacts. Redaction must preserve enough command
shape to explain the result. At handoff, distinguish verified provenance from
assumptions and unresolved gaps.

## Classify the provenance intent

Before writing source, record one declaration in `audit.md`:

- `upstream-intent`: the user states the work targets QEMU upstream. Do not prepare or
  send agent-generated code, documentation, commit messages, or patches for that
  submission; see the checked-out `docs/devel/code-provenance.rst`.
- `local-only`: experiments, analysis, debugging, or learning. Never let local-only work
  become an upstream-ready patch by accident: do not strip Gerrit metadata into a
  submission series, do not label branches or patches as ready for the mailing list, and
  do not change the intent without an explicit user declaration.
- `downstream/fork`: a vendor or fork tree with its own contribution policy. Record the
  target tree and policy; upstream guidance from this skill does not apply unchanged.

If the user has not declared intent, state the default (`local-only`) and ask only when
the next action would cross into upstream submission. Changing the tree or audience
reopens the gate; record the new declaration and date.

## Record a non-Git source snapshot

When the source tree is not a Git worktree, record `provenance: non-Git snapshot`, the
archive path, the extraction root, and SHA-256 values for the archive and for the touched
sources and configuration. Never add a `.git` directory to a vendor tree and never report
a snapshot as clean. Treat any rebuild or re-extraction as a new input that needs its own
hash.

## Hash consumed inputs

Hash each input before consuming it: kernel `Image`, DTB, initrd or root filesystem,
firmware blobs, and disk images. Record the hash beside the input path and re-hash after
any regeneration; a changed hash invalidates evidence produced with the earlier input. If
hashing is disproportionate, state that gap and the weaker evidence used instead.

## Optional skill and evidence manifests

Bridge loops and multi-round runs can record machine-readable manifests under `output/`.
Keep them optional and link them from `audit.md`. Generate the hash record with
`gates.sh evidence-manifest` and see
[evidence-manifest-template.md](../assets/evidence-manifest-template.md) for the TSV and
JSON shapes:

- `skill-manifest.json`: one entry per skill used, with `name`, `path`, `sha256`, and
  `complete`, plus a top-level `complete` flag and a `missing` list. A missing required
  skill is a gap, never a reason to improvise its rules.
- `evidence-manifest.json`: one entry per evidence artifact, with `path`, `sha256`,
  `status` for JSON reports, and `first_blocker`. `first_blocker` is the first failing
  gate in the projected order, not a summary of all failures.

## Record retention for generated artifacts

Record the task directory size, the largest members, and whether `output/` may be deleted
after handoff. State which artifacts must be preserved to reproduce the claims and which
are disposable. Do not copy QEMU build outputs into `output/`; reference their source-root
`builds/build-<target>/` paths and record their hashes when a claim depends on them.
