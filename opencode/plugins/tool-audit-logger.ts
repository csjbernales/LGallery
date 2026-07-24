import type { Plugin } from "@opencode-ai/plugin"

/**
 * tool-audit-logger
 * ---------------------------------------------------------------------------
 * Educational OpenCode port of Claude Code's hook / observability concept.
 *
 * Source concept:
 *   - agent/agent-prompt-agent-hook.md
 *   - agent/agent-prompt-hook-condition-evaluator*.md
 *   - data/data-directoryadded-hook-description.md
 *   (bundled in `claude-code-internals-data` / `claude-code-system-prompts`)
 *
 * Claude Code fires hooks around tool use and session lifecycle events and can
 * run an evaluator against the transcript. OpenCode exposes the same surface
 * through two plugin hooks:
 *   - `tool.execute.after` — fires after every individual tool call
 *   - `event`              — fires for session/bus events (session.idle, etc.)
 *
 * This plugin writes a one-line JSON audit record for every tool call to
 * `.opencode/tool-audit.log`, and a marker when the session goes idle. Logging
 * failures are swallowed so the audit never blocks real work.
 */

export const ToolAuditLogger: Plugin = async ({ $, directory }) => {
  const logfile = `${directory}/.opencode/tool-audit.log`

  const append = async (text: string) => {
    try {
      // `$` is Bun's shell API. Values interpolated with $ are escaped for us.
      await $`printf '%s\n' ${text} >> ${logfile}`
    } catch {
      // Never let the audit log break a tool call or event.
    }
  }

  return {
    "tool.execute.after": async (input, output) => {
      await append(
        JSON.stringify({
          at: "tool.execute.after",
          tool: input.tool,
          sessionID: input.sessionID,
          callID: input.callID,
          title: output.title,
        }),
      )
    },

    event: async ({ event }) => {
      if ((event as any)?.type === "session.idle") {
        await append(JSON.stringify({ at: "event", type: "session.idle" }))
      }
    },
  }
}
