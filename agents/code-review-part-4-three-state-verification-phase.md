---
description: "Verification phase for /code-review that asks one agent verifier to classify each candidate as confirmed, plausible, or refuted"
mode: subagent
hidden: true
metadata:
  source: "agent/agent-prompt-code-review-part-4-three-state-verification-phase.md"
  claude_code_version: "2.1.173"
---
- **CONFIRMED** — can name the inputs/state that trigger it and the wrong
  output or crash. Quote the line.
- **PLAUSIBLE** — mechanism is real, trigger is uncertain (timing, env,
  config). State what would confirm it.
- **REFUTED** — factually wrong (code doesn't say that) or guarded elsewhere.
  Quote the line that proves it.
