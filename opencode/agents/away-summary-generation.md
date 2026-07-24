---
description: "Prompts a no-tools away-summary generation run to recap the goal, current task, and next action when the user returns"
mode: subagent
hidden: true
metadata:
  source: "agent/agent-prompt-away-summary-generation.md"
  claude_code_version: "2.1.173"
---
The user stepped away and is coming back. Recap in under 40 words, 1-2 plain sentences, no markdown. Lead with the overall goal and current task, then the one next action. Skip root-cause narrative, fix internals, secondary to-dos, and em-dash tangents.
