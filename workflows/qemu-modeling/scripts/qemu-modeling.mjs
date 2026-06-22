#!/usr/bin/env node

import { spawnSync } from "node:child_process";
import { existsSync } from "node:fs";
import { appendFile, mkdir, readFile, writeFile } from "node:fs/promises";
import { basename, isAbsolute, join, resolve } from "node:path";

const ROOT_FILES = [
  "plan.md",
  "evidence.md",
  "commands.md",
  "source-provenance.md",
  "image-layout.md",
  "boot-run.md",
  "methodology-feedback.md",
  "register-extraction.md",
  "source-inventory.md",
  "conflicts.md",
  "workflow-handoff.md",
];

const ROOT_DIRS = ["logs", "reviews", "scratch", "rlcr"];

const WORKSTREAM_CHAINS = {
  "register-extraction": ["qemu-flow-plan", "qemu-source-provenance", "qemu-register-extraction"],
  "peripheral-modeling": [
    "qemu-flow-plan",
    "qemu-source-provenance",
    "qemu-register-extraction",
    "qemu-peripheral-modeling",
    "qemu-qtest",
    "qemu-model-verification",
    "qemu-rlcr-loop",
  ],
  "board-modeling": [
    "qemu-flow-plan",
    "qemu-source-provenance",
    "qemu-register-extraction",
    "qemu-board-modeling",
    "qemu-qtest",
    "qemu-direct-linux-boot",
    "qemu-model-verification",
    "qemu-rst-documentation",
    "qemu-rlcr-loop",
  ],
  build: ["qemu-flow-plan", "qemu-source-provenance", "qemu-build"],
  "kernel-build": ["qemu-flow-plan", "qemu-source-provenance", "qemu-kernel-build"],
  "uboot-build": ["qemu-flow-plan", "qemu-source-provenance", "qemu-uboot-build"],
  "image-packaging": ["qemu-flow-plan", "qemu-source-provenance", "qemu-image-layout", "qemu-image-packaging"],
  "direct-linux-boot": [
    "qemu-flow-plan",
    "qemu-source-provenance",
    "qemu-image-layout",
    "qemu-boot-run",
    "qemu-direct-linux-boot",
    "qemu-model-verification",
  ],
  "firmware-linux-boot": [
    "qemu-flow-plan",
    "qemu-source-provenance",
    "qemu-image-layout",
    "qemu-boot-run",
    "qemu-firmware-linux-boot",
    "qemu-debug",
    "qemu-model-verification",
  ],
  debug: ["qemu-flow-plan", "qemu-boot-run", "qemu-debug", "qemu-model-verification"],
  qtest: ["qemu-flow-plan", "qemu-qtest", "qemu-model-verification"],
  documentation: ["qemu-flow-plan", "qemu-rst-documentation"],
  "tcg-frontend": ["qemu-flow-plan", "qemu-tcg-frontend-instruction", "qemu-build", "qemu-rlcr-loop"],
  "tcg-backend": ["qemu-flow-plan", "qemu-tcg-backend-adaptation", "qemu-build", "qemu-rlcr-loop"],
  general: ["qemu-flow-plan", "qemu-source-provenance", "qemu-model-verification", "qemu-rlcr-loop"],
};

const mode = process.argv[2] ?? "bootstrap";
const cwd = process.cwd();
const context = parseWorkflowContext();
const taskSpec = await readTaskSpec();
const rawTaskName =
  process.env.QEMU_TASK ?? process.env.QEMU_TASK_SLUG ?? context.state?.slug ?? taskSpec.slug ?? taskSpec.title ?? basename(cwd);
const slug = slugify(String(rawTaskName));
const taskRoot = join(cwd, "build", "agent", slug);
const taskBrief = await resolveTaskBrief(context.state?.taskBrief, taskSpec);
const workstream = normalizeWorkstream(
  process.env.QEMU_WORKSTREAM ?? context.state?.workstream ?? taskSpec.workstream ?? inferWorkstream(taskBrief),
);

