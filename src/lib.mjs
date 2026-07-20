import { spawnSync } from "node:child_process";
import {
  existsSync,
  mkdirSync,
  readFileSync,
  realpathSync,
  statSync,
  writeFileSync,
} from "node:fs";
import { basename, dirname, join, relative, resolve } from "node:path";

// Shared, runtime-agnostic workspace and artifact-policy logic for the Oh My
// Pi extension and Claude Code plugin scripts.

export const ROOT_FILES = {
  "audit.md": true,
  "commands.md": true,
  "plan.md": true,
  "evidence.md": true,
  "register-extraction.md": true,
  "source-provenance.md": true,
  "image-layout.md": true,
  "boot-run.md": true,
  "methodology-feedback.md": true,
  "source-inventory.md": true,
  "conflicts.md": true,
  "debugger.md": true,
  "final-summary.md": true,
};

// Values are the canonical task-directory destination. Legacy names remain
// blocked at the source root and point to the simplified layout.
export const ROOT_DIRS = {
  logs: "logs",
  scripts: "scripts",
  output: "output",
  scratch: "scripts",
  reviews: "logs",
  rlcr: "logs",
};

export const QEMU_SOURCE_ROOT_FILES = [
  "configure",
  "meson.build",
  "VERSION",
  "docs/devel/code-provenance.rst",
];

export const TASK_ROOT_DIR = ".oh-my-qemu";
export const QEMU_BUILD_ROOT_DIR = "builds";
export const LOCAL_GIT_EXCLUDES = [".agents/", ".oh-my-qemu/", "builds/"];

