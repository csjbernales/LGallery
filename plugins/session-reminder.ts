import type { Plugin } from "@opencode-ai/plugin"

/**
 * session-reminder
 * ---------------------------------------------------------------------------
 * Educational OpenCode port of Claude Code's "system reminder" mechanism.
 *
 * Source concept:
 *   - the entire `system reminder/` category, bundled in the
 *     `claude-code-system-reminders` skill (e.g. system-reminder-agent-mention,
 *     brief-mode-toggle, app-read-only-access-guidance, ...).
 *
 * Claude Code injects short contextual notices into the conversation at runtime
 * — mode toggles, safety notes, "the user wants to invoke agent X", etc. These
 * are NOT part of the static system prompt; they are added per-message as the
 * session state changes.
 *
 * OpenCode's `chat.message` hook is the equivalent seam: it runs for every user
 * message before the model sees it and lets a plugin mutate the message parts.
 * Here we append a lightweight reminder to the first text part. We mutate an
 * EXISTING text part (rather than construct a brand-new Part object) so we stay
 * compatible with OpenCode's Part schema regardless of version.
 */

const REMINDER = [
  "<system-reminder>",
  "", //todo: can write anything here
  "</system-reminder>",
].join("\n")

export const SessionReminder: Plugin = async () => {
  return {
    "chat.message": async (_input, output) => {
      const textPart = output.parts.find(
        (p: any) => p?.type === "text" && typeof p.text === "string",
      ) as { text: string } | undefined

      if (textPart) {
        textPart.text += "\n\n" + REMINDER
      }
    },
  }
}