if (mode === "bootstrap") {
  await bootstrapWorkspace();
} else if (mode === "provenance") {
  await recordProvenance();
} else if (mode === "handoff") {
  await writeHandoff();
} else if (mode === "record-round") {
  await recordRound();
} else if (mode === "finalize") {
  await finalizeEvidence();
} else {
  throw new Error(`unknown qemu-modeling mode: ${mode}`);
}

async function bootstrapWorkspace() {
  const provenance = captureProvenance();
  const result = { created: [], kept: [] };
  await ensureDir(taskRoot, result);
  for (const dir of ROOT_DIRS) await ensureDir(join(taskRoot, dir), result);

  await writeIfMissing(join(taskRoot, "plan.md"), planTemplate(), result);
  await writeIfMissing(join(taskRoot, "evidence.md"), evidenceTemplate(), result);
  await writeIfMissing(join(taskRoot, "commands.md"), commandsTemplate(), result);
  await writeIfMissing(join(taskRoot, "source-provenance.md"), sourceProvenanceTemplate(), result);
  await writeIfMissing(join(taskRoot, "image-layout.md"), imageLayoutTemplate(), result);
  await writeIfMissing(join(taskRoot, "boot-run.md"), bootRunTemplate(), result);
  await writeIfMissing(join(taskRoot, "methodology-feedback.md"), methodologyFeedbackTemplate(), result);
  await writeIfMissing(join(taskRoot, "register-extraction.md"), registerExtractionTemplate(), result);
  await writeIfMissing(join(taskRoot, "source-inventory.md"), sourceInventoryTemplate(), result);
  await writeIfMissing(join(taskRoot, "conflicts.md"), conflictsTemplate(), result);
  await writeIfMissing(join(taskRoot, "workflow-handoff.md"), workflowHandoffStub(), result);
  await writeIfMissing(join(taskRoot, "rlcr", "goal-tracker.md"), goalTrackerTemplate(), result);

  emit({
    summary: `initialized QEMU modeling workspace ${relativeTaskRoot()}`,
    data: { slug, taskRoot, workstream, taskFile: taskSpec.path, created: result.created.length, kept: result.kept.length },
    statePatch: [
      { op: "set", path: "/slug", value: slug },
      { op: "set", path: "/taskRoot", value: taskRoot },
      { op: "set", path: "/taskBrief", value: taskBrief },
      { op: "set", path: "/workstream", value: workstream },
      {
        op: "set",
        path: "/workspace",
        value: {
          root: taskRoot,
          created: result.created.length,
          kept: result.kept.length,
          taskFile: taskSpec.path,
          files: ROOT_FILES,
          dirs: ROOT_DIRS,
        },
      },
      { op: "set", path: "/provenance", value: provenance },
      { op: "set", path: "/plan", value: stageState("pending", "planWork has not run") },
      { op: "set", path: "/research", value: stageState("pending", "researchContract has not run") },
      { op: "set", path: "/implementation", value: stageState("pending", "implementationRound has not run") },
      { op: "set", path: "/verification", value: stageState("pending", "verificationRound has not run") },
      { op: "set", path: "/fixes", value: { status: "pending", round: 0, summary: "No fix round has run yet." } },
      { op: "set", path: "/modeling", value: { status: "bootstrapped", round: 0, attempt: 0, summaries: {}, artifacts: [] } },
      { op: "set", path: "/commit", value: { status: "pending", round: 0, commit: "none" } },
      { op: "set", path: "/final", value: { status: "pending" } },
    ],
  });
}