export function slugify(input) {
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

export function taskRoot(cwd, slug) {
  return join(cwd, TASK_ROOT_DIR, slug);
}

export function initQemuTask(cwd, rawName) {
  assertQemuSourceRoot(cwd);
  ensureLocalGitExclude(cwd);

  const slug = slugify(rawName);
  const root = taskRoot(cwd, slug);
  const buildRoot = join(cwd, QEMU_BUILD_ROOT_DIR);
  const result = { slug, root, buildRoot, created: [], kept: [] };

  ensureDir(root, result);
  ensureDir(join(root, "logs"), result);
  ensureDir(join(root, "scripts"), result);
  ensureDir(join(root, "output"), result);
  ensureDir(buildRoot, result);

  writeIfMissing(join(root, "audit.md"), `# ${slug} Audit

## Baseline

- Workspace root:
- Branch/revision:
- Initial \`git status --short\`:
- User-owned dirty paths:
- QEMU build directory: \`builds/build-<target>/\`

## Goal, scope, and non-goals

## Acceptance checks

## Sources and provenance

## Decisions and assumptions

## Work and review record

## Evidence and verification

## Unresolved gaps

## Handoff
`, result);

  writeIfMissing(join(root, "commands.md"), `# ${slug} Commands

Record safely redacted commands, working directories, relevant environment,
exit status, concise results, and decisive log paths here.
`, result);

  return result;
}

function isRegularFile(path) {
  try {
    return statSync(path).isFile();
  } catch {
    return false;
  }
}

function gitLine(cwd, args) {
  const result = spawnSync("git", ["-C", cwd, ...args], {
    encoding: "utf8",
    timeout: 2000,
  });
  if (result.error) {
    return { ok: false, stdout: "", error: result.error.message };
  }
  const stdout = (result.stdout ?? "").trim().split(/\r?\n/)[0] ?? "";
  const stderr = (result.stderr ?? "").trim().split(/\r?\n/)[0] ?? "";
  return { ok: result.status === 0, stdout, error: stderr || `exit ${result.status}` };
}

export function ensureLocalGitExclude(cwd) {
  const gitInside = gitLine(cwd, ["rev-parse", "--is-inside-work-tree"]);
  if (!gitInside.ok || gitInside.stdout !== "true") {
    return false;
  }

  const exclude = gitLine(cwd, ["rev-parse", "--git-path", "info/exclude"]);
  if (!exclude.ok || !exclude.stdout) {
    return false;
  }

  const excludePath = resolve(cwd, exclude.stdout);
  let existing = "";
  try {
    existing = readFileSync(excludePath, "utf8");
  } catch {
    existing = "";
  }

  const normalized = new Set(
    existing
      .split(/\r?\n/)
      .map((line) => line.replace(/^\/+|\/+$/g, ""))
      .filter(Boolean),
  );
  const missing = LOCAL_GIT_EXCLUDES.filter(
    (entry) => !normalized.has(entry.replace(/\/+$/, "")),
  );
  if (missing.length === 0) {
    return false;
  }

  mkdirSync(dirname(excludePath), { recursive: true });
  const prefix = existing.length > 0 && !existing.endsWith("\n") ? "\n" : "";
  writeFileSync(excludePath, `${existing}${prefix}${missing.join("\n")}\n`, "utf8");
  return true;
}

export function qemuSourceRootViolation(cwd) {
  const missing = QEMU_SOURCE_ROOT_FILES.filter((path) => !isRegularFile(join(cwd, path)));
  if (missing.length > 0) {
    return `Oh My QEMU must be started from a QEMU source root. Missing required files under ${cwd}: ${missing.join(", ")}.`;
  }

  const gitInside = gitLine(cwd, ["rev-parse", "--is-inside-work-tree"]);
  if (gitInside.ok && gitInside.stdout === "true") {
    const gitRoot = gitLine(cwd, ["rev-parse", "--show-toplevel"]);
    if (!gitRoot.ok || !gitRoot.stdout) {
      return `Oh My QEMU could not determine the Git worktree root for ${cwd}: ${gitRoot.error}.`;
    }

    const expected = realpathSync(cwd);
    const actual = realpathSync(gitRoot.stdout);
    if (actual !== expected) {
      return `Oh My QEMU must be started from the QEMU Git worktree root. CWD is ${expected}, but Git root is ${actual}.`;
    }
  }

  return null;
}

export function assertQemuSourceRoot(cwd) {
  const reason = qemuSourceRootViolation(cwd);
  if (reason) {
    throw new Error(reason);
  }
}

export function isInsideTaskArtifacts(cwd, rawPath) {
  const absolute = resolve(cwd, rawPath);
  return /[\\/]\.oh-my-qemu[\\/][^\\/]+[\\/]/.test(absolute);
}

export function artifactPolicyViolation(cwd, rawPath) {
  if (!rawPath || isInsideTaskArtifacts(cwd, rawPath)) {
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

  if (parts[0] === TASK_ROOT_DIR) {
    return `QEMU agent artifacts must be written under .oh-my-qemu/<task-slug>/, not ${rel}.`;
  }

  if (parts.includes(".plan") || parts.includes(".humanize")) {
    return `QEMU agent artifacts must be written under .oh-my-qemu/<task-slug>/, not ${rel}.`;
  }

  if (parts[0] === "build") {
    return `QEMU build output must use builds/build-<target>/, not ${rel}.`;
  }

  if (parts.length === 1 && ROOT_FILES[parts[0]]) {
    return `Root-level ${parts[0]} would pollute the QEMU source tree. Use .oh-my-qemu/<task-slug>/audit.md or another task-local record.`;
  }

  const legacyRootDirs = new Set(["scratch", "reviews", "rlcr"]);
  if (
    ROOT_DIRS[parts[0]] &&
    (parts.length === 1 || legacyRootDirs.has(parts[0]))
  ) {
    return `Root-level ${parts[0]}/ would pollute the QEMU source tree. Use .oh-my-qemu/<task-slug>/${ROOT_DIRS[parts[0]]}/.`;
  }

  return null;
}

function shellClauses(command) {
  const clauses = [];
  let current = "";
  let quote = null;

  for (let index = 0; index < command.length; index += 1) {
    const char = command[index];
    const next = command[index + 1];

    if (quote) {
      current += char;
      if (quote === '"' && char === "\\" && next) {
        current += next;
        index += 1;
      } else if (char === quote) {
        quote = null;
      }
      continue;
    }

    if (char === "'" || char === '"') {
      quote = char;
      current += char;
      continue;
    }
    if (char === "\\" && next) {
      current += char + next;
      index += 1;
      continue;
    }

    const separator =
      char === ";" || char === "\n" || char === "|" ||
      (char === "&" && next === "&");
    if (separator) {
      if (current.trim()) {
        clauses.push(current);
      }
      current = "";
      if ((char === "|" && next === "|") || (char === "&" && next === "&")) {
        index += 1;
      }
      continue;
    }
    current += char;
  }

  if (current.trim()) {
    clauses.push(current);
  }
  return clauses;
}

function shellWords(clause) {
  const words = [];
  let current = "";
  let quote = null;
  const push = () => {
    if (current) {
      words.push(current);
      current = "";
    }
  };

  for (let index = 0; index < clause.length; index += 1) {
    const char = clause[index];
    const next = clause[index + 1];

    if (quote) {
      if (char === quote) {
        quote = null;
      } else if (quote === '"' && char === "\\" && next) {
        current += next;
        index += 1;
      } else {
        current += char;
      }
      continue;
    }

    if (char === "'" || char === '"') {
      quote = char;
    } else if (char === "\\" && next) {
      current += next;
      index += 1;
    } else if (/\s/.test(char)) {
      push();
    } else if (char === "#" && current === "") {
      break;
    } else if (char === ">") {
      push();
      const operator = next === ">" ? ">>" : ">";
      words.push(operator);
      if (next === ">") {
        index += 1;
      }
    } else {
      current += char;
    }
  }
  push();
  return words;
}

function shellExecutable(words) {
  let index = 0;
  while (/^[A-Za-z_][A-Za-z0-9_]*=/.test(words[index] ?? "")) {
    index += 1;
  }

  if (words[index] === "env") {
    index += 1;
    while (/^[A-Za-z_][A-Za-z0-9_]*=/.test(words[index] ?? "")) {
      index += 1;
    }
  } else if (words[index] === "command") {
    index += 1;
    if (words[index] === "--") {
      index += 1;
    } else if ((words[index] ?? "").startsWith("-")) {
      return "";
    }
  } else if (words[index] === "sudo") {
    return "";
  }

  return words[index] ? basename(words[index]) : "";
}

function rootRelativePath(word, name) {
  const path = word.startsWith("./") ? word.slice(2) : word;
  return path === name || path.startsWith(`${name}/`);
}

function relativePathSegment(word, name) {
  if (word.startsWith("/") || word.startsWith("../")) {
    return false;
  }
  const path = word.startsWith("./") ? word.slice(2) : word;
  return path.split("/").includes(name);
}

function optionTargetsPath(words, matchesPath) {
  const separateOptions = new Set([
    "-B", "-C", "-o", "--build", "--build-dir", "--builddir",
    "--directory", "--out-dir", "--output",
  ]);
  for (let index = 1; index < words.length; index += 1) {
    const word = words[index];
    if (separateOptions.has(word) && matchesPath(words[index + 1] ?? "")) {
      return true;
    }
    const assignment = word.match(/^(?:O|of|--build|--build-dir|--builddir|--directory|--out-dir|--output)=(.+)$/);
    if (assignment && matchesPath(assignment[1])) {
      return true;
    }
  }
  return false;
}

export function commandPolicyViolation(command) {
  const directWriters = new Set(["mkdir", "rm", "rmdir", "tee", "touch", "truncate"]);
  const copyLikeWriters = new Set(["cp", "install", "mv", "rsync"]);
  const buildTools = new Set(["cmake", "make", "meson", "ninja"]);
  const policies = [
    {
      matches: (word) => rootRelativePath(word, "build"),
      reason: "QEMU build output must use builds/build-<target>/, not an unqualified build/ path.",
    },
    {
      matches: (word) => rootRelativePath(word, "scratch"),
      reason: "QEMU task helpers must use .oh-my-qemu/<task-slug>/scripts/, not a root-level scratch/ path.",
    },
    {
      matches: (word) => relativePathSegment(word, ".plan") || relativePathSegment(word, ".humanize"),
      reason: "QEMU agent artifacts must stay under .oh-my-qemu/<task-slug>/, not .plan/ or .humanize/.",
    },
  ];

  for (const clause of shellClauses(command)) {
    const words = shellWords(clause);
    const executable = shellExecutable(words);
    if (!executable) {
      continue;
    }

    for (const policy of policies) {
      const redirect = words.some(
        (word, index) => (word === ">" || word === ">>") && policy.matches(words[index + 1] ?? ""),
      );
      const direct = directWriters.has(executable) && words.slice(1).some(policy.matches);
      const copied = copyLikeWriters.has(executable) && policy.matches(words.at(-1) ?? "");
      const buildOutput = buildTools.has(executable) &&
        (optionTargetsPath(words, policy.matches) ||
          (executable === "meson" && words.includes("setup") && words.some(policy.matches)));
      const ddOutput = executable === "dd" && optionTargetsPath(words, policy.matches);

      if (redirect || direct || copied || buildOutput || ddOutput) {
        return policy.reason;
      }
    }
  }
  return null;
}

export function resultText(result) {
  return [
    `QEMU task workspace: ${result.root}`,
    `QEMU build root: ${result.buildRoot}`,
    `Local Git excludes: ${LOCAL_GIT_EXCLUDES.join(", ")}`,
    `Slug: ${result.slug}`,
    `Created: ${result.created.length}`,
    `Kept: ${result.kept.length}`,
  ].join("\n");
}

export function defaultTaskName(cwd) {
  return basename(cwd);
}
