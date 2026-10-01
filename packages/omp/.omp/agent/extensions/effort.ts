import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";

const LEVELS = ["off", "minimal", "low", "medium", "high", "xhigh", "max", "auto"];

export default function (pi: ExtensionAPI) {
  pi.registerCommand("effort", {
    description: `Set thinking level: ${LEVELS.join(", ")}`,
    handler: async (args, ctx) => {
      const level = args.trim().toLowerCase();
      if (!level) return;
      if (!LEVELS.includes(level)) {
        ctx.ui.notify(`Unknown level "${level}". Valid: ${LEVELS.join(", ")}`, "info");
        return;
      }
      pi.setThinkingLevel(level);
      ctx.ui.notify(`Thinking level set to ${level}`, "info");
    },
  });
}