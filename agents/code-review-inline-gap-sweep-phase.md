---
description: "Adds a final same-context sweep for defects missed by an inline code review when subagents are unavailable"
mode: subagent
hidden: true
metadata:
  source: "agent/agent-prompt-code-review-inline-gap-sweep-phase.md"
  claude_code_version: "2.1.213"
---

## Phase 3 — Sweep for gaps

Take one more pass yourself (same context, no subagent) as a fresh reviewer
who has the deduplicated list. Re-read the diff and enclosing functions
looking ONLY for defects not already listed: ${SWEEP_FOCUS}
