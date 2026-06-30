import { spawnSync } from "node:child_process";
import { appendFileSync, existsSync, mkdirSync, readFileSync, statSync, writeFileSync } from "node:fs";
import { basename, join, relative, resolve } from "node:path";

// Shared, runtime-agnostic logic for the Oh My QEMU plugin.
//
// Both the Oh My Pi extension (src/extension.js) and the Claude Code
// scripts (scripts/init-task.mjs, scripts/artifact-policy.mjs) import from
// here so the task workspace layout and artifact policy stay identical
// across runtimes.

export const ROOT_FILES = {
  "plan.md": true,
  "evidence.md": true,
  "commands.md": true,
  "register-extraction.md": true,
  "source-provenance.md": true,
  "image-layout.md": true,
  "boot-run.md": true,
  "methodology-feedback.md": true,
  "source-inventory.md": true,
  "conflicts.md": true,
  "debugger.md": true,
  "final-summary.md": true,
};

export const ROOT_DIRS = {
  logs: true,
  reviews: true,
  scratch: true,
};

export const QEMU_SOURCE_ROOT_FILES = [
  "configure",
  "meson.build",
  "VERSION",
  "docs/devel/code-provenance.rst",
];

export const TASK_ROOT_DIR = ".oh-my-qemu";

export function slugify(input) {
  const slug = input
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9._-]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 80);

  return slug || "qemu-task";
}

function ensureDir(path, result) {
  if (existsSync(path)) {
    result.kept.push(path);
    return;
  }
  mkdirSync(path, { recursive: true });
  result.created.push(path);
}

function writeIfMissing(path, content, result) {
  if (existsSync(path)) {
    result.kept.push(path);
    return;
  }
  writeFileSync(path, content, "utf8");
  result.created.push(path);
}

export function taskRoot(cwd, slug) {
  return join(cwd, TASK_ROOT_DIR, slug);
}

