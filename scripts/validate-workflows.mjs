#!/usr/bin/env node

import { existsSync, readFileSync, readdirSync } from "node:fs";
import { dirname, join, basename } from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = dirname(dirname(fileURLToPath(import.meta.url)));
const workflowsRoot = join(repoRoot, "workflows");

export function discoverWorkflows(root = workflowsRoot) {
  if (!existsSync(root)) return [];
  return readdirSync(root, { withFileTypes: true })
    .filter((entry) => entry.isFile() && entry.name.endsWith(".omhflow"))
    .map((entry) => ({
      name: basename(entry.name, ".omhflow"),
      flowFile: join(root, entry.name),
      resourceDir: join(root, basename(entry.name, ".omhflow")),
    }))
    .sort((a, b) => a.name.localeCompare(b.name));
}

function parseFrontmatter(content) {
  if (!content.startsWith("---\n")) throw new Error("missing YAML frontmatter");
  const end = content.indexOf("\n---", 4);
  if (end === -1) throw new Error("unterminated YAML frontmatter");
  const fields = new Map();
  for (const line of content.slice(4, end).split("\n")) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;
    const match = trimmed.match(/^([A-Za-z0-9_-]+):\s*(.*)$/);
    if (!match) continue;
    fields.set(match[1], stripQuotes(match[2]));
  }
  return Object.fromEntries(fields);
}

function stripQuotes(value) {
  const trimmed = value.trim();
  if (
    (trimmed.startsWith('"') && trimmed.endsWith('"')) ||
    (trimmed.startsWith("'") && trimmed.endsWith("'"))
  ) {
    return trimmed.slice(1, -1);
  }
  return trimmed;
}

function declaredResourcePaths(content) {
  const paths = [];
  const resourceBlock = content.match(/^resources:\n([\s\S]*?)(?=^[A-Za-z_][A-Za-z0-9_]*:|\s*```|$)/m);
  const body = resourceBlock?.[1] ?? "";
  for (const match of body.matchAll(/^\s*-?\s*path:\s*(.+)$/gm)) {
    paths.push(stripQuotes(match[1]));
  }
  return paths;
}

export function validateWorkflow(workflow) {
  const errors = [];
  const content = readFileSync(workflow.flowFile, "utf8");
  let frontmatter;
  try {
    frontmatter = parseFrontmatter(content);
  } catch (error) {
    return [`${workflow.name}: ${error.message}`];
  }

  if (frontmatter.name !== workflow.name) {
    errors.push(`${workflow.name}: frontmatter name must match filename`);
  }
  if (frontmatter.schema !== "omhflow/v1") {
    errors.push(`${workflow.name}: schema must be omhflow/v1`);
  }
  if (!/^```(?:yaml|yml|json)\s+workflow\s*$/m.test(content)) {
    errors.push(`${workflow.name}: missing fenced workflow block`);
  }
  if (!existsSync(workflow.resourceDir)) {
    errors.push(`${workflow.name}: missing same-name resource directory`);
  }
  for (const resourcePath of declaredResourcePaths(content)) {
    if (resourcePath.startsWith("/") || resourcePath.includes("..")) {
      errors.push(`${workflow.name}: resource path escapes resource directory: ${resourcePath}`);
      continue;
    }
    if (!existsSync(join(workflow.resourceDir, resourcePath))) {
      errors.push(`${workflow.name}: missing resource ${resourcePath}`);
    }
  }
  return errors;
}

export function validateAll(root = workflowsRoot) {
  const workflows = discoverWorkflows(root);
  const errors = workflows.flatMap(validateWorkflow);
  return { workflows, errors };
}

function main() {
  const { workflows, errors } = validateAll();
  if (errors.length) {
    for (const error of errors) console.error(`ERROR ${error}`);
    process.exit(1);
  }
  console.log(`Validated ${workflows.length} workflow artifact(s).`);
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  main();
}
