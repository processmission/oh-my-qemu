import { existsSync, mkdirSync, writeFileSync } from "node:fs";
import { basename, join, relative, resolve } from "node:path";

const ROOT_FILES = {
  "plan.md": true,
  "evidence.md": true,
  "commands.md": true,
  "register-extraction.md": true,
  "source-inventory.md": true,
  "conflicts.md": true,
  "debugger.md": true,
  "final-summary.md": true,
};

const ROOT_DIRS = {
  logs: true,
  reviews: true,
  scratch: true,
};

function slugify(input) {
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

function taskRoot(cwd, slug) {
  return join(cwd, "build", "agent", slug);
}

function initQemuTask(cwd, rawName) {
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

function isInsideBuildAgent(cwd, rawPath) {
  const absolute = resolve(cwd, rawPath);
  const rel = relative(join(cwd, "build", "agent"), absolute);
  return rel !== "" && !rel.startsWith("..") && !rel.startsWith("/");
}

function artifactPolicyViolation(cwd, rawPath) {
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

function commandPolicyViolation(command) {
  if (/(^|[\s'"`])(\.plan|\.humanize)(\/|\s|$)/.test(command)) {
    return "QEMU agent artifacts must stay under build/agent/<task-slug>/, not .plan/ or .humanize/.";
  }
  return null;
}

function resultText(result) {
  return [
    `QEMU task workspace: ${result.root}`,
    `Slug: ${result.slug}`,
    `Created: ${result.created.length}`,
    `Kept: ${result.kept.length}`,
  ].join("\n");
}

export default function ohMyQemu(pi) {
  const z = pi.zod.z ?? pi.zod;

  pi.setLabel("Oh My QEMU");

  pi.registerTool({
    name: "qemu_init_task",
    label: "QEMU Init Task",
    description: "Create build/agent/<task-slug>/ plan, evidence, command, register extraction, log, review, scratch, and RLCR files for a QEMU task.",
    parameters: z.object({
      name: z.string().describe("Task name or slug. It will be normalized for build/agent/<task-slug>/.").optional(),
    }),
    async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
      const result = initQemuTask(ctx.cwd, params.name ?? basename(ctx.cwd));
      return {
        content: [{ type: "text", text: resultText(result) }],
        details: result,
      };
    },
  });

  pi.registerCommand("qemu-init-task", {
    description: "Create build/agent/<task-slug>/ QEMU task artifacts",
    handler: async (args, ctx) => {
      const result = initQemuTask(ctx.cwd, args.trim() || basename(ctx.cwd));
      ctx.ui.notify(resultText(result), "info");
    },
  });

  pi.on("tool_call", async (event, ctx) => {
    const input = event.input;

    if (event.toolName === "write") {
      const path = typeof input?.path === "string" ? input.path : "";
      const reason = artifactPolicyViolation(ctx.cwd, path);
      if (reason) {
        return { block: true, reason };
      }
    }

    if (event.toolName === "bash") {
      const command = typeof input?.command === "string" ? input.command : "";
      const reason = commandPolicyViolation(command);
      if (reason) {
        return { block: true, reason };
      }
    }
  });
}