export function initQemuTask(cwd, rawName) {
  assertQemuSourceRoot(cwd);
  ensureLocalGitExclude(cwd);

  const slug = slugify(rawName);
  const root = taskRoot(cwd, slug);
  const result = { slug, root, created: [], kept: [] };

  ensureDir(root, result);
  ensureDir(join(root, "logs"), result);
  ensureDir(join(root, "reviews"), result);
  ensureDir(join(root, "scratch"), result);
  ensureDir(join(root, "rlcr"), result);

  writeIfMissing(join(root, "plan.md"), `# ${slug} Plan

## Goal

## Policy

- QEMU upstream provenance policy applies.
- Agent-created artifacts stay under .oh-my-qemu/${slug}/.
- Round checkpoint commits carry no DCO/review trailers added by the agent.
- Final-series drafts, if requested, are human-owned and not upstream-ready until a human rewrites and certifies them.
- \`AI-used-for:\` is a proposed qemu-devel scope-disclosure trailer, not DCO; draft it only when a human-recorded policy or maintainer exception applies.

## Scope

### In scope

### Out of scope

### Allowed source changes

### Artifact root

\`.oh-my-qemu/${slug}/\`

## Acceptance Criteria

- AC-1:
  - Evidence:

## Verification Gates

## Evidence Ledger

## Open Questions

## Decision Log
`, result);

  writeIfMissing(join(root, "evidence.md"), `# ${slug} Evidence

## Sources Read

## Commands Run

## Logs and Artifacts

## Assumptions
`, result);

  writeIfMissing(join(root, "commands.md"), `# ${slug} Commands

Record exact commands, working directories, environment overrides, and output artifact paths here.
`, result);

  writeIfMissing(join(root, "source-provenance.md"), `# ${slug} Source Provenance

## Source Roots

| Component | Path/URL | Revision | Dirty state | Purpose |
| --- | --- | --- | --- | --- |

## Task Source Baseline

| Tree | Branch | Baseline revision | Initial dirty paths | Commit pathspecs |
| --- | --- | --- | --- | --- |

## RLCR Round Checkpoints

| Round | Parent | Commit | Tree | Subject | Staged paths | Verification/review | Residual dirty state |
| --- | --- | --- | --- | --- | --- | --- | --- |

## Final Series Preparation

| Patch | Source round commits | Subject | Message draft | Required evidence | Sign-offs | AI-used-for |
| --- | --- | --- | --- | --- | --- | --- |

## Configurations

| Component | Config path/name | Key options | Notes |
| --- | --- | --- | --- |

## Toolchains and Runtime

| Tool | Version | Path | Notes |
| --- | --- | --- | --- |

## Build Commands

## Output Artifacts

| Artifact | Producer | Path | Size | SHA256 | Verified by |
| --- | --- | --- | --- | --- | --- |

## Assumptions and Gaps
`, result);

  writeIfMissing(join(root, "image-layout.md"), `# ${slug} Image Layout

## Image Summary

| Image | Format | Virtual size | Actual size | SHA256 | Mutable? |
| --- | --- | --- | --- | --- | --- |

## Partition or Region Map

| Region | Start | Size | Type | Filesystem | Purpose | Source |
| --- | --- | --- | --- | --- | --- | --- |

## Write Operations

| Order | Input | Output image | Offset/seek | Block size | Size | Command | Verified by |
| --- | --- | --- | --- | --- | --- | --- | --- |

## Boot-Relevant Files

## Mutation Policy

## Verification Notes
`, result);

  writeIfMissing(join(root, "boot-run.md"), `# ${slug} Boot Run

## Command

## Inputs

| Input | Path | SHA256 | Provenance |
| --- | --- | --- | --- |

## Console and Logs

## Timeout and Markers

## Result

## Debug Handoff
`, result);

  writeIfMissing(join(root, "methodology-feedback.md"), `# ${slug} Methodology Feedback

## Status

- State: not-analyzed
- Exit reason:
- User asked for issue: no
- Issue filed: no

## Sanitized Workflow Context

- Workflow type:
- Exit condition:
- Phases involved:

## Observed Patterns

## Improvement Suggestions

## Issue Draft

### Title

### Body

## Privacy Check

- [ ] No private paths, repository paths, or local usernames.
- [ ] No branch names, commit hashes, or git identifiers.
- [ ] No proprietary logs, raw error messages, or stack traces.
- [ ] No code snippets or code fragments.
- [ ] No project-specific URLs, image paths, or endpoints.
- [ ] No customer, product, board, or SoC identifiers unless explicitly approved.
`, result);

  writeIfMissing(join(root, "register-extraction.md"), `# ${slug} Register Extraction

## Target

## Source Inventory Summary

## Variants and Compatibility

## Memory Map

## Interrupts, Clocks, Resets, and DMA

## Register Summary Table

| Name | Offset | Width | Reset | Access | Side Effects | Confidence | Sources |
| --- | --- | --- | --- | --- | --- | --- | --- |

## Field Tables

## Driver Sequences

## IRQ and Status Flow

## DMA, FIFO, Timer, or Command Behavior

## Cross-Register Dependencies

| Feature/Flow | Registers and Fields | Required Sequence | Coupling Semantics | Failure/Partial State | Confidence | Sources | qtest Candidate |
| --- | --- | --- | --- | --- | --- | --- | --- |

## Feature Flow Details

## QEMU RegisterInfo Mapping Notes

| Register | RegisterAccessInfo facts | Hook needed | Dependent registers/fields | qtest coverage |
| --- | --- | --- | --- | --- |

## qtest Candidates

## Unknowns and Conflicts

## Handoff Checklist for qemu-peripheral-modeling
`, result);

  writeIfMissing(join(root, "source-inventory.md"), `# ${slug} Source Inventory

| Source | Version/Revision | Path/URL | Relevant Sections | Notes |
| --- | --- | --- | --- | --- |
`, result);

  writeIfMissing(join(root, "conflicts.md"), `# ${slug} Conflicts

| Fact | Source A | Source B | Difference | Resolution/Test |
| --- | --- | --- | --- | --- |
`, result);

  return result;
}

function isRegularFile(path) {
  try {
    return statSync(path).isFile();
  } catch {
    return false;
  }
}

function gitLine(cwd, args) {
  const result = spawnSync("git", ["-C", cwd, ...args], {
    encoding: "utf8",
    timeout: 2000,
  });
  if (result.error) {
    return { ok: false, stdout: "", error: result.error.message };
  }
  const stdout = (result.stdout ?? "").trim().split(/\r?\n/)[0] ?? "";
  const stderr = (result.stderr ?? "").trim().split(/\r?\n/)[0] ?? "";
  return { ok: result.status === 0, stdout, error: stderr || `exit ${result.status}` };
}

export function ensureLocalGitExclude(cwd) {
  const gitInside = gitLine(cwd, ["rev-parse", "--is-inside-work-tree"]);
  if (!gitInside.ok || gitInside.stdout !== "true") {
    return false;
  }

  const exclude = gitLine(cwd, ["rev-parse", "--git-path", "info/exclude"]);
  if (!exclude.ok || !exclude.stdout) {
    return false;
  }

  const excludePath = resolve(cwd, exclude.stdout);
  let existing = "";
  try {
    existing = readFileSync(excludePath, "utf8");
  } catch {
    existing = "";
  }

  if (/^\.oh-my-qemu\/$/m.test(existing)) {
    return false;
  }

  const prefix = existing.length > 0 && !existing.endsWith("\n") ? "\n" : "";
  appendFileSync(excludePath, `${prefix}.oh-my-qemu/\n`, "utf8");
  return true;
}

export function qemuSourceRootViolation(cwd) {
  const missing = QEMU_SOURCE_ROOT_FILES.filter((path) => !isRegularFile(join(cwd, path)));
  if (missing.length > 0) {
    return `Oh My QEMU must be started from a QEMU source root. Missing required files under ${cwd}: ${missing.join(", ")}.`;
  }

  const gitInside = gitLine(cwd, ["rev-parse", "--is-inside-work-tree"]);
  if (gitInside.ok && gitInside.stdout === "true") {
    const gitRoot = gitLine(cwd, ["rev-parse", "--show-toplevel"]);
    if (!gitRoot.ok || !gitRoot.stdout) {
      return `Oh My QEMU could not determine the Git worktree root for ${cwd}: ${gitRoot.error}.`;
    }

    const expected = resolve(cwd);
    const actual = resolve(gitRoot.stdout);
    if (actual !== expected) {
      return `Oh My QEMU must be started from the QEMU Git worktree root. CWD is ${expected}, but Git root is ${actual}.`;
    }
  }

  return null;
}

export function assertQemuSourceRoot(cwd) {
  const reason = qemuSourceRootViolation(cwd);
  if (reason) {
    throw new Error(reason);
  }
}

export function isInsideTaskArtifacts(cwd, rawPath) {
  const absolute = resolve(cwd, rawPath);
  // cwd-independent: an artifact is inside the task root when its absolute
  // path sits under a .../.oh-my-qemu/<slug>/... tree. Matching the path
  // segment anywhere is robust when a hook runs from a task subdirectory or
  // a pinned agent cwd.
  return /[\\/]\.oh-my-qemu[\\/][^\\/]+[\\/]/.test(absolute);
}

export function artifactPolicyViolation(cwd, rawPath) {
  if (!rawPath || isInsideTaskArtifacts(cwd, rawPath)) {
    return null;
  }

  const absolute = resolve(cwd, rawPath);
  const rel = relative(cwd, absolute);
  if (rel.startsWith("..") || rel.startsWith("/")) {
    return null;
  }

  const parts = rel.split(/[\\/]+/).filter(Boolean);
  if (parts.length === 0) {
    return null;
  }

  if (parts[0] === TASK_ROOT_DIR) {
    return `QEMU agent artifacts must be written under .oh-my-qemu/<task-slug>/, not ${rel}.`;
  }

  if (parts.includes(".plan") || parts.includes(".humanize")) {
    return `QEMU agent artifacts must be written under .oh-my-qemu/<task-slug>/, not ${rel}.`;
  }

  if (parts.length === 1 && ROOT_FILES[parts[0]]) {
    return `Root-level ${parts[0]} would pollute the QEMU source tree. Use .oh-my-qemu/<task-slug>/${parts[0]}.`;
  }

  if (parts.length === 1 && ROOT_DIRS[parts[0]]) {
    return `Root-level ${parts[0]}/ would pollute the QEMU source tree. Use .oh-my-qemu/<task-slug>/${parts[0]}/.`;
  }

  return null;
}

export function commandPolicyViolation(command) {
  if (/(^|[\s'"`])(\.plan|\.humanize)(\/|\s|$)/.test(command)) {
    return "QEMU agent artifacts must stay under .oh-my-qemu/<task-slug>/, not .plan/ or .humanize/.";
  }
  return null;
}

export function resultText(result) {
  return [
    `QEMU task workspace: ${result.root}`,
    `Slug: ${result.slug}`,
    `Created: ${result.created.length}`,
    `Kept: ${result.kept.length}`,
  ].join("\n");
}

export function defaultTaskName(cwd) {
  return basename(cwd);
}
