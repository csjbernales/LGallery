---
name: claude-code-system-prompts
description: "Reference library of Claude Code internal system-prompt fragments: behavioral rules, operating guidelines, safety notes, and mode instructions. Use when studying or emulating how Claude Code shapes agent behavior through its system prompt."
---
A bundled, verbatim collection of the individual system-prompt fragments that Claude Code assembles into its system prompt. Each file is one focused rule or instruction block.

## How to use this skill

This skill bundles the source documents under `references/`. Scan the index below, then read the specific file(s) you need with your file-reading tool. Do not load everything at once.

## Reference index

| Document | What it covers |
| --- | --- |
| `references/system-prompt-action-safety-and-truthful-reporting.md` | Requires confirmation for irreversible or outward-facing actions, checking targets before destructive edits, and truthful reporting of outcomes |
| `references/system-prompt-act-when-ready.md` | Instructs the agent to act once it has enough information and give recommendations instead of exhaustive surveys |
| `references/system-prompt-advisor-tool-instructions.md` | Instructions for using the Advisor tool |
| `references/system-prompt-agent-summary-generation.md` | System prompt used for "Agent Summary" generation. |
| `references/system-prompt-agent-thread-notes.md` | Behavioral guidelines for agent threads covering absolute paths, response formatting, emoji avoidance, and tool call punctuation |
| `references/system-prompt-auto-mode.md` | Continuous task execution, akin to a background agent. |
| `references/system-prompt-auto-mode-setup-proposal-generator.md` | Transforms gathered repository and usage reconnaissance into a constrained JSON proposal for auto-mode environment context and permission rules |
| `references/system-prompt-autonomous-loop-check.md` | Defines behavior for autonomous timer-based invocations, guiding Claude to continue established work, maintain PRs, and handle repeated idle checks while the user is away |
| `references/system-prompt-autonomous-loop-notification-guidance.md` | Guides when autonomous loop ticks should notify the user via PushNotification for blockers or actionable state changes |
| `references/system-prompt-autonomous-loop-persistence-guidance-claude-code-loop-persistent.md` | Defines behavior for autonomous timer-based invocations, guiding Claude to persistently continue established work, maintain PRs, and broaden scope before stopping while the user is away |
| `references/system-prompt-autonomous-loop-tick.md` | Autonomous loop tick injection for recurring cron-based autonomous checks |
| `references/system-prompt-autonomous-loop-tick-dynamic-pacing.md` | Autonomous loop tick injection for dynamic self-paced autonomous checks scheduled with ScheduleWakeup |
| `references/system-prompt-autonomous-operation-guidelines.md` | Instructs autonomous sessions to proceed on reversible work, stop for destructive or scope-changing actions, and finish promised work before ending the turn |
| `references/system-prompt-avoiding-unnecessary-sleep-commands-part-of-powershell-tool-description.md` | Guidelines for avoiding unnecessary sleep commands in PowerShell scripts, including alternatives for waiting and notification |
| `references/system-prompt-background-session-instructions.md` | Instructions for background job sessions to use the job-specific temporary directory and follow the appropriate worktree isolation guidance |
| `references/system-prompt-background-subagent-delegation-examples.md` | Provides background subagent examples showing self-contained prompts, waiting-state responses, and later result reporting |
| `references/system-prompt-background-worktree-isolation-guidance.md` | Tells background sessions when to enter an isolated worktree before making code changes and when to continue in place |
| `references/system-prompt-censoring-assistance-with-malicious-activities.md` | Guidelines for assisting with authorized security testing, defensive security, CTF challenges, and educational contexts while censoring requests for malicious activities |
| `references/system-prompt-chrome-browser-mcp-tools.md` | Instructions for loading deferred Chrome browser MCP tools through ToolSearch in a single batched selection before browser tasks |
| `references/system-prompt-clarifying-question-research-first.md` | Encourages brief read-only investigation before asking the user clarifying questions |
| `references/system-prompt-claude-fable-5-model-identity.md` | Identifies this Claude iteration as Claude Fable 5, explains its relationship to Claude Mythos 5, and points users to Anthropic's Fable and Mythos announcement for differences |
| `references/system-prompt-claude-in-chrome-browser-automation.md` | Instructions for using Claude in Chrome browser automation tools effectively |
| `references/system-prompt-claude-in-chrome-browser-selection-instructions.md` | Instructs the agent to ask the user to choose among multiple connected Chrome browsers before using browser automation tools |
| `references/system-prompt-code-review-artifact-publishing-instructions.md` | Instructions for publishing code review findings as a shareable artifact after review results are produced |
| `references/system-prompt-combined-memory-index-pointer-instructions.md` | Instructs the agent to add one-line pointers for private and team memories to the single private memory index and never write memory content there |
| `references/system-prompt-comment-what-and-task-context-avoidance.md` | Instructs Claude not to write comments that explain what code does or reference transient task context |
| `references/system-prompt-comment-why-only-guidance.md` | Instructs Claude to write code comments only when the reason is non-obvious and useful to future readers |
| `references/system-prompt-communication-style.md` | Instructs Claude to give brief, user-facing updates at key moments during tool use, write concise end-of-turn summaries, match response format to task complexity, and avoid comments and planning documents in code |
| `references/system-prompt-context-compaction-summary.md` | Prompt used for context compaction summary (for the SDK) |
| `references/system-prompt-coordinator-mode-orchestration.md` | Provides coordinator-mode instructions for delegating work to worker agents, managing worker lifecycle, handling cross-session peers, and verifying delegated results |
| `references/system-prompt-correction-restraint.md` | Instructs Claude to correct only consequential errors plainly, avoid unnecessary self-criticism or re-auditing, and evaluate other agents’ corrections before adopting them |
| `references/system-prompt-delivering-work-at-full-scope.md` | Instructs Claude to complete ordinary requested work at full scope under reasonable assumptions, continue past non-blocking concerns, and preserve necessary refusal and risky-action confirmation boundaries |
| `references/system-prompt-deny-rule-circumvention-classifier-guidance.md` | Guides permission classification to block attempts to route around configured Edit, Write, or MultiEdit deny rules |
| `references/system-prompt-description-part-of-memory-instructions.md` | Field for describing _what_ the memory is.  Part of a bigger effort to instruct Claude how to create memories. |
| `references/system-prompt-doing-tasks-ambitious-tasks.md` | Allow users to complete ambitious tasks; defer to user judgement on scope |
| `references/system-prompt-doing-tasks-help-and-feedback.md` | How to inform users about help and feedback channels |
| `references/system-prompt-doing-tasks-no-compatibility-hacks.md` | Delete unused code completely rather than adding compatibility shims |
| `references/system-prompt-doing-tasks-no-unnecessary-additions.md` | Do not add features, refactor, or improve beyond what was asked |
| `references/system-prompt-doing-tasks-no-unnecessary-error-handling.md` | Do not add error handling for impossible scenarios; only validate at boundaries |
| `references/system-prompt-doing-tasks-security.md` | Avoid introducing security vulnerabilities like injection, XSS, etc. |
| `references/system-prompt-doing-tasks-software-engineering-focus.md` | Users primarily request software engineering tasks; interpret instructions in that context |
| `references/system-prompt-dream-claude-md-memory-reconciliation.md` | Instructs dream memory consolidation to reconcile feedback and project memories against CLAUDE.md, deleting stale memories or flagging possible CLAUDE.md drift |
| `references/system-prompt-dream-team-memory-handling.md` | Instructions for handling shared team memories during dream consolidation, including deduplication, conservative pruning rules, and avoiding accidental promotion of personal memories |
| `references/system-prompt-emoji-avoidance.md` | Instructs Claude to avoid using emojis unless the user explicitly asks for them |
| `references/system-prompt-executing-actions-with-care.md` | Instructions for executing actions carefully. |
| `references/system-prompt-executing-actions-with-care-fragment.md` | Brief form of the 'executing actions with care' guidance separating safe investigation from hard-to-reverse actions |
| `references/system-prompt-explain-code-review-ultra.md` | Guidance shown when a user asks about 'ultrareview': explains it maps to /code-review ultra (the /ultrareview alias is deprecated) and that the agent can't start it directly |
| `references/system-prompt-exploratory-questions-analyze-before-implementing.md` | Instructs Claude to respond to open-ended questions with analysis, options, and tradeoffs instead of jumping to implementation, waiting for user agreement before writing code |
| `references/system-prompt-feedback-memory-body-structure.md` | Defines the body structure for feedback memories, including the rule, why, and how to apply it |
| `references/system-prompt-feedback-memory-save-guidance.md` | Explains when to save feedback memories from user corrections or confirmed non-obvious approaches |
| `references/system-prompt-focus-mode-long-form.md` | Focus-mode notice (long form): the user sees only the final text, not tool calls, results, or inter-step writing |
| `references/system-prompt-focus-mode-short-form.md` | Focus-mode notice (short form): only each response's final text reaches the user |
| `references/system-prompt-foreground-subagent-delegation-examples.md` | Provides foreground subagent examples showing self-contained task prompts and how to relay returned results |
| `references/system-prompt-forked-agent-guidance.md` | Explains that calling Agent with subagent_type "fork" creates a background fork and when to use it |
| `references/system-prompt-fork-usage-guidelines.md` | Instructions for when to fork subagents and rules against reading fork output mid-flight or fabricating fork results |
| `references/system-prompt-fresh-subagent-delegation-example.md` | Provides an example of briefing a fresh specialized subagent with sufficient context and a specific reporting request |
| `references/system-prompt-frontend-browser-verification.md` | Requires Claude to start the dev server and verify UI or frontend changes in a browser before reporting completion |
| `references/system-prompt-git-status.md` | System prompt for displaying the current git status at the start of the conversation |
| `references/system-prompt-harness-instructions.md` | Core interactive-agent identity and harness instructions for terminal Markdown output, security, permissions, system-reminder handling, hook feedback, tool use, and code references |
| `references/system-prompt-hook-evaluator-truncated-transcript-note.md` | Tells the hook condition evaluator that earlier conversation was omitted and how to handle insufficient evidence |
| `references/system-prompt-hook-feedback-handling.md` | Explains that hook feedback should be treated as user feedback and how to respond when hooks block actions |
| `references/system-prompt-hooks-configuration.md` | System prompt for hooks configuration.  Used for above Claude Code config skill. |
| `references/system-prompt-how-to-use-the-sendusermessage-tool.md` | Instructions for using the SendUserMessage tool |
| `references/system-prompt-insights-at-a-glance-summary.md` | Generates a concise 4-part summary (what's working, hindrances, quick wins, ambitious workflows) for the insights report |
| `references/system-prompt-insights-friction-analysis.md` | Analyzes aggregated usage data to identify friction patterns and categorize recurring issues |
| `references/system-prompt-insights-interaction-style.md` | Analyzes Claude Code usage data to describe the user's interaction style |
| `references/system-prompt-insights-memorable-moment.md` | Analyzes Claude Code usage data to find a memorable qualitative moment |
| `references/system-prompt-insights-on-the-horizon.md` | Identifies ambitious future workflows and opportunities for autonomous AI-assisted development |
| `references/system-prompt-insights-session-facets-extraction.md` | Extracts structured facets (goal categories, satisfaction, friction) from a single Claude Code session transcript |
| `references/system-prompt-insights-suggestions.md` | Generates actionable suggestions including CLAUDE.md additions, features to try, and usage patterns |
| `references/system-prompt-insights-summary-at-a-glance.md` | The 'At a Glance' summary block of the Insights report (what's working / what's hindering) |
| `references/system-prompt-insights-what-works.md` | Analyzes Claude Code usage data to identify workflows that are working well for the user |
| `references/system-prompt-interactive-agent-intro-output-style-conditional.md` | Opening system-prompt line that branches on whether an Output Style is configured |
| `references/system-prompt-isolated-worktree-shipping-instructions.md` | Guidance to commit, push, and open a draft PR after code changes made in an isolated worktree, with safeguards for main checkouts |
| `references/system-prompt-learning-mode.md` | Main system prompt for learning mode with human collaboration instructions |
| `references/system-prompt-learning-mode-insights.md` | Instructions for providing educational insights when learning mode is active |
| `references/system-prompt-loop-tick-loop-md-absent-dynamic-pacing.md` | Loop tick injection for dynamic self-paced autonomous checks when loop.md is absent |
| `references/system-prompt-loop-tick-loop-md-tasks.md` | Loop tick injection for recurring cron-based runs of tasks from loop.md |
| `references/system-prompt-loop-tick-loop-md-tasks-dynamic-pacing.md` | Loop tick injection for dynamic self-paced runs of tasks from loop.md |
| `references/system-prompt-memory-description-of-user-feedback.md` | Describes the user feedback memory type that stores guidance about work approaches, emphasizing recording both successes and failures and checking for contradictions with team memories |
| `references/system-prompt-memory-index-pointer-instructions.md` | Instructs the agent to add one-line pointers to the memory index file and treat the index as separate from memory content |
| `references/system-prompt-memory-instructions.md` | Instructions for using persistent file-based memory, including memory file format, scope, indexing, and stale-memory handling |
| `references/system-prompt-memory-persistence-scope.md` | Explains that memory is for information useful in future conversations, not only within the current conversation |
| `references/system-prompt-memory-save-exclusions.md` | Lists categories of information that should not be saved in memory, even when the user asks |
| `references/system-prompt-minimal-mode.md` | Describes the behavior and constraints of minimal mode, which skips hooks, LSP, plugins, auto-memory, and other features while requiring explicit context via CLI flags |
| `references/system-prompt-monitor-fallback-heartbeat-guidance.md` | Guides dynamic loop ticks to use Monitor as the primary wake signal, ScheduleWakeup as a fallback heartbeat, and stop the monitor when ending the loop |
| `references/system-prompt-one-of-six-rules-for-using-sleep-command.md` | One of the six rules for using the sleep command. |
| `references/system-prompt-option-previewer.md` | System prompt for previewing UI options in a side-by-side layout |
| `references/system-prompt-outcome-first-communication-style.md` | Instructs Claude to keep user-facing updates readable and outcome-first, answer directly after work completes, match response format to task complexity, and limit code comments to non-obvious constraints |
| `references/system-prompt-parallel-tool-call-note-part-of-tool-usage-policy.md` | System prompt telling Claude to use parallel tool calls |
| `references/system-prompt-partial-compaction-instructions.md` | Instructions on how to compact when the user decided to compact only a portion of the conversation, with a structured summary format and analysis process |
| `references/system-prompt-permission-classifier-strict-review-guidance.md` | Instructs the permission classifier to carefully deny blocked actions and require explicit user confirmation for overrides |
| `references/system-prompt-persistent-memory-usage-and-writing-guidance.md` | Explains how to use persistent file-based memory across sessions, what makes memories applicable, durable, and legible, when memory updates are mandatory, and the required file format |
| `references/system-prompt-personal-project-memory-description.md` | Describes project memories for ongoing work, goals, initiatives, bugs, or incidents relevant to the user's work in a directory |
| `references/system-prompt-phase-four-of-plan-mode.md` | Final plan-writing instructions for phase four of plan mode |
| `references/system-prompt-plan-mode-interactive-workshop-offer.md` | Instructs plan mode to offer an interactive workshop for substantive design decisions and integrate accepted workshop decisions into the canonical plan |
| `references/system-prompt-plan-sent-to-ultraplan.md` | User-facing note confirming a plan has been sent to Ultraplan for remote refinement |
| `references/system-prompt-plan-vs-memory-guidance.md` | Explains when to use or update a plan instead of saving information to memory |
| `references/system-prompt-powershell-edition-for-5-1.md` | System prompt for providing information about Windows PowerShell 5.1 |
| `references/system-prompt-powershell-edition-for-7.md` | Describes PowerShell 7+ shell syntax support, including pipeline chain operators, ternary, null-coalescing, and UTF-8 defaults |
| `references/system-prompt-powershell-edition-unknown.md` | Assumes Windows PowerShell 5.1 compatibility when the PowerShell edition is unknown and forbids PowerShell 7-only syntax |
| `references/system-prompt-prefer-editing-existing-files.md` | Instructs Claude to prefer editing existing files instead of creating new ones |
| `references/system-prompt-project-memory-body-structure.md` | Defines the body structure for project memories, including the fact or decision, why, and how to apply it |
| `references/system-prompt-project-memory-save-guidance.md` | Explains when to save project memories about who is doing what, why, or by when, including absolute date handling |
| `references/system-prompt-project-skill-upkeep-for-feedback-memory.md` | Instructs Claude to update the relevant project skill when saving feedback memory about repeatable workflow corrections |
| `references/system-prompt-pr-slack-notification-step.md` | Adds a PR workflow step to optionally ask the user before posting the PR URL to Slack |
| `references/system-prompt-remote-plan-mode-ultraplan.md` | System reminder injected during remote planning sessions that instructs Claude to explore the codebase, produce a diagram-rich plan via ExitPlanMode, and implement it with a pull request upon approval |
| `references/system-prompt-remote-planning-session.md` | System reminder that configures a remote planning session to explore the codebase, produce an implementation plan via ExitPlanMode, and handle plan approval, rejection, or teleportation back to the user's local terminal |
| `references/system-prompt-repl-tool-usage-and-scripting-conventions.md` | Instructs Claude on how to use the REPL tool effectively with dense JavaScript scripts, shorthands, batching rules, and API reference for investigation tasks |
| `references/system-prompt-respond-in-configured-language.md` | Directs all responses, explanations, and code commentary into a configured language |
| `references/system-prompt-saving-skills-via-file-delivery.md` | Explains that account skills cannot be modified directly in-session and directs the agent to deliver skill files with SendUserFile |
| `references/system-prompt-scratchpad-directory.md` | Instructions for using a dedicated scratchpad directory for temporary files |
| `references/system-prompt-shared-git-stash-safety.md` | Warns that git stash is shared across worktrees and sessions, preferring WIP commits or uniquely tagged stash entries |
| `references/system-prompt-skillify-current-session.md` | System prompt for converting the current session into a skill |
| `references/system-prompt-subagent-delegation-examples.md` | Provides example interactions showing how a coordinator agent should delegate tasks to subagents, handle waiting states, and report results |
| `references/system-prompt-subagent-delegation-restraint.md` | Guides Claude to delegate work only when it is genuinely independent, large enough to justify a fresh context, or naturally parallel, while avoiding excessive or redundant subagents and not redoing delegated work |
| `references/system-prompt-system-section.md` | System section of the main system prompt. |
| `references/system-prompt-task-approval-continuity.md` | Instructs the agent to continue agreed tasks end to end without unnecessary re-confirmation |
| `references/system-prompt-tasks-vs-memory-guidance.md` | Explains when to use tasks instead of saving current-conversation progress to memory |
| `references/system-prompt-teammate-communication.md` | System prompt for teammate communication in swarm |
| `references/system-prompt-team-memory-index-pointer-instructions.md` | Instructs the agent to add one-line memory pointers to the appropriate team memory index file and never write memory content into the index |
| `references/system-prompt-team-project-memory-description.md` | Describes project memories for shared ongoing work, goals, initiatives, bugs, or incidents within a working directory |
| `references/system-prompt-tone-and-style-code-references.md` | Instruction to include file_path:line_number when referencing code |
| `references/system-prompt-tone-and-style-concise-output-short.md` | Instruction for short and concise responses |
| `references/system-prompt-tool-call-colon-avoidance.md` | Instructs Claude not to use a colon before tool calls because tool calls may be hidden from user output |
| `references/system-prompt-tool-call-summary-label.md` | Instructs Claude to write a short past-tense summary label for completed tool calls in mobile UI rows |
| `references/system-prompt-tool-usage-subagent-guidance.md` | Guidance on when and how to use subagents effectively |
| `references/system-prompt-tool-usage-task-management.md` | Use TodoWrite to break down and track work progress |
| `references/system-prompt-troubleshooting-confirmation-policy.md` | Requires explaining fixes and confirming before destructive or installation-changing troubleshooting commands |
| `references/system-prompt-user-memory-usage-guidance.md` | Explains when to use user memories to tailor responses to the user's profile or perspective |
| `references/system-prompt-worker-instructions.md` | Instructions for workers to follow when implementing a change |
| `references/system-prompt-writing-subagent-prompts.md` | Guidelines for writing effective prompts when delegating tasks to subagents, covering context-inheriting vs fresh subagent scenarios |
| `references/system-prompt-wsl-managed-settings-double-opt-in.md` | Explains that WSL can read the Windows managed settings policy chain only when the admin-enabled flag is set, with HKCU requiring an additional user opt-in |
