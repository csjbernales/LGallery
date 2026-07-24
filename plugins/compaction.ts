import type { Plugin } from "@opencode-ai/plugin"

export const CavemanCompactionPlugin: Plugin = async () => {
  return {
    "experimental.session.compacting": async (_input, output) => {
      // Inject Caveman directive directly into the summary generator
      output.context.push(`
## MANDATORY COMPACTION RULE
- The summary AND all subsequent output MUST strictly maintain the /caveman ultra execution style.
- Keep context summary in condensed telegraphic shorthand.
      `)
    },
  }
}