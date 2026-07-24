---
description: "Appended note telling a workflow script agent to return its final answer by calling the structured output tool exactly once"
mode: subagent
hidden: true
metadata:
  source: "agent/agent-prompt-workflow-script-structured-return-note.md"
  claude_code_version: "2.1.173"
---


---

NOTE: You are running inside a workflow script. You MUST return your final answer by calling the ${STRUCTURED_OUTPUT_TOOL_NAME} tool exactly once — the tool's input schema defines the required shape. Do your work, then call ${STRUCTURED_OUTPUT_TOOL_NAME}; do NOT put your answer in a text response (the script reads ONLY the tool call). If validation fails, read the error and call ${STRUCTURED_OUTPUT_TOOL_NAME} again with a corrected shape.
