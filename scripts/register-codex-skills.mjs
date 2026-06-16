#!/usr/bin/env node

import {
  cpSync,
  existsSync,
  lstatSync,
  mkdirSync,
  readlinkSync,
  realpathSync,
  rmSync,
  symlinkSync,
} from "node:fs";
import { dirname, join, resolve } from "node:path";
import { homedir } from "node:os";
import { fileURLToPath } from "node:url";
import { discoverSkills, validateAll } from "./validate-codex-skills.mjs";

const repoRoot = dirname(dirname(fileURLToPath(import.meta.url)));
const sourceRoot = join(repoRoot, ".agents", "skills");

function usage() {
  return `Usage: node scripts/register-codex-skills.mjs [--dry-run] [--copy] [--force] [--target DIR]

Registers .agents/skills into Codex's skills directory.

Options:
  --dry-run      Print actions without writing anything
  --copy         Copy skill directories instead of symlinking them
  --force        Replace existing target skill directories
  --target DIR   Register into DIR instead of \${CODEX_HOME:-$HOME/.codex}/skills
`;
}

function parseArgs(argv) {
  const options = {
    copy: false,
    dryRun: false,
    force: false,
    target: null,
  };

  for (let i = 2; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === "--copy") {
      options.copy = true;
    } else if (arg === "--dry-run") {
      options.dryRun = true;
    } else if (arg === "--force") {
      options.force = true;
    } else if (arg === "--target") {
      i += 1;
      if (!argv[i]) {
        throw new Error("--target requires a directory");
      }
      options.target = resolve(argv[i]);
    } else if (arg === "--help" || arg === "-h") {
      console.log(usage());
      process.exit(0);
    } else {
      throw new Error(`unknown argument: ${arg}`);
    }
  }

  const codexHome = process.env.CODEX_HOME || join(homedir(), ".codex");
  options.target ??= join(codexHome, "skills");
  return options;
}

function sameTarget(existingPath, sourcePath) {
  const stat = lstatSync(existingPath);
  if (!stat.isSymbolicLink()) {
    return false;
  }
  const linkTarget = resolve(dirname(existingPath), readlinkSync(existingPath));
  return realpathSync(linkTarget) === realpathSync(sourcePath);
}

function registerSkill(skill, targetRoot, options) {
  const dest = join(targetRoot, skill.name);
  const source = join(sourceRoot, skill.name);
  const verb = options.copy ? "copy" : "link";

  if (existsSync(dest)) {
    if (!options.copy && sameTarget(dest, source)) {
      console.log(`OK ${skill.name}: already linked`);
      return;
    }
    if (!options.force) {
      throw new Error(`${skill.name}: target already exists at ${dest}; use --force to replace`);
    }
    console.log(`${options.dryRun ? "WOULD " : ""}replace ${dest}`);
    if (!options.dryRun) {
      rmSync(dest, { recursive: true, force: true });
    }
  }

  console.log(`${options.dryRun ? "WOULD " : ""}${verb} ${skill.name} -> ${dest}`);
  if (options.dryRun) {
    return;
  }

  if (options.copy) {
    cpSync(source, dest, { recursive: true });
  } else {
    symlinkSync(source, dest, "dir");
  }
}

function main() {
  const options = parseArgs(process.argv);
  const { skills, errors } = validateAll(sourceRoot);
  if (errors.length) {
    for (const error of errors) {
      console.error(`ERROR ${error}`);
    }
    process.exit(1);
  }

  if (!options.dryRun) {
    mkdirSync(options.target, { recursive: true });
  }

  for (const skill of skills) {
    registerSkill(skill, options.target, options);
  }

  console.log(`${options.dryRun ? "Dry-run checked" : "Registered"} ${skills.length} Codex skill(s) in ${options.target}.`);
}

try {
  main();
} catch (error) {
  console.error(`ERROR ${error.message}`);
  process.exit(1);
}
