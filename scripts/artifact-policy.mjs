#!/usr/bin/env node
// Claude Code PreToolUse hook that enforces the QEMU artifact policy:
// agent artifacts must live under .oh-my-qemu/<task-slug>/ and never as
// identifiable root-level scratch/build writes or .plan/.humanize paths.
//
// Reads the PreToolUse JSON payload on stdin. Blocks Write/Edit/MultiEdit
// of policy-violating paths and identifiable Bash writes.
// Blocking uses Claude Code's "exit code 2 -> stderr fed back to the model"
// contract, which is stable across versions.

import {
  artifactPolicyViolation,
  commandPolicyViolation,
  qemuSourceRootViolation,
} from "../src/lib.mjs";

async function readStdin() {
  let data = "";
  for await (const chunk of process.stdin) data += chunk;
  return data;
}

const raw = await readStdin();

let payload;
try {
  payload = JSON.parse(raw);
} catch {
  // Malformed or missing payload: never break the session.
  process.exit(0);
}

const toolName = String(payload?.tool_name ?? payload?.toolName ?? "").toLowerCase();
const input = payload?.tool_input ?? payload?.input ?? {};
const cwd = payload?.cwd ?? process.cwd();

// Claude Code plugins can be enabled outside QEMU. Leave unrelated projects
// untouched and enforce this hook only at a verified QEMU source root.
if (qemuSourceRootViolation(cwd)) {
  process.exit(0);
}

let reason = null;

if (toolName === "write" || toolName === "edit" || toolName === "multiedit") {
  const path =
    (typeof input.file_path === "string" && input.file_path) ||
    (typeof input.file_input === "string" && input.file_input) ||
    (typeof input.path === "string" && input.path) ||
    "";
  reason = artifactPolicyViolation(cwd, path);
} else if (toolName === "bash") {
  const command = typeof input.command === "string" ? input.command : "";
  reason = commandPolicyViolation(cwd, command);
}

if (reason) {
  process.stderr.write(`${reason}\n`);
  process.exit(2);
}

process.exit(0);
