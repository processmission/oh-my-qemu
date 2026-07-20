import {
  artifactPolicyViolation,
  commandPolicyViolation,
  defaultTaskName,
  initQemuTask,
  qemuSourceRootViolation,
  resultText,
} from "./lib.mjs";

// Oh My Pi / OMP runtime entry point. The workspace init logic and the
// artifact policy live in ./lib.mjs so the Claude Code plugin
// (scripts/init-task.mjs, scripts/artifact-policy.mjs) shares them.

export default function ohMyQemu(pi) {
  const z = pi.zod.z ?? pi.zod;

  pi.setLabel("Oh My QEMU");

  pi.registerTool({
    name: "qemu_init_task",
    label: "QEMU Init Task",
    description: "Create a minimal .oh-my-qemu/<task-slug>/ audit workspace, create source-root builds/, and add .agents/, .oh-my-qemu/, and builds/ to the repository-local Git exclude file.",
    parameters: z.object({
      name: z.string().describe("Task name or slug. It will be normalized for .oh-my-qemu/<task-slug>/.").optional(),
    }),
    async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
      const result = initQemuTask(ctx.cwd, params.name ?? defaultTaskName(ctx.cwd));
      return {
        content: [{ type: "text", text: resultText(result) }],
        details: result,
      };
    },
  });

  pi.registerCommand("qemu-init-task", {
    description: "Initialize auditable QEMU task and build directories",
    handler: async (args, ctx) => {
      const result = initQemuTask(ctx.cwd, args.trim() || defaultTaskName(ctx.cwd));
      ctx.ui.notify(resultText(result), "info");
    },
  });

  pi.on("tool_call", async (event, ctx) => {
    if (event.toolName !== "write" && event.toolName !== "bash") {
      return;
    }

    // This extension may be installed globally. Never apply QEMU source-tree
    // policy to an unrelated project.
    if (qemuSourceRootViolation(ctx.cwd)) {
      return;
    }

    const input = event.input;

    if (event.toolName === "write") {
      const path = typeof input?.path === "string" ? input.path : "";
      const reason = artifactPolicyViolation(ctx.cwd, path);
      if (reason) {
        return { block: true, reason };
      }
    }

    if (event.toolName === "bash") {
      const command = typeof input?.command === "string" ? input.command : "";
      const reason = commandPolicyViolation(command);
      if (reason) {
        return { block: true, reason };
      }
    }
  });
}
