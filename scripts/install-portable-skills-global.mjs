#!/usr/bin/env node

import { spawn } from "node:child_process";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";

const SCRIPT_DIR = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = resolve(SCRIPT_DIR, "..");
const DEFAULT_SOURCE = REPO_ROOT;

// Keep this list in sync with the `skills` CLI agents that define a global
// skill directory. PromptScript is intentionally absent because it is
// project-only in skills 1.5.x and fails global installation.
const GLOBAL_AGENTS = [
  "aider-desk",
  "amp",
  "antigravity",
  "antigravity-cli",
  "astrbot",
  "autohand-code",
  "augment",
  "bob",
  "claude-code",
  "openclaw",
  "cline",
  "codearts-agent",
  "codebuddy",
  "codemaker",
  "codestudio",
  "codex",
  "command-code",
  "continue",
  "cortex",
  "crush",
  "cursor",
  "deepagents",
  "devin",
  "dexto",
  "droid",
  "firebender",
  "forgecode",
  "gemini-cli",
  "github-copilot",
  "goose",
  "hermes-agent",
  "inference-sh",
  "jazz",
  "junie",
  "iflow-cli",
  "kilo",
  "kimi-code-cli",
  "kiro-cli",
  "kode",
  "lingma",
  "loaf",
  "mcpjam",
  "mistral-vibe",
  "moxby",
  "mux",
  "opencode",
  "openhands",
  "ona",
  "pi",
  "qoder",
  "qoder-cn",
  "qwen-code",
  "replit",
  "reasonix",
  "rovodev",
  "roo",
  "tabnine-cli",
  "terramind",
  "tinycloud",
  "trae",
  "trae-cn",
  "warp",
  "windsurf",
  "zed",
  "zencoder",
  "zenflow",
  "neovate",
  "pochi",
  "adal",
  "universal",
];

function usage() {
  return `Usage: node scripts/install-portable-skills-global.mjs [--source SOURCE] [--print]

Installs all oh-my-qemu portable skills globally for agents supported by
the skills CLI global install path. PromptScript is project-only and is not
included, so the command does not emit PromptScript global-install failures.

Options:
  --source SOURCE  Skill source for "npx skills add" (default: this checkout)
  --print          Print the generated npx command without running it
  -h, --help       Show this help
`;
}

function shellQuote(value) {
  if (/^[A-Za-z0-9_@%+=:,./-]+$/.test(value)) {
    return value;
  }
  return `'${value.replaceAll("'", "'\\''")}'`;
}

function parseArgs(argv) {
  const options = {
    source: DEFAULT_SOURCE,
    print: false,
  };

  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === "-h" || arg === "--help") {
      console.log(usage());
      process.exit(0);
    }
    if (arg === "--print") {
      options.print = true;
      continue;
    }
    if (arg === "--source") {
      const source = argv[++i];
      if (!source) {
        throw new Error("--source requires a value");
      }
      options.source = source;
      continue;
    }
    if (arg.startsWith("--source=")) {
      options.source = arg.slice("--source=".length);
      continue;
    }
    throw new Error(`Unknown argument: ${arg}`);
  }

  return options;
}

function buildCommand(source) {
  return [
    "skills",
    "add",
    source,
    "-g",
    "--skill",
    "*",
    ...GLOBAL_AGENTS.flatMap((agent) => ["--agent", agent]),
    "-y",
  ];
}

async function run(command, args) {
  const child = spawn(command, args, {
    stdio: "inherit",
  });

  return await new Promise((resolveCode, reject) => {
    child.on("error", reject);
    child.on("close", resolveCode);
  });
}

async function main() {
  let options;
  try {
    options = parseArgs(process.argv.slice(2));
  } catch (error) {
    console.error(error.message);
    console.error();
    console.error(usage());
    process.exit(2);
  }

  const npx = process.platform === "win32" ? "npx.cmd" : "npx";
  const args = buildCommand(options.source);

  if (options.print) {
    console.log([npx, ...args].map(shellQuote).join(" "));
    return;
  }

  const code = await run(npx, args);
  if (code !== 0) {
    process.exit(code ?? 1);
  }

  if (resolve(options.source) === REPO_ROOT) {
    console.log();
    console.log("Refreshing Codex global skill links...");
    const registerCode = await run(process.execPath, [
      resolve(SCRIPT_DIR, "register-codex-skills.mjs"),
    ]);
    process.exit(registerCode ?? 1);
  }
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : String(error));
  process.exit(1);
});
