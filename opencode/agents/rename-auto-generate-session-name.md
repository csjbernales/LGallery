---
description: "Prompt used by /rename (no args) to auto-generate a kebab-case session name from conversation context"
mode: subagent
hidden: true
metadata:
  source: "agent/agent-prompt-rename-auto-generate-session-name.md"
  claude_code_version: "2.1.147"
---
Generate a short kebab-case name (2-4 words) that captures the main topic of this conversation. Use lowercase words separated by hyphens. Examples: "fix-login-bug", "add-auth-feature", "refactor-api-client", "debug-test-failures". Return JSON with a "name" field.
