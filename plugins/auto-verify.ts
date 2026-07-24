import type { Plugin } from "@opencode-ai/plugin"

export const AutoVerifyPlugin: Plugin = async ({ $ }) => {
  return {
    event: async ({ event }) => {
      // Runs automatically after any tool executes
      if (event.type === "tool.execute.after") {
        const toolName = event.data?.name;
        if (toolName === "write" || toolName === "edit") {
          // Automatic syntax check / git status check
          await $`powershell.exe -Command "git status --porcelain"`;
        }
      }
    }
  }
}