import { existsSync, mkdirSync, writeFileSync } from "node:fs";
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
  return join(cwd, "build", "agent", slug);
}

export function initQemuTask(cwd, rawName) {
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
- Agent-created artifacts stay under build/agent/${slug}/.
- No DCO or review trailers are added by the agent.

## Scope

### In scope

### Out of scope

### Allowed source changes

### Artifact root

\`build/agent/${slug}/\`

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

export function isInsideBuildAgent(cwd, rawPath) {
  const absolute = resolve(cwd, rawPath);
  // cwd-independent: an artifact is "inside build/agent" when its absolute path
  // sits anywhere under a .../build/agent/<slug>/... tree. The previous
  // cwd-only check (relative(join(cwd,"build","agent"), absolute)) mis-fired
  // when the hook ran with a cwd other than the repo root (e.g. a task
  // subdirectory or a pinned agent cwd): a valid build/agent/<slug>/plan.md
  // then resolved to a ".." relative path and fell through to the root-level
  // plan.md block. Matching the path segment anywhere is robust to that.
  return /[\\/]build[\\/]agent[\\/][^\\/]+[\\/]/.test(absolute);
}

export function artifactPolicyViolation(cwd, rawPath) {
  if (!rawPath || isInsideBuildAgent(cwd, rawPath)) {
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

  if (parts.includes(".plan") || parts.includes(".humanize")) {
    return `QEMU agent artifacts must be written under build/agent/<task-slug>/, not ${rel}.`;
  }

  if (parts.length === 1 && ROOT_FILES[parts[0]]) {
    return `Root-level ${parts[0]} would pollute the QEMU source tree. Use build/agent/<task-slug>/${parts[0]}.`;
  }

  if (parts.length === 1 && ROOT_DIRS[parts[0]]) {
    return `Root-level ${parts[0]}/ would pollute the QEMU source tree. Use build/agent/<task-slug>/${parts[0]}/.`;
  }

  return null;
}

export function commandPolicyViolation(command) {
  if (/(^|[\s'"`])(\.plan|\.humanize)(\/|\s|$)/.test(command)) {
    return "QEMU agent artifacts must stay under build/agent/<task-slug>/, not .plan/ or .humanize/.";
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
