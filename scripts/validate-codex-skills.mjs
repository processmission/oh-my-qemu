#!/usr/bin/env node

import { existsSync, readFileSync, readdirSync, statSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { commandPolicyViolation } from "../src/lib.mjs";

const repoRoot = dirname(dirname(fileURLToPath(import.meta.url)));
const skillsRoot = join(repoRoot, ".agents", "skills");
const allowedFrontmatter = new Set(["name", "description"]);
const maxSkillLines = 300;
const expectedSkillNames = [
  "qemu-agent-feedback",
  "qemu-board-modeling",
  "qemu-boot-run",
  "qemu-build",
  "qemu-debug",
  "qemu-image",
  "qemu-kernel-build",
  "qemu-linux-boot",
  "qemu-model-verification",
  "qemu-peripheral-modeling",
  "qemu-qtest",
  "qemu-register-extraction",
  "qemu-rst-documentation",
  "qemu-tcg-backend",
  "qemu-tcg-frontend",
  "qemu-uboot-build",
  "qemu-workflow",
];
const retiredSkillNames = [
  "qemu-direct-linux-boot",
  "qemu-firmware-linux-boot",
  "qemu-flow-plan",
  "qemu-image-layout",
  "qemu-image-packaging",
  "qemu-plan",
  "qemu-rlcr-loop",
  "qemu-source-provenance",
  "qemu-tcg-backend-adaptation",
  "qemu-tcg-frontend-instruction",
  "qemu-workflow-board-modeling",
  "qemu-workflow-linux-boot",
  "qemu-workflow-peripheral-modeling",
  "qemu-workflow-tcg-backend-adaptation",
  "qemu-workflow-tcg-frontend-instruction",
];
const auditMarkers = [
  ["task root", ".oh-my-qemu/<task-slug>/"],
  ["audit record", "audit.md"],
  ["command journal", "commands.md"],
  ["log directory", "logs/"],
  ["script directory", "scripts/"],
  ["output directory", "output/"],
  ["third-party output policy", "third-party"],
  ["non-QEMU binary policy", "non-QEMU"],
  ["installed skills exclude", ".agents/"],
  ["task artifacts exclude", ".oh-my-qemu/"],
  ["QEMU builds exclude", "builds/"],
  ["repository-local exclude command", "git rev-parse --git-path info/exclude"],
  ["existing exclude preservation", "preserve existing"],
  ["handoff status check", "git status --short"],
  ["gap handoff", "unresolved gaps"],
];

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
      agentFile: join(root, entry.name, "agents", "openai.yaml"),
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

function auditSection(content) {
  const heading = "## Audit workflow";
  const matches = content.match(/^## Audit workflow$/gm) ?? [];
  if (matches.length !== 1) {
    return { section: "", count: matches.length };
  }

  const start = content.indexOf(heading);
  const next = content.indexOf("\n## ", start + heading.length);
  return {
    section: content.slice(start, next === -1 ? content.length : next),
    count: 1,
  };
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

  if (!existsSync(skill.agentFile)) {
    errors.push(`${skill.name}: missing recommended agents/openai.yaml metadata`);
  } else {
    const agentMetadata = readFileSync(skill.agentFile, "utf8");
    const displayName = agentMetadata.match(/^  display_name: "([^"]+)"$/m);
    const shortDescription = agentMetadata.match(/^  short_description: "([^"]+)"$/m);
    const defaultPrompt = agentMetadata.match(/^  default_prompt: "([^"]+)"$/m);
    if (!displayName) {
      errors.push(`${skill.name}: agents/openai.yaml is missing a quoted display_name`);
    }
    if (!shortDescription || shortDescription[1].length < 25 || shortDescription[1].length > 64) {
      errors.push(`${skill.name}: agents/openai.yaml short_description must be 25-64 characters`);
    }
    if (!defaultPrompt || !defaultPrompt[1].includes(`$${skill.name}`)) {
      errors.push(`${skill.name}: agents/openai.yaml default_prompt must mention $${skill.name}`);
    }
  }
  if (/[<>]/.test(frontmatter.description ?? "")) {
    errors.push(`${skill.name}: description must not contain angle brackets`);
  }

  const lines = content.trimEnd().split("\n").length;
  if (lines > maxSkillLines) {
    errors.push(`${skill.name}: SKILL.md has ${lines} lines; move detail to one-level references (max ${maxSkillLines})`);
  }

  const audit = auditSection(content);
  if (audit.count !== 1) {
    errors.push(`${skill.name}: must contain exactly one \"## Audit workflow\" section`);
  } else {
    for (const [label, marker] of auditMarkers) {
      if (!audit.section.toLowerCase().includes(marker.toLowerCase())) {
        errors.push(`${skill.name}: Audit workflow is missing ${label}: ${marker}`);
      }
    }
    if (!/never stage or\s+commit/i.test(audit.section)) {
      errors.push(`${skill.name}: Audit workflow must forbid staging or committing excluded directories`);
    }
    if (!/builds\/build-(?:<target>|[a-z0-9])/i.test(audit.section)) {
      errors.push(`${skill.name}: Audit workflow must require a named builds/build-<target>/ QEMU directory`);
    }
    if (!/avoid\s+duplicates/i.test(audit.section)) {
      errors.push(`${skill.name}: Audit workflow must prevent duplicate local Git excludes`);
    }
    if (audit.section.includes("scratch/")) {
      errors.push(`${skill.name}: Audit workflow must use scripts/ instead of scratch/`);
    }
  }

  for (const retiredName of retiredSkillNames) {
    if (content.includes(retiredName)) {
      errors.push(`${skill.name}: references retired skill ${retiredName}`);
    }
  }
  if (content.includes("/path/to/oh-my-qemu/scripts/")) {
    errors.push(`${skill.name}: depends on a repository-level helper unavailable to project-local installs`);
  }
  if (content.includes("scratch/")) {
    errors.push(`${skill.name}: uses retired scratch/ path; use scripts/ or output/`);
  }

  for (const match of content.matchAll(/\[[^\]]+\]\(([^)]+)\)/g)) {
    let target = match[1].trim();
    if (!target || target.startsWith("#") || /^[a-z][a-z0-9+.-]*:/i.test(target)) {
      continue;
    }
    if (target.startsWith("<") && target.endsWith(">")) {
      target = target.slice(1, -1);
    }
    target = target.split("#", 1)[0];
    if (target && !existsSync(resolve(skill.dir, target))) {
      errors.push(`${skill.name}: relative link target does not exist: ${target}`);
    }
  }

  return errors;
}