async function recordProvenance() {
  const prior = context.state?.provenance;
  const snapshot =
    prior && prior.gitInsideWorkTree !== "unavailable" ? prior : captureProvenance();

  await appendSectionOnce(
    join(taskRoot, "evidence.md"),
    "<!-- qemu-modeling provenance -->",
    `\n## Workflow Bootstrap Snapshot\n\n<!-- qemu-modeling provenance -->\n\n- CWD: ${cwd}\n- Git root: ${snapshot.gitRoot}\n- Git branch: ${snapshot.gitBranch}\n- Git HEAD: ${snapshot.gitHead}\n- Initial dirty state: ${snapshot.gitDirtyState}\n- qemu-system: ${snapshot.qemuSystem}\n- qemu-img: ${snapshot.qemuImg}\n\n\`\`\`text\n${snapshot.gitStatus || "(clean)"}\n\`\`\`\n`,
  );
  await appendSectionOnce(
    join(taskRoot, "source-provenance.md"),
    "<!-- qemu-modeling source-provenance -->",
    `\n## Task Source Baseline\n\n<!-- qemu-modeling source-provenance -->\n\n| Tree | Branch | Baseline revision | Initial dirty paths | Commit pathspecs |\n| --- | --- | --- | --- | --- |\n| ${markdownCell(snapshot.gitRoot)} | ${markdownCell(snapshot.gitBranch)} | ${markdownCell(snapshot.gitHead)} | ${snapshot.gitDirtyState === "dirty" ? "see status below" : snapshot.gitDirtyState} | pending plan |\n\n### Initial Git Status\n\n\`\`\`text\n${snapshot.gitStatus || "(clean)"}\n\`\`\`\n\n## Detected Tools\n\n| Tool | Path | Notes |\n| --- | --- | --- |\n| qemu-system | ${snapshot.qemuSystem} | first aarch64/x86_64 executable on PATH, if any |\n| qemu-img | ${snapshot.qemuImg} | executable on PATH, if any |\n`,
  );

  emit({
    summary: "recorded QEMU modeling provenance snapshot",
    data: snapshot,
    statePatch: [{ op: "set", path: "/provenance", value: snapshot }],
  });
}

function captureProvenance() {
  const gitRoot = commandLine("git", ["rev-parse", "--show-toplevel"]);
  const gitHead = commandLine("git", ["rev-parse", "HEAD"]);
  const gitBranch = commandLine("git", ["branch", "--show-current"]);
  const gitStatus = commandOutput("git", ["status", "--short"]);
  const gitInside = commandLine("git", ["rev-parse", "--is-inside-work-tree"]);
  const qemuSystem = commandLine("sh", ["-c", "command -v qemu-system-aarch64 || command -v qemu-system-x86_64 || true"]);
  const qemuImg = commandLine("sh", ["-c", "command -v qemu-img || true"]);
  return {
    cwd,
    gitRoot: gitRoot.ok ? gitRoot.stdout : "unavailable",
    gitHead: gitHead.ok ? gitHead.stdout : "unavailable",
    gitBranch: gitBranch.ok ? gitBranch.stdout || "detached" : "unavailable",
    gitStatus: gitStatus.ok ? gitStatus.stdout : `unavailable: ${gitStatus.error}`,
    gitDirtyPaths: gitStatus.ok ? gitStatus.stdout.split(/\r?\n/).filter(Boolean) : [],
    gitDirtyState: gitStatus.ok ? (gitStatus.stdout ? "dirty" : "clean") : "unavailable",
    gitInsideWorkTree: gitInside.ok ? gitInside.stdout : "unavailable",
    qemuSystem: qemuSystem.stdout || "unavailable",
    qemuImg: qemuImg.stdout || "unavailable",
  };
}

async function writeHandoff() {
  const skills = WORKSTREAM_CHAINS[workstream] ?? WORKSTREAM_CHAINS.general;
  const handoff = {
    path: join(taskRoot, "workflow-handoff.md"),
    workstream,
    skills,
    nextStep: skills[0],
  };
  await writeFile(handoff.path, handoffTemplate(skills), "utf8");
  await appendSectionOnce(
    join(taskRoot, "plan.md"),
    "<!-- qemu-modeling handoff -->",
    `\n## Workflow Handoff\n\n<!-- qemu-modeling handoff -->\n\n- Workstream: ${workstream}\n- Skill chain: ${skills.join(" -> ")}\n- Handoff: workflow-handoff.md\n`,
  );

  emit({
    summary: `wrote QEMU modeling handoff for ${workstream}`,
    data: handoff,
    statePatch: [{ op: "set", path: "/handoff", value: handoff }],
  });
}

