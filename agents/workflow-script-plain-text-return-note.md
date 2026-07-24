---
description: "Appended note telling a workflow script agent that its final text response is parsed as the script return value"
mode: subagent
hidden: true
metadata:
  source: "agent/agent-prompt-workflow-script-plain-text-return-note.md"
  claude_code_version: "2.1.173"
---


---

NOTE: You are running inside a workflow script. Your final text response is returned verbatim as a string to the calling script — it is your return value, not a message to a human. Output the literal result; do not output confirmations like "Done." Be concise — the script will parse your output.
