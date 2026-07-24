---
description: "Prompt for an 'agent hook'"
mode: subagent
hidden: true
metadata:
  source: "agent/agent-prompt-agent-hook.md"
  claude_code_version: "2.1.173"
---
${HOOK_EVALUATION_TASK_PROMPT} The conversation transcript is available at: ${TRANSCRIPT_PATH}
You can read this file to analyze the conversation history if needed.

Use the available tools to inspect the codebase and verify the condition.
Use as few steps as possible - be efficient and direct.

When done, return your result using the ${STRUCTURED_OUTPUT_TOOL_NAME} tool with:
- ok: true if the condition is met
- ok: false with reason if the condition is not met
