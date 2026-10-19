# Patch series

Use this reference only when the user explicitly requests commits, a patch series, or
cleanup of an existing series. It never authorizes sending anything upstream; the skill's
boundary and the declared provenance intent still govern.

## Open the series

- Record the user's request, the target tree, and the base revision in `audit.md`. If the
  tree is not a Git worktree, stop and confirm the intended base before creating commits.
- Record the provenance intent: `local-only`, `downstream/fork`, or `upstream-intent`. A
  local-only series may be committed locally when requested, but it must not become an
  upstream-ready submission by accident.
- List the atomic logical changes and their dependency order before creating the first
  commit.
- Confirm what the user asked to include: tests, documentation, and each subsystem split.
  Do not add patches the user did not request.

## Write each commit

- One atomic logical change per commit. Every commit should build on its own and leave the
  tree consistent.
- Subject: `subsystem: lowercase imperative`, normally at most 72 characters, with no
  trailing period, no version marker, and no chat-derived wording.
- Body: why the change is needed plus at most a one-line what. No implementation
  walkthrough, no review discussion, no reference to the conversation, and no claim that
  the checked-out tree or a cited document cannot verify.
- Credit tags only when they are real: do not invent `Reviewed-by`, `Acked-by`, or
  `Tested-by` lines.

## Split, merge, and order

- Split a fix from its test only when the user asks for separate patches; otherwise add
  the test to the commit that needs it.
- Fold follow-up fixes into the commit they repair instead of appending a fixup series,
  unless the user wants the review history preserved.
- Order by dependency: register definitions and shared helpers before their users;
  introduce a new file together with the build-system entry that references it.
- Keep placeholder-to-implementation transitions buildable. Add a placeholder in the
  commit that needs it and replace it in the later commit that implements the behavior.
- Keep `Kconfig`, `meson.build`, and `MAINTAINERS` updates in the commit that introduces
  the file, device, or machine.
- Order documentation as the user asks. For local-only and downstream series, appending a
  documentation patch last is the common local shape; for an upstream-intent series follow
  the checked-out `docs/devel/submitting-a-patch.rst`, which prefers documentation first
  for clean-room review.

## Verify every commit

- Build the narrow target from the source root with `ninja -C builds/build-<target>`, and
  record the target and result per commit.
- Run QEMU's `scripts/checkpatch.pl` on each patch or on the full series. Fix findings, or
  record why a finding is intentional.
- Check changed lines for 80 columns, and run `git diff --check` to catch whitespace
  errors.
- Run the proportional gate the user asked for, such as qtest or a boot marker, and record
  decisive output under `logs/`.
- Mechanical or comment-only commits may use a reduced gate; record the reason.

## Review the series

- Export with `git format-patch`, compare against the working tree with `git range-diff`,
  and byte-compare affected files when a patch is compared across trees.
- Re-read the complete series: subjects, order, buildability, and that no audit artifacts,
  logs, or task files are included.
- Verify `git status --short` after export, preserve unrelated dirty paths, and report the
  series shape and remaining gaps in `audit.md`.

## Certify and rebase

- Every commit needs `Signed-off-by: Name <email>` for each contributor, as described in
  the checked-out `docs/devel/submitting-a-patch.rst`. Use `git commit -s` only after the
  user has requested commits.
- When the same series lives in a Gerrit tree and in an upstream-prep tree, keep Gerrit
  metadata in the Gerrit tree only. Strip the `Change-Id:` line in the upstream-prep tree
  and verify with a byte comparison; do not sync it between trees.
- Use fixup commits plus `git rebase --autosquash` with `GIT_SEQUENCE_EDITOR=true` when
  the user asks for cleanup. Preserve the author and existing tags during the rebase.

## Stay inside the boundary

- Never push, send email, open a merge request, or prepare an upstream submission unless
  the user explicitly requests that separate action.
- If the user asked for local-only commits, say in the handoff that the branches and patch
  files are not upstream contributions.
- Record the request, base, per-commit verification, and remaining gaps in `audit.md`.
