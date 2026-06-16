#!/usr/bin/env node

import { existsSync, readFileSync, readdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = dirname(dirname(fileURLToPath(import.meta.url)));
const skillsRoot = join(repoRoot, ".agents", "skills");
const allowedFrontmatter = new Set(["name", "description"]);

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

export function discoverSkills(root = skillsRoot) {
  return readdirSync(root, { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .map((entry) => ({
      name: entry.name,
      dir: join(root, entry.name),
      skillFile: join(root, entry.name, "SKILL.md"),
    }))
    .filter((skill) => existsSync(skill.skillFile))
    .sort((a, b) => a.name.localeCompare(b.name));
}

function parseFrontmatter(content) {
  if (!content.startsWith("---\n")) {
    throw new Error("missing YAML frontmatter");
  }
  const end = content.indexOf("\n---", 4);
  if (end === -1) {
    throw new Error("unterminated YAML frontmatter");
  }

  const fields = new Map();
  const lines = content.slice(4, end).split("\n").filter((line) => line.trim());
  for (const line of lines) {
    const match = line.match(/^([A-Za-z0-9_-]+):\s*(.*)$/);
    if (!match) {
      throw new Error(`unsupported frontmatter line: ${line}`);
    }
    const key = match[1];
    if (!allowedFrontmatter.has(key)) {
      throw new Error(`unexpected frontmatter key: ${key}`);
    }
    fields.set(key, stripQuotes(match[2]));
  }

  return Object.fromEntries(fields);
}

export function validateSkill(skill) {
  const errors = [];
  const content = readFileSync(skill.skillFile, "utf8");
  let frontmatter;

  try {
    frontmatter = parseFrontmatter(content);
  } catch (error) {
    return [`${skill.name}: ${error.message}`];
  }

  if (frontmatter.name !== skill.name) {
    errors.push(`${skill.name}: frontmatter name must match folder name`);
  }
  if (!/^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(frontmatter.name ?? "")) {
    errors.push(`${skill.name}: name must be lowercase hyphen-case`);
  }
  if (!frontmatter.description || frontmatter.description.includes("[TODO")) {
    errors.push(`${skill.name}: description is missing or still a TODO`);
  }
  if ((frontmatter.description ?? "").length > 1024) {
    errors.push(`${skill.name}: description exceeds 1024 characters`);
  }
  if (/[<>]/.test(frontmatter.description ?? "")) {
    errors.push(`${skill.name}: description must not contain angle brackets`);
  }

  return errors;
}

export function validateAll(root = skillsRoot) {
  const skills = discoverSkills(root);
  const errors = skills.flatMap(validateSkill);
  return { skills, errors };
}

function main() {
  const { skills, errors } = validateAll();
  if (errors.length) {
    for (const error of errors) {
      console.error(`ERROR ${error}`);
    }
    process.exit(1);
  }

  console.log(`Validated ${skills.length} Codex skill(s).`);
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  main();
}
