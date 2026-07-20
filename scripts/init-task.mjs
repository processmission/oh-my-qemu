#!/usr/bin/env node
// Claude Code entry point for the /qemu-init-task command.
// Creates a minimal .oh-my-qemu/<task-slug>/ audit workspace plus source-root
// builds/, and updates the repository-local Git exclude file.
//
// Usage: node init-task.mjs [task-name]
// If no name is given, the current directory name is used as the slug.

import { basename } from "node:path";
import { initQemuTask, resultText } from "../src/lib.mjs";

const cwd = process.cwd();
const name = (process.argv[2] ?? "").trim() || basename(cwd);
const result = initQemuTask(cwd, name);

process.stdout.write(resultText(result) + "\n");