async function recordRound() {
  const completed = Array.isArray(context.completedActivations) ? context.completedActivations : [];
  const round = countCompleted(completed, "commitRound") + 1;
  const attempt = countCompletedAfterLast(completed, "recordRound", "commitRound") + 1;
  const summaries = {
    planWork: summarizeActivation(latestActivation(completed, "planWork")),
    researchContract: summarizeActivation(latestActivation(completed, "researchContract")),
    implementationRound: summarizeActivation(
      latestActivationAfterLast(completed, "implementationRound", "commitRound"),
    ),
    verificationRound: summarizeActivation(
      latestActivationAfterLast(completed, "verificationRound", "commitRound"),
    ),
    fixRound: summarizeActivation(latestActivationAfterLast(completed, "fixRound", "commitRound")),
  };
  const artifacts = unique(
    Object.values(summaries).flatMap((summary) => summary.artifacts ?? []),
  );
  const modeling = {
    status: "review-pending",
    round,
    attempt,
    summaries,
    artifacts,
    updatedAt: new Date().toISOString(),
  };
  const roundFile = join(taskRoot, "rlcr", `round-${String(round).padStart(3, "0")}-summary.md`);
  const attemptFile = join(
    taskRoot,
    "reviews",
    `round-${String(round).padStart(3, "0")}-attempt-${String(attempt).padStart(3, "0")}-summary.md`,
  );
  const summary = roundSummaryTemplate(round, attempt, summaries, artifacts);
  await writeFile(roundFile, summary, "utf8");
  await writeFile(attemptFile, summary, "utf8");
  await appendSectionOnce(
    join(taskRoot, "evidence.md"),
    `<!-- qemu-modeling round ${round} attempt ${attempt} -->`,
    `\n## Workflow Round ${round} Attempt ${attempt}\n\n<!-- qemu-modeling round ${round} attempt ${attempt} -->\n\n- Summary: ${summaries.verificationRound.summary}\n- Round summary: rlcr/${basename(roundFile)}\n- Attempt summary: reviews/${basename(attemptFile)}\n- Artifact references: ${artifacts.length ? artifacts.join(", ") : "none recorded"}\n`,
  );

  emit({
    summary: `recorded QEMU modeling round ${round} attempt ${attempt}`,
    data: { round, attempt, roundFile, attemptFile, artifacts },
    statePatch: [{ op: "set", path: "/modeling", value: modeling }],
  });
}

async function finalizeEvidence() {
  const completed = Array.isArray(context.completedActivations) ? context.completedActivations : [];
  const review = latestActivation(completed, "reviewModeling");
  const commit = context.state?.commit ?? {};
  const verdict = commit.verdict ?? review?.output?.data?.verdict ?? context.state?.verdict ?? "unknown";
  const modeling = context.state?.modeling ?? {};
  const final = {
    status: verdict === "COMPLETE" ? "complete" : "incomplete",
    verdict,
    taskRoot,
    workstream,
    completedAt: new Date().toISOString(),
  };
  await writeFile(join(taskRoot, "rlcr", "final-summary.md"), finalSummaryTemplate(final, modeling, commit), "utf8");
  await appendSectionOnce(
    join(taskRoot, "evidence.md"),
    "<!-- qemu-modeling final -->",
    `\n## Workflow Final Summary\n\n<!-- qemu-modeling final -->\n\n- Verdict: ${verdict}\n- Final summary: rlcr/final-summary.md\n- Artifact root: ${relativeTaskRoot()}\n`,
  );

  emit({
    summary: `finalized QEMU modeling workflow with verdict ${verdict}`,
    data: final,
    statePatch: [{ op: "set", path: "/final", value: final }],
  });
}

function parseWorkflowContext() {
  const raw = process.env.OMP_WORKFLOW_CONTEXT;
  if (!raw) return { state: {}, completedActivations: [] };
  try {
    return JSON.parse(raw);
  } catch {
    return { state: {}, completedActivations: [] };
  }
}

async function readTaskSpec() {
  const candidates = [];
  if (typeof process.env.QEMU_TASK_FILE === "string" && process.env.QEMU_TASK_FILE.trim()) {
    const raw = process.env.QEMU_TASK_FILE.trim();
    candidates.push(isAbsolute(raw) ? raw : resolve(cwd, raw));
  }
  candidates.push(join(cwd, "qemu-task.md"), join(cwd, "task.md"));

  for (const path of candidates) {
    if (!existsSync(path)) continue;
    const text = await readFile(path, "utf8");
    return { path, ...parseTaskSpec(text) };
  }
  return {};
}

function parseTaskSpec(text) {
  const { frontmatter, body } = splitTaskFrontmatter(text);
  const heading = firstMarkdownHeading(body);
  const firstLine = firstNonemptyLine(body);
  const brief = body.trim().slice(0, 12000);
  return {
    slug: frontmatter.slug ?? frontmatter.task ?? frontmatter.name ?? heading ?? firstLine,
    title: frontmatter.title ?? heading ?? firstLine,
    workstream: frontmatter.workstream ?? frontmatter.workflow,
    brief,
  };
}

function splitTaskFrontmatter(text) {
  if (!text.startsWith("---\n")) return { frontmatter: {}, body: text };
  const end = text.indexOf("\n---", 4);
  if (end === -1) return { frontmatter: {}, body: text };
  return {
    frontmatter: parseSimpleFrontmatter(text.slice(4, end)),
    body: text.slice(end + 4).replace(/^\r?\n/, ""),
  };
}

function parseSimpleFrontmatter(text) {
  const fields = {};
  for (const line of text.split(/\r?\n/)) {
    const match = line.match(/^([A-Za-z0-9_-]+):\s*(.*)$/);
    if (!match) continue;
    fields[match[1]] = stripTaskSpecQuotes(match[2]);
  }
  return fields;
}

function stripTaskSpecQuotes(value) {
  const trimmed = value.trim();
  if (
    (trimmed.startsWith('"') && trimmed.endsWith('"')) ||
    (trimmed.startsWith("'") && trimmed.endsWith("'"))
  ) {
    return trimmed.slice(1, -1);
  }
  return trimmed;
}

function firstMarkdownHeading(text) {
  const match = text.match(/^#\s+(.+)$/m);
  return match?.[1]?.trim();
}

function firstNonemptyLine(text) {
  return text.split(/\r?\n/).find((entry) => entry.trim().length > 0)?.trim();
}

function slugify(input) {
  const slug = input
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9._-]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 80);
  return slug || "qemu-modeling";
}

async function resolveTaskBrief(stateBrief, spec) {
  if (typeof process.env.QEMU_TASK_BRIEF === "string" && process.env.QEMU_TASK_BRIEF.trim()) {
    return process.env.QEMU_TASK_BRIEF.trim();
  }
  if (typeof stateBrief === "string" && stateBrief.trim()) return stateBrief.trim();
  if (typeof spec.brief === "string" && spec.brief.trim()) return spec.brief.trim();
  return `QEMU modeling workflow for ${slug}`;
}

function inferWorkstream(text) {
  const value = `${rawTaskName} ${text}`.toLowerCase();
  if (/debug|hang|trace|gdb|stuck/.test(value)) return "debug";
  if (/direct.*linux|initrd|dtb|rootfs/.test(value)) return "direct-linux-boot";
  if (/firmware|bootloader|pflash|rom/.test(value)) return "firmware-linux-boot";
  if (/tcg|translator|decode|instruction/.test(value)) return "tcg-frontend";
  if (/backend|host op|register allocation/.test(value)) return "tcg-backend";
  if (/peripheral|sysbus|qdev|device model|uart|spi|i2c|pcie/.test(value)) return "peripheral-modeling";
  if (/board|machine|soc|fdt|irq topology|memory map/.test(value)) return "board-modeling";
  if (/register|mmio|datasheet|bitfield/.test(value)) return "register-extraction";
  if (/u-boot|uboot|spl|tpl|fit|itb/.test(value)) return "uboot-build";
  if (/kernel|vmlinux|bzimage/.test(value)) return "kernel-build";
  if (/image|qcow2|sd card|emmc|flash/.test(value)) return "image-packaging";
  if (/qtest|test/.test(value)) return "qtest";
  if (/rst|docs|documentation/.test(value)) return "documentation";
  if (/build|configure|meson|ninja/.test(value)) return "build";
  return "general";
}

function normalizeWorkstream(value) {
  const normalized = String(value).trim().toLowerCase().replace(/_/g, "-");
  return WORKSTREAM_CHAINS[normalized] ? normalized : "general";
}

async function ensureDir(path, result) {
  if (existsSync(path)) {
    result.kept.push(path);
    return;
  }
  await mkdir(path, { recursive: true });
  result.created.push(path);
}

async function writeIfMissing(path, content, result) {
  if (existsSync(path)) {
    result.kept.push(path);
    return;
  }
  await writeFile(path, content, "utf8");
  result.created.push(path);
}

async function appendSectionOnce(path, marker, content) {
  let existing = "";
  try {
    existing = await readFile(path, "utf8");
  } catch {
    existing = "";
  }
  if (existing.includes(marker)) return false;
  await appendFile(path, content, "utf8");
  return true;
}

function commandLine(command, args) {
  const result = runCommand(command, args);
  if (!result.ok) return result;
  return { ...result, stdout: result.stdout.split(/\r?\n/)[0] ?? "" };
}

function commandOutput(command, args) {
  return runCommand(command, args);
}

function runCommand(command, args) {
  const result = spawnSync(command, args, {
    cwd,
    encoding: "utf8",
    timeout: 2000,
  });
  if (result.error) return { ok: false, stdout: "", error: result.error.message };
  const stdout = (result.stdout ?? "").trim();
  const stderr = (result.stderr ?? "").trim().split(/\r?\n/)[0] ?? "";
  return { ok: result.status === 0, stdout, error: stderr || `exit ${result.status}` };
}

function countCompleted(activations, nodeId) {
  return activations.filter((activation) => activation.nodeId === nodeId && activation.status === "completed").length;
}

function countCompletedAfterLast(activations, nodeId, boundaryNodeId) {
  let boundary = -1;
  for (let index = activations.length - 1; index >= 0; index -= 1) {
    const activation = activations[index];
    if (activation.nodeId === boundaryNodeId && activation.status === "completed") {
      boundary = index;
      break;
    }
  }
  return activations
    .slice(boundary + 1)
    .filter((activation) => activation.nodeId === nodeId && activation.status === "completed").length;
}

function latestActivation(activations, nodeId) {
  for (let index = activations.length - 1; index >= 0; index -= 1) {
    const activation = activations[index];
    if (activation.nodeId === nodeId && activation.status === "completed") return activation;
  }
  return undefined;
}

function latestActivationAfterLast(activations, nodeId, boundaryNodeId) {
  let boundary = -1;
  for (let index = activations.length - 1; index >= 0; index -= 1) {
    const activation = activations[index];
    if (activation.nodeId === boundaryNodeId && activation.status === "completed") {
      boundary = index;
      break;
    }
  }
  for (let index = activations.length - 1; index > boundary; index -= 1) {
    const activation = activations[index];
    if (activation.nodeId === nodeId && activation.status === "completed") return activation;
  }
  return undefined;
}

function summarizeActivation(activation) {
  if (!activation) return { status: "missing", summary: "No completed activation recorded.", artifacts: [] };
  return {
    status: activation.status,
    activationId: activation.id,
    summary: clipText(activation.output?.summary ?? "No summary recorded.", 1600),
    artifacts: activation.output?.artifacts ?? [],
    data: compactData(activation.output?.data),
  };
}

function compactData(data) {
  if (!data || typeof data !== "object" || Array.isArray(data)) return undefined;
  const result = {};
  for (const [key, value] of Object.entries(data)) {
    if (typeof value === "string") result[key] = clipText(value, 800);
    else if (typeof value === "number" || typeof value === "boolean" || value === null) result[key] = value;
  }
  return Object.keys(result).length ? result : undefined;
}

function clipText(text, max) {
  const value = String(text).trim();
  if (value.length <= max) return value;
  return `${value.slice(0, Math.max(0, max - 18)).trimEnd()} …[truncated]`;
}

function unique(values) {
  return [...new Set(values.filter((value) => typeof value === "string" && value.length > 0))];
}

function markdownCell(value) {
  return String(value).replace(/\|/g, "\\|").replace(/\r?\n/g, "<br>");
}

function stageState(status, summary) {
  return { status, summary };
}

function emit(payload) {
  console.log(JSON.stringify(payload));
}

function relativeTaskRoot() {
  return `build/agent/${slug}`;
}

function planTemplate() {
  return `# ${slug} Plan

## Goal

${taskBrief}

## Policy

- QEMU upstream provenance policy applies.
- Agent-created artifacts stay under build/agent/${slug}/.
- Source changes are local workflow outputs unless a human independently rewrites and certifies them for upstream.
- No DCO, Reviewed-by, Acked-by, Tested-by, or similar contribution trailers are added by the agent.

## Scope

### In scope

- Workstream: ${workstream}
- Complete the source research, local modeling/debugging/build work, and verification gates needed by the task.

### Out of scope

- Upstream-ready contribution packaging.
- Agent-authored contribution trailers.

### Allowed source changes

### Local Git Checkpoint Contract

- Task source tree:
- Dedicated local branch:
- Baseline revision:
- Initial dirty paths:
- Round-commit pathspecs:
- QEMU subject prefix:
- Remote publication: forbidden

### Artifact root

\`build/agent/${slug}/\`

## Acceptance Criteria

- AC-1: The task goal is decomposed into testable QEMU modeling or workflow criteria.
  - Evidence: This plan records the criteria and verification gates.
- AC-2: Source provenance and hardware/software contracts are captured before implementation.
  - Evidence: source-provenance.md, source-inventory.md, register-extraction.md, or a recorded reason they are not applicable.
- AC-3: Local QEMU model, board, boot, build, debug, or documentation work is completed for the selected workstream.
  - Evidence: Source changes and artifact references recorded in the round summaries.
- AC-4: Targeted verification proves the relevant behavior.
  - Evidence: commands.md, evidence.md, logs/, qtest/build/boot/debug output as applicable.
- AC-5: Every source-changing logical round has one reviewed local Git
  checkpoint commit.
  - Evidence: source-provenance.md and rlcr/round-NNN-source-state.md.
- AC-6: Independent review returns COMPLETE.
  - Evidence: reviewModeling verdict and rlcr/final-summary.md.

## Verification Gates

## Evidence Ledger

## Open Questions

## Decision Log
`;
}

function evidenceTemplate() {
  return `# ${slug} Evidence

## Sources Read

## Commands Run

## Logs and Artifacts

## Assumptions
`;
}

function commandsTemplate() {
  return `# ${slug} Commands

Record exact commands, working directories, environment overrides, and output artifact paths here.
`;
}

function sourceProvenanceTemplate() {
  return `# ${slug} Source Provenance

## Source Roots

| Component | Path/URL | Revision | Dirty state | Purpose |
| --- | --- | --- | --- | --- |

## RLCR Round Checkpoints

| Round | Parent | Commit | Tree | Subject | Staged paths | Verification/review | Residual dirty state |
| --- | --- | --- | --- | --- | --- | --- | --- |

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
`;
}

function imageLayoutTemplate() {
  return `# ${slug} Image Layout

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
`;
}

function bootRunTemplate() {
  return `# ${slug} Boot Run

## Command

## Inputs

| Input | Path | SHA256 | Provenance |
| --- | --- | --- | --- |

## Console and Logs

## Timeout and Markers

## Result

## Debug Handoff
`;
}

