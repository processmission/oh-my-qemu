#!/usr/bin/env node

import { spawnSync } from "node:child_process";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { discoverWorkflows, validateWorkflow } from "./validate-workflows.mjs";

const repoRoot = dirname(dirname(fileURLToPath(import.meta.url)));
const workflowsRoot = join(repoRoot, "workflows");

function parseArgs(argv) {
  const options = {
    dryRun: false,
    force: true,
    ompBin: process.env.OMP_BIN || "omp",
  };
  for (let index = 0; index < argv.length; index++) {
    const arg = argv[index];
    if (arg === "--dry-run") {
      options.dryRun = true;
    } else if (arg === "--no-force") {
      options.force = false;
    } else if (arg === "--force") {
      options.force = true;
    } else if (arg === "--omp-bin") {
      const value = argv[++index];
      if (!value) throw new Error("--omp-bin requires a value");
      options.ompBin = value;
    } else if (arg.startsWith("--omp-bin=")) {
      options.ompBin = arg.slice("--omp-bin=".length);
    } else {
      throw new Error(`unknown option: ${arg}`);
    }
  }
  return options;
}

function installWorkflow(workflow, options) {
  const args = ["workflow", "install", workflow.flowFile];
  if (options.force) args.push("--force");
  if (options.dryRun) {
    console.log(`[dry-run] ${options.ompBin} ${args.map(quoteArg).join(" ")}`);
    return;
  }
  const result = spawnSync(options.ompBin, args, {
    cwd: repoRoot,
    encoding: "utf8",
    stdio: "inherit",
  });
  if (result.error) throw result.error;
  if (result.status !== 0) {
    throw new Error(`${options.ompBin} ${args.join(" ")} exited with ${result.status}`);
  }
}

function quoteArg(value) {
  return /[\s"']/.test(value) ? JSON.stringify(value) : value;
}

function main() {
  const options = parseArgs(process.argv.slice(2));
  const workflows = discoverWorkflows(workflowsRoot);
  if (workflows.length === 0) {
    console.error(`No workflow artifacts found under ${workflowsRoot}`);
    process.exit(1);
  }
  const errors = workflows.flatMap(validateWorkflow);
  if (errors.length) {
    for (const error of errors) console.error(`ERROR ${error}`);
    process.exit(1);
  }
  for (const workflow of workflows) installWorkflow(workflow, options);
  console.log(`${options.dryRun ? "Would install" : "Installed"} ${workflows.length} workflow artifact(s).`);
}

main();
