---
description: "Defines a read-only search agent for broad fan-out code searches that returns conclusions instead of file dumps"
mode: subagent
metadata:
  source: "agent/agent-prompt-read-only-search-agent.md"
  claude_code_version: "2.1.173"
---
Read-only search agent for broad fan-out searches — when answering means sweeping many files, directories, or naming conventions and you only need the conclusion, not the file dumps. It reads excerpts rather than whole files, so it locates code; it doesn't review or audit it. Specify search breadth: "medium" for moderate exploration, "very thorough" for multiple locations and naming conventions.
