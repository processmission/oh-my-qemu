# Evidence mining for modeling requirements

Use this reference when a modeling task should start from prior agent evidence
instead of only a fresh prompt. It explains where the local evidence lives, how
to search it, how to turn findings into reusable requirements, and which limits
to record.

## Evidence sources

| Source | What it contains | Main limit |
| --- | --- | --- |
| Codex CLI/desktop rollouts (local rollout store) | long QEMU implementation sessions, commands, patches, reviews, compactions | cloud-side sessions may not be fully local; record the coverage gap |
| Claude Code project JSONL + prompt history | session transcripts, tool calls, file edits | transcript retention may be shorter than the prompt history |
| DeepSeek Harness sessions (compressed JSONL) | turns, tool calls, subagents, compaction summaries | compressed format needs a streaming parser |
| Legacy TUI session store | older long modeling loops | model-authored summaries; verify commit hashes independently |
| Remote workspace audit dirs and bridge logs | Humanize-style stage/round records, evidence manifests, first blockers | remote access is read-only and logs may be partial |
| Review comments (mail threads, patch review, local reviewer output) | requested changes, claim corrections | claims are hypotheses; verify against code/TRM |
| Chat desktop apps | usually server-side history | do not claim local recovery without a stored cache |

## Search strategy

1. **Scope by repo and date.** Filter by working directory, branch, date range,
   and QEMU repo names before keyword search.
2. **Two-stage keyword filter.** First find candidate files with broad terms
   (device name, board, subsystem, `qtest`, `RegisterInfo`, `trace`,
   `LOG_UNIMP`, `checkpatch`); then parse only the candidates.
3. **Extract the user signal.** Keep user prompts, corrections, reviewer
   requests, failure exits, and handoff summaries; do not dump raw transcripts
   into the skill reference.
4. **Cross-check with artifacts.** Confirm a session claim against the checked-out
   code, commit, audit record, or test; a model-authored summary is navigation,
   not proof.
5. **Record provenance.** For each finding keep the source class, date range,
   and a stable evidence pointer in the task audit; sanitize private data before
   writing reusable guidance.

## Review-comment extraction

- Parse review threads into "claim / requested change / affected file:line";
  drop quoted text, signatures, and diffs.
- Verify each claim against the checked-out code and QOM semantics; classify it
  as pre-existing or introduced by the change set.
- Reject debug-only surfaces (for example an unreachable `-global` override) as
  correctness evidence.
- Separate behavior requirements from patch hygiene (subject/body, split/order,
  checkstyle); the latter belong to the workflow patch-series reference.
- Keep unexplained numeric differences as explicit gaps, not as a summary line.

## Requirement abstraction

Turn repeated findings into a small, stable catalog:

- Use a prefix and number: `PM-###` for peripheral/register requirements,
  `BM-###` for board requirements, `RV-###` for review adjustments.
- Each row: requirement, anti-pattern it prevents, verification hint.
- Keep names, local paths, customer names, hostnames, and unreviewed quotes out.
- Update an existing row instead of adding a near-duplicate.
- Record the evidence class and date range in the task audit, not in the skill.
- Store domain lessons in the domain skill (`qemu-peripheral-modeling` or
  `qemu-board-modeling`); store mining procedure here.

## Coverage limits to record

- Desktop chat history is usually server-side; local caches may contain UI state
  only.
- Transcript cleanup may delete older sessions; prompt history may outlive the
  full transcript.
- Cloud/remote agent sessions may be only partially mirrored locally; state the
  gap instead of assuming coverage.
- Compaction summaries are model-generated: use them to navigate, not as quotes.
- Large corpora are sampled; report the sampled subset and the parsing method.

## Outputs

- A short evidence note in `.oh-my-qemu/<task-slug>/audit.md`: sources,
  date range, filters, counts, limits.
- Reusable requirement rows in the relevant domain skill reference.
- A sanitized summary; raw evidence stays in the original corpus or the task
  `logs/` directory.

## Boundaries

Evidence mining supports local research and verification. Do not copy private
session content, customer material, or unreviewed reviewer text into a tracked
skill reference, and do not use mining output to prepare upstream submissions.