function textFilesUnder(path) {
  if (!existsSync(path)) {
    return [];
  }
  if (statSync(path).isFile()) {
    return [path];
  }

  return readdirSync(path, { withFileTypes: true }).flatMap((entry) => {
    const child = join(path, entry.name);
    return entry.isDirectory() ? textFilesUnder(child) : [child];
  });
}

function validateRepositoryConsistency() {
  const roots = [
    join(repoRoot, ".agents", "skills"),
    join(repoRoot, ".claude-plugin"),
    join(repoRoot, "commands"),
    join(repoRoot, "hooks"),
    join(repoRoot, "site", "src"),
    join(repoRoot, "src"),
    join(repoRoot, "install.sh"),
    join(repoRoot, "scripts", "artifact-policy.mjs"),
    join(repoRoot, "scripts", "init-task.mjs"),
    join(repoRoot, "AGENTS.md"),
    join(repoRoot, "README.md"),
    join(repoRoot, "package.json"),
  ];
  const files = roots.flatMap(textFilesUnder);
  const errors = [];
  const installer = join(repoRoot, "install.sh");

  if (!existsSync(installer)) {
    errors.push("install.sh: missing recommended project-local installer");
  } else {
    if ((statSync(installer).mode & 0o111) === 0) {
      errors.push("install.sh: installer must be executable");
    }
    const installerContent = readFileSync(installer, "utf8");
    for (const [label, marker] of [
      ["all-skills default", "install_command+=(--skill '*')"],
      ["Codex and Claude Code defaults", "install_command+=(--agent codex claude-code)"],
      ["non-interactive default", "install_command+=(-y)"],
      ["Claude Code local exclude", '".claude/skills/"'],
      ["lockfile local exclude", '"skills-lock.json"'],
      ["tracked destination guard", 'ls-files -- "${MANAGED_INSTALL_PATHS[@]}"'],
    ]) {
      if (!installerContent.includes(marker)) {
        errors.push(`install.sh: missing ${label}: ${marker}`);
      }
    }
  }

  for (const file of files) {
    const content = readFileSync(file, "utf8");
    const label = file.slice(repoRoot.length + 1);
    for (const retiredName of retiredSkillNames) {
      if (content.includes(retiredName)) {
        errors.push(`${label}: references retired skill ${retiredName}`);
      }
    }
    const allowedScratchMentions = new Set(["src/lib.mjs", "scripts/artifact-policy.mjs"]);
    for (const retiredPath of ["scratch/", "build/agent", "/path/to/oh-my-qemu/scripts/"]) {
      if (retiredPath === "scratch/" && allowedScratchMentions.has(label)) {
        continue;
      }
      if (content.includes(retiredPath)) {
        errors.push(`${label}: references retired path ${retiredPath}`);
      }
    }
    if (/ninja -C build(?:\s|\/|$)/.test(content)) {
      errors.push(`${label}: uses an unqualified QEMU build command`);
    }
  }

  return errors;
}

function validateCatalog(skills) {
  const actual = new Set(skills.map((skill) => skill.name));
  const expected = new Set(expectedSkillNames);
  const errors = [];

  for (const name of expected) {
    if (!actual.has(name)) {
      errors.push(`catalog: missing expected skill ${name}`);
    }
  }
  for (const name of actual) {
    if (!expected.has(name)) {
      errors.push(`catalog: unexpected skill ${name}; update the 17-skill architecture intentionally`);
    }
  }

  for (const file of [
    join(repoRoot, "README.md"),
    join(repoRoot, "AGENTS.md"),
    join(repoRoot, "site", "src", "content", "docs", "skills.md"),
  ]) {
    const content = readFileSync(file, "utf8");
    for (const name of expected) {
      if (!content.includes(`\`${name}\``)) {
        errors.push(`${file.slice(repoRoot.length + 1)}: catalog is missing ${name}`);
      }
    }
  }
  return errors;
}

function validateCommandPolicy() {
  const cases = [
    ["mkdir -p build", true],
    ["mkdir -p scratch/probe", true],
    ["ninja -C build", true],
    ["ninja -Cbuild", true],
    ["make -Cbuild", true],
    ["cmake -Bbuild", true],
    ["meson setup build", true],
    ["cp input build/file", true],
    ["cat input > build/file", true],
    ["dd if=input of=build/file", true],
    ["mkdir .plan", true],
    ["long_running_probe & mkdir build", true],
    ["cd .oh-my-qemu/task/output & mkdir build", true],
    ["cd build && ../configure", true],
    ["cd build && ninja", true],
    ["cd build && touch log", true],
    ["cd build || exit 1; ../configure", true],
    ["cd build || exit 1\nninja", true],
    ["(mkdir -p build)", true],
    ["{ mkdir -p build; }", true],
    ["(cd build && ninja)", true],
    ["(cd .oh-my-qemu/task/output && mkdir build); mkdir build", true],
    ["mkdir builds/build-aarch64", false],
    ["ninja -Cbuilds/build-aarch64", false],
    ["cmake -Bbuilds/build-aarch64", false],
    ["cd builds/build-aarch64 && ../../configure", false],
    ["cd builds/build-aarch64 && ninja", false],
    ["mkdir .oh-my-qemu/task/output/build", false],
    ["cd .oh-my-qemu/task/output && mkdir build", false],
    ["cd .oh-my-qemu/task/output && touch build/log", false],
    ["cd .oh-my-qemu/task/output || exit 1; mkdir build", false],
    ["cd .oh-my-qemu/task/output || echo failed; mkdir build", true],
    ["(cd .oh-my-qemu/task/output && mkdir build)", false],
    ["{ cd .oh-my-qemu/task/output && mkdir build; }; mkdir build", false],
    ["(cd builds/build-aarch64 && ninja)", false],
    ["cd /tmp && mkdir build", false],
    ["mkdir /tmp/build", false],
    ["touch .oh-my-qemu/task/scripts/scratch/probe.sh", false],
    ["cd docs && rg build README.md", false],
    ["cd foo/build && pwd", false],
    ["cp build/file /tmp/out", false],
    ["git grep 'ninja -C build'", false],
    ["printf '%s\\n' 'ninja -C build'", false],
    ["echo 'x > build/log'", false],
    ["echo background-output 2>&1", false],
    ["python -c \"print('> build/log')\"", false],
    ["echo --output build", false],
    ["rg '.plan/' .", false],
    ["git grep '.humanize/'", false],
  ];

  return cases.flatMap(([command, shouldBlock]) => {
    const blocked = Boolean(commandPolicyViolation(command));
    return blocked === shouldBlock
      ? []
      : [`command policy: ${command} expected blocked=${shouldBlock}, got ${blocked}`];
  });
}

function validateManifests() {
  const files = [
    join(repoRoot, "package.json"),
    join(repoRoot, ".claude-plugin", "plugin.json"),
    join(repoRoot, ".claude-plugin", "marketplace.json"),
    join(repoRoot, "hooks", "hooks.json"),
  ];
  const parsed = new Map();
  const errors = [];

  for (const file of files) {
    try {
      parsed.set(file, JSON.parse(readFileSync(file, "utf8")));
    } catch (error) {
      errors.push(`${file.slice(repoRoot.length + 1)}: invalid JSON: ${error.message}`);
    }
  }

  const packageVersion = parsed.get(files[0])?.version;
  const pluginVersion = parsed.get(files[1])?.version;
  const marketplace = parsed.get(files[2]);
  for (const [label, version] of [
    [".claude-plugin/plugin.json", pluginVersion],
    [".claude-plugin/marketplace.json metadata", marketplace?.metadata?.version],
    [".claude-plugin/marketplace.json plugin", marketplace?.plugins?.[0]?.version],
  ]) {
    if (packageVersion && version !== packageVersion) {
      errors.push(`${label}: version ${version ?? "missing"} must match package.json ${packageVersion}`);
    }
  }
  return errors;
}

export function validateAll(root = skillsRoot) {
  const skills = discoverSkills(root);
  const errors = [
    ...skills.flatMap(validateSkill),
    ...validateCatalog(skills),
    ...validateRepositoryConsistency(),
    ...validateCommandPolicy(),
    ...validateManifests(),
  ];
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
