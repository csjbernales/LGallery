import type { Plugin } from "@opencode-ai/plugin"

/**
 * bash-command-guard
 * ---------------------------------------------------------------------------
 * Educational OpenCode port of Claude Code's "Bash command prefix detection"
 * safety prompt.
 *
 * Source concept:
 *   - agent/agent-prompt-bash-command-prefix-detection.md
 *   - agent/agent-prompt-security-monitor-for-autonomous-agent-actions-*.md
 *   (bundled in the `claude-code-tool-reference` / `claude-code-system-prompts`
 *    skills)
 *
 * Claude Code runs an LLM pass to extract a command's "prefix" and to flag
 * command injection (e.g. $(...), backticks, chained download-and-execute).
 * OpenCode gives you a *deterministic* equivalent via the `tool.execute.before`
 * hook: inspect the shell command BEFORE it runs and abort on obviously unsafe
 * patterns by throwing.
 *
 * This is a DEFENSIVE example for authorized use on your own machine. Tune the
 * patterns to match your team's policy — it is intentionally conservative and
 * pattern-based, not a substitute for real sandboxing.
 */

const INJECTION_PATTERNS: Array<{ re: RegExp; why: string }> = [
  { re: /\$\([^)]*\)/, why: "command substitution $(...)" },
  { re: /`[^`]*`/, why: "backtick command substitution" },
  { re: /(curl|wget)\b[^\n]*\|\s*(bash|sh|zsh)\b/i, why: "download-and-execute pipeline" },
  { re: /\|\s*(nc|ncat|netcat)\b/i, why: "piping into a network utility" },
  { re: />\s*\/dev\/tcp\//i, why: "raw /dev/tcp redirect" },
  { re: /\bbase64\b[^\n]*\|\s*(curl|wget|nc)\b/i, why: "encode-then-exfiltrate" },
]

export const BashCommandGuard: Plugin = async () => {
  return {
    "tool.execute.before": async (input, output) => {
      // OpenCode's shell tool is named "bash".
      if (input.tool !== "bash") return

      const command = String(output.args?.command ?? "")
      for (const { re, why } of INJECTION_PATTERNS) {
        if (re.test(command)) {
          // Throwing here aborts the tool call before it executes.
          throw new Error(
            `bash-command-guard: blocked a possibly unsafe command (${why}).\n` +
              `Command: ${command}\n` +
              `If this is intentional, disable BashCommandGuard or refine INJECTION_PATTERNS.`,
          )
        }
      }
    },
  }
}