function methodologyFeedbackTemplate() {
  return `# ${slug} Methodology Feedback

## Status

- State: not-analyzed
- Exit reason:
- User asked for issue: no
- Issue filed: no

## Sanitized Workflow Context

- Workflow type: ${workstream}
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
`;
}

function registerExtractionTemplate() {
  return `# ${slug} Register Extraction

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
`;
}

function sourceInventoryTemplate() {
  return `# ${slug} Source Inventory

| Source | Version/Revision | Path/URL | Relevant Sections | Notes |
| --- | --- | --- | --- | --- |
`;
}

function conflictsTemplate() {
  return `# ${slug} Conflicts

| Fact | Source A | Source B | Difference | Resolution/Test |
| --- | --- | --- | --- | --- |
`;
}

function workflowHandoffStub() {
  return `# ${slug} Workflow Handoff

Run the workflow to fill this file with the recommended Oh My QEMU skill chain.
`;
}

function goalTrackerTemplate() {
  return `# Goal Tracker

## Immutable

- Goal: ${taskBrief.replace(/\n/g, " ")}
- Acceptance Criteria: See ../plan.md.

## Mutable

- Active round: 0
- Round commit: none
- Completed:
- Remaining:
- Deferred with reason:
- Decision log:
`;
}

function handoffTemplate(skills) {
  return `# ${slug} Workflow Handoff

## Task

${taskBrief}

## Workstream

${workstream}

## Skill Chain

${skills.map((skill, index) => `${index + 1}. ${skill}`).join("\n")}

## Required Artifact Root

\`build/agent/${slug}/\`

## Workflow Contract

- Start with \`${skills[0]}\`; keep artifacts in this task root.
- For implementation/debugging rounds, use \`qemu-rlcr-loop\` mechanics: one coherent slice, targeted verification, independent review, and one scoped local commit before advancing.
- Use targeted QEMU build/qtest/boot/debug gates that prove the acceptance criteria.
- Preserve QEMU provenance policy: no agent-added DCO or review trailers, and no claim that source output is upstream-ready.

## Completion Bar

The workflow is complete only when source provenance, modeling/build/debug work, targeted verification, and the reviewer gate all agree that the task acceptance criteria are satisfied.
`;
}

function roundSummaryTemplate(round, attempt, summaries, artifacts) {
  return `# Round ${round} Summary

## Attempt

${attempt}

## Plan

${summaries.planWork.summary}

## Research Contract

${summaries.researchContract.summary}

## Implementation

${summaries.implementationRound.summary}

## Verification

${summaries.verificationRound.summary}

## Latest Fix Round

${summaries.fixRound.summary}

## Review

Pending independent review for this attempt.

## Git Checkpoint

- Status: pending review
- Parent:
- Commit:
- Tree:
- Subject:
- Staged paths:
- Residual dirty state:

## Artifacts

${artifacts.length ? artifacts.map((artifact) => `- ${artifact}`).join("\n") : "- None recorded by workflow runtime."}
`;
}

function finalSummaryTemplate(final, modeling, commit) {
  return `# Final Summary

## Status

- Verdict: ${final.verdict}
- Status: ${final.status}
- Workstream: ${final.workstream}
- Artifact root: ${relativeTaskRoot()}

## Acceptance Criteria Status

See ../plan.md and the round summaries in this directory.

## Workflow Modeling State

\`\`\`json
${JSON.stringify(modeling, null, 2)}
\`\`\`

## Latest Round Commit

\`\`\`json
${JSON.stringify(commit, null, 2)}
\`\`\`

## Policy Check

- Agent-created artifacts belong under ${relativeTaskRoot()}/.
- No DCO, Reviewed-by, Acked-by, Tested-by, or similar contribution trailers are added by this workflow.
- Source output is local workflow output, not an upstream-ready contribution package.
- Every source-changing reviewed round is committed locally before the workflow advances.
- The workflow does not push, publish, format, or send round commits.
`;
}
