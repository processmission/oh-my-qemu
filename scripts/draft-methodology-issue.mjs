#!/usr/bin/env node

import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { basename, dirname, join, resolve } from "node:path";

function usage() {
  return `Usage: node scripts/draft-methodology-issue.mjs <build/agent/task> [--repo owner/name] [--output path]

Creates a GitHub issue draft from build/agent/<task>/methodology-feedback.md.
The feedback file must already be sanitized and approved for user review.

Options:
  --repo owner/name   Target issue repository, default processmission/oh-my-qemu
  --output path       Output draft path, default <task>/scratch/methodology-issue.md
`;
}

function parseArgs(argv) {
  const options = {
    taskRoot: null,
    repo: process.env.QEMU_METHODOLOGY_ISSUE_REPO || "processmission/oh-my-qemu",
    output: null,
  };

  for (let index = 2; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg === "--help" || arg === "-h") {
      console.log(usage());
      process.exit(0);
    }
    if (arg === "--repo") {
      index += 1;
      options.repo = argv[index];
      continue;
    }
    if (arg === "--output") {
      index += 1;
      options.output = argv[index];
      continue;
    }
    if (!options.taskRoot) {
      options.taskRoot = arg;
      continue;
    }
    throw new Error(`unknown argument: ${arg}`);
  }

  if (!options.taskRoot) {
    throw new Error("missing build/agent task directory");
  }
  if (!options.repo || !/^[^/\s]+\/[^/\s]+$/.test(options.repo)) {
    throw new Error("--repo must use owner/name form");
  }

  options.taskRoot = resolve(options.taskRoot);
  options.output = options.output
    ? resolve(options.output)
    : join(options.taskRoot, "scratch", "methodology-issue.md");

  return options;
}

function section(markdown, heading) {
  const lines = markdown.split(/\r?\n/);
  const start = lines.findIndex((line) => line.trim() === `## ${heading}`);
  if (start === -1) {
    return "";
  }

  const body = [];
  for (let index = start + 1; index < lines.length; index += 1) {
    if (lines[index].startsWith("## ")) {
      break;
    }
    body.push(lines[index]);
  }
  return body.join("\n").trim();
}

function subsection(markdown, heading) {
  const lines = markdown.split(/\r?\n/);
  const start = lines.findIndex((line) => line.trim() === `### ${heading}`);
  if (start === -1) {
    return "";
  }

  const body = [];
  for (let index = start + 1; index < lines.length; index += 1) {
    if (lines[index].startsWith("### ") || lines[index].startsWith("## ")) {
      break;
    }
    body.push(lines[index]);
  }
  return body.join("\n").trim();
}

function issueDraftField(markdown, heading) {
  const lines = markdown.split(/\r?\n/);
  const issueStart = lines.findIndex((line) => line.trim() === "## Issue Draft");
  if (issueStart === -1) {
    return "";
  }

  let issueEnd = lines.length;
  for (let index = issueStart + 1; index < lines.length; index += 1) {
    if (lines[index].trim() === "## Privacy Check") {
      issueEnd = index;
      break;
    }
  }

  const start = lines.findIndex((line, index) =>
    index > issueStart && index < issueEnd && line.trim() === `### ${heading}`);
  if (start === -1) {
    return "";
  }

  const body = [];
  for (let index = start + 1; index < issueEnd; index += 1) {
    if (lines[index].startsWith("### ")) {
      break;
    }
    body.push(lines[index]);
  }
  return body.join("\n").trim();
}

function firstNonemptyLine(text) {
  return text
    .split(/\r?\n/)
    .map((line) => line.replace(/^[-*\s]+/, "").trim())
    .find(Boolean);
}

function privacyWarnings(text) {
  const warnings = [];
  const checks = [
    [/\/Users\/|\/home\/|[A-Za-z]:\\/, "possible local filesystem path"],
    [/\b[0-9a-f]{7,40}\b/i, "possible commit hash or raw identifier"],
    [/```/, "code fence present"],
    [/https?:\/\/(?!github\.com\/processmission\/oh-my-qemu\b)/, "project-specific URL"],
    [/\b(traceback|stack trace|segmentation fault|panic:|assertion failed)\b/i, "raw error wording"],
  ];

  for (const [pattern, message] of checks) {
    if (pattern.test(text)) {
      warnings.push(message);
    }
  }

  return warnings;
}

function titlePathFor(output) {
  return output.endsWith(".md")
    ? output.slice(0, -3) + "-title.txt"
    : output + ".title.txt";
}

function buildIssue(markdown, taskName) {
  const explicitTitle = issueDraftField(markdown, "Title") || subsection(markdown, "Title");
  const explicitBody = issueDraftField(markdown, "Body") || subsection(markdown, "Body");
  const suggestions = section(markdown, "Improvement Suggestions");
  const patterns = section(markdown, "Observed Patterns");
  const context = section(markdown, "Sanitized Workflow Context");

  const title = explicitTitle || firstNonemptyLine(suggestions) || `Improve QEMU workflow feedback from ${taskName}`;
  const body = explicitBody || `## Summary

${firstNonemptyLine(suggestions) || "Sanitized workflow feedback identified a reusable improvement opportunity."}

## Sanitized Workflow Context

${context || "- Not specified"}

## Observed Pattern

${patterns || "- Not specified"}

## Proposed Improvement

${suggestions || "- Not specified"}

## Acceptance Criteria

- The workflow improvement is documented or implemented in oh-my-qemu.
- Future QEMU modeling sessions can apply it without project-specific context.

## Privacy Check

- No private paths
- No branch names or commit hashes
- No proprietary logs or raw stack traces
- No code snippets
- No project-specific URLs or endpoints
`;

  return { title, body: body.trim() + "\n" };
}

function main() {
  const options = parseArgs(process.argv);
  const feedbackPath = join(options.taskRoot, "methodology-feedback.md");
  if (!existsSync(feedbackPath)) {
    throw new Error(`methodology feedback file not found: ${feedbackPath}`);
  }

  const markdown = readFileSync(feedbackPath, "utf8");
  const warnings = privacyWarnings(markdown);
  if (warnings.length) {
    console.error("Privacy warnings:");
    for (const warning of warnings) {
      console.error(`- ${warning}`);
    }
    console.error("Review and sanitize methodology-feedback.md before filing an issue.");
  }

  const draft = buildIssue(markdown, basename(options.taskRoot));
  const titlePath = titlePathFor(options.output);
  mkdirSync(dirname(options.output), { recursive: true });
  writeFileSync(options.output, draft.body, "utf8");
  writeFileSync(titlePath, draft.title + "\n", "utf8");
  console.log(`Title: ${titlePath}`);
  console.log(`Body: ${options.output}`);
  console.log(`Repo: ${options.repo}`);

  if (warnings.length) {
    process.exitCode = 2;
  }
}

try {
  main();
} catch (error) {
  console.error(`ERROR ${error.message}`);
  process.exit(1);
}
