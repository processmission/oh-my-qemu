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
