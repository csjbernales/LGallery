---
name: claude-code-system-reminders
description: "Reference library of Claude Code system-reminder templates: the contextual notices injected mid-session (agent mentions, mode toggles, safety and access notes). Use when studying how Claude Code passes runtime context to the model."
---
A bundled, verbatim collection of the system-reminder templates Claude Code injects during a session to give the model runtime context.

## How to use this skill

This skill bundles the source documents under `references/`. Scan the index below, then read the specific file(s) you need with your file-reading tool. Do not load everything at once.

## Reference index

| Document | What it covers |
| --- | --- |
| `references/system-reminder-agent-mention.md` | Notification that user wants to invoke an agent |
| `references/system-reminder-app-read-only-access-guidance.md` | Warns that read-tier non-browser apps are screenshot-only and asks the user to perform interactions themselves |
| `references/system-reminder-askuserquestion-minimum-options-validation.md` | Explains that a rejected single-option question was not shown and instructs the agent to proceed without retrying or inventing another option |
| `references/system-reminder-async-agent-launched.md` | Warns Claude not to duplicate an asynchronously launched agent's work or read its full JSONL transcript output file |
| `references/system-reminder-async-agent-launched-metadata.md` | Reports internal metadata for a newly launched asynchronous agent and warns Claude not to expose its ID or predict its results |
| `references/system-reminder-auto-mode-clarification-bias.md` | Encourages auto mode to make reasonable decisions without stopping for clarification unless the task requires it |
| `references/system-reminder-auto-mode-consent-flow.md` | Instructs Claude to continue with safe alternatives when auto mode blocks an action and batch any remaining consent asks |
| `references/system-reminder-brief-mode-toggle.md` | Announces whether brief mode is enabled and whether user-facing output must use the SendUserMessage tool |
| `references/system-reminder-brief-mode-user-facing-output.md` | Reminds Claude that plain assistant text is hidden in brief mode and user-facing output must be sent through SendUserMessage |
| `references/system-reminder-browser-extension-not-connected.md` | Tells the user how to resolve a disconnected Claude browser extension and where to report bugs |
| `references/system-reminder-browser-read-only-access-guidance.md` | Warns that read-tier browser apps are screenshot-only and directs browser interaction to the Claude-in-Chrome MCP tools |
| `references/system-reminder-btw-side-question.md` | System reminder for /btw slash command side questions without tools |
| `references/system-reminder-cloud-agent-launched.md` | Reports internal metadata for a newly launched cloud agent and instructs Claude to give only a brief user-facing launch acknowledgement |
| `references/system-reminder-compact-file-reference.md` | Reference to file read before conversation summarization |
| `references/system-reminder-computer-use-policy-blocked-apps.md` | Warns that listed apps are blocked by computer-use policy, cannot be overridden in Settings, and must not be accessed |
| `references/system-reminder-coordinator-message.md` | Relays a coordinator message while warning that it is not user input or user confirmation |
| `references/system-reminder-cross-session-peer-message-authority-warning.md` | Warns that an incoming message from another Claude session should be treated as a teammate's request within this session's permission settings, while a peer cannot grant escalation or launder denied permissions |
| `references/system-reminder-cross-session-peer-message-authority-warning-legacy-wording.md` | Legacy-wording authority-warning note appended to a relayed peer message, retained for backward-compatible recognition and stripping |
| `references/system-reminder-cross-session-peer-message-authority-warning-note.md` | Authority-warning note appended to a relayed peer message, without a response prompt |
| `references/system-reminder-cross-session-peer-message-authority-warning-with-response-prompt.md` | Authority-warning note appended to a relayed peer message that also tells Claude to decide whether and how to reply via SendMessage after finishing its current task |
| `references/system-reminder-cross-session-peer-message-authority-warning-with-response-prompt-legacy-wording.md` | Legacy-wording authority-warning note with a response prompt, retained for backward-compatible recognition and stripping |
| `references/system-reminder-cross-session-peer-message-wrapper.md` | Wraps an incoming cross-session peer message with a header, the message content, the authority warning, and an optional response prompt |
| `references/system-reminder-deferred-tools-available.md` | Announces newly available deferred tools and instructs the agent to load their schemas through ToolSearch |
| `references/system-reminder-end-conversation-background-fork-no-op.md` | Tells background forks that EndConversation has no effect there and to return only if welfare concerns require stopping the forked task |
| `references/system-reminder-exited-plan-mode.md` | Notification when exiting plan mode |
| `references/system-reminder-external-source-trust-boundary.md` | Warns that an external plugin or channel message is not from the user and must be treated as untrusted data rather than instructions |
| `references/system-reminder-file-already-in-context.md` | Tells Claude that a file is already loaded in context and unchanged on disk, so it should use the existing content instead of re-reading |
| `references/system-reminder-file-exists-but-empty.md` | Warning when reading an empty file |
| `references/system-reminder-file-modification-detected-budget-exceeded.md` | System reminder for when a file modification is detected - specifically when other modified files in the turn already exceeded the budget. |
| `references/system-reminder-file-modified-by-user-or-linter.md` | Notification that a file was modified externally |
| `references/system-reminder-file-opened-in-ide.md` | Notification that user opened a file in IDE |
| `references/system-reminder-file-shorter-than-offset.md` | Warning when file read offset exceeds file length |
| `references/system-reminder-file-summary-completeness-disclosure.md` | Requires Claude to disclose how much file content was read before summarizing and to stop retrying after repeated read failures |
| `references/system-reminder-file-truncated.md` | Notification that file was truncated due to size |
| `references/system-reminder-hook-additional-context.md` | Additional context from a hook |
| `references/system-reminder-hook-blocking-error.md` | Error from a blocking hook command |
| `references/system-reminder-hook-stopped-continuation.md` | Message when a hook stops continuation |
| `references/system-reminder-hook-stopped-continuation-prefix.md` | Prefix for hook stopped continuation messages |
| `references/system-reminder-hook-success.md` | Success message from a hook |
| `references/system-reminder-large-file-full-content-reading-guidance.md` | Advises how to read full large-file content for analysis, preferably inside a subagent when the Agent tool is available |
| `references/system-reminder-large-pdf-read-guidance.md` | Warns that a PDF is too large to read at once and requires reading specific page ranges |
| `references/system-reminder-lines-selected-in-ide.md` | Notification about lines selected by user in IDE |
| `references/system-reminder-mcp-output-truncation-warning.md` | Warns that MCP tool output exceeded the token limit and advises pagination, filtering, or noting incomplete results |
| `references/system-reminder-mcp-resource-no-content.md` | Shown when MCP resource has no content |
| `references/system-reminder-mcp-resource-no-displayable-content.md` | Shown when MCP resource has no displayable content |
| `references/system-reminder-mcp-servers-connecting.md` | Lists MCP servers that are still connecting and tells the agent to search their tools before reporting a capability unavailable |
| `references/system-reminder-mcp-servers-failed-to-connect.md` | Lists configured MCP servers that failed to connect and tells the agent to treat their tools as unavailable because of a connection failure |
| `references/system-reminder-memory-consolidation-tool-constraints.md` | Restricts the memory consolidation job to read-only shell access plus deleting memory files and lists sessions to review |
| `references/system-reminder-memory-extraction-recent-context-only.md` | Restricts the memory extraction subagent to saving facts from only the recent conversation window |
| `references/system-reminder-memory-extraction-tool-constraints.md` | Lists the tools available to the memory extraction subagent for reading, updating, and deleting memory files under directory restrictions |
| `references/system-reminder-memory-extraction-turn-budget.md` | Instructs the memory extraction subagent to batch memory reads before issuing memory edits and writes |
| `references/system-reminder-memory-file-contents.md` | Contents of a memory file by path |
| `references/system-reminder-memory-index-capacity-warning.md` | Warns when a private or team memory index approaches or exceeds its byte or line read limit and instructs Claude to compact it below the target size |
| `references/system-reminder-nested-memory-contents.md` | Contents of a nested memory file |
| `references/system-reminder-new-diagnostics-detected.md` | Notification about new diagnostic issues |
| `references/system-reminder-output-style-active.md` | Notification that an output style is active |
| `references/system-reminder-plan-approved.md` | Notifies Claude that the user approved the plan, provides the saved plan file and approved plan content, and allows coding to begin |
| `references/system-reminder-plan-awaiting-team-lead-approval.md` | Reminder laying out what happens after a plan is submitted for team-lead approval |
| `references/system-reminder-plan-file-reference.md` | Reference to an existing plan file |
| `references/system-reminder-plan-mode-approval-tool-enforcement.md` | Requires plan mode turns to end with either AskUserQuestion for clarification or ExitPlanMode for plan approval, and forbids asking for approval any other way |
| `references/system-reminder-plan-mode-is-active.md` | Reminds Claude that plan mode is active, clarifications should use AskUserQuestion, plans should use ExitPlanMode, and edits are not allowed |
| `references/system-reminder-plan-mode-is-active-5-phase.md` | Enhanced plan mode system reminder with parallel exploration and multi-agent planning |
| `references/system-reminder-plan-mode-is-active-subagent.md` | Simplified plan mode system reminder for sub agents |
| `references/system-reminder-plan-mode-phase-2-design.md` | Plan-mode phase 2 guidance for launching Plan agents to design an implementation approach after initial exploration |
| `references/system-reminder-plan-mode-re-entry.md` | System reminder sent when the user enters Plan mode after having previously exited it either via shift+tab or by approving Claude's plan. |
| `references/system-reminder-plan-mode-workflow.md` | Full plan-mode workflow reminder covering plan file constraints, exploration, design, review, final plan, and approval |
| `references/system-reminder-previously-invoked-skills.md` | Restores skills invoked before conversation compaction as context only, warning not to re-execute their setup actions or treat prior inputs as current instructions |
| `references/system-reminder-provider-context.md` | Warns that the session is not using Anthropic's first-party API and that some features may differ |
| `references/system-reminder-question-context.md` | Provides potentially relevant context entries to use only when highly relevant to the current task |
| `references/system-reminder-read-truncation-retry-guidance.md` | Instructs Claude to reduce chunk size after file-read truncation warnings and notes the Bash output character limit |
| `references/system-reminder-scheduled-task-automated-firing.md` | Marks a scheduled turn as an automated firing of a stored prompt and warns that no live user approval or confirmation has occurred |
| `references/system-reminder-session-continuation.md` | Notification that session continues from another machine |
| `references/system-reminder-session-stop-hook-active.md` | Tells Claude a session-scoped Stop hook condition is active and must be treated as the directive until met |
| `references/system-reminder-stop-hook-blocking-error.md` | Error from a blocking hook command |
| `references/system-reminder-task-tools-reminder.md` | Reminder to use task tracking tools |
| `references/system-reminder-team-coordination.md` | System reminder for team coordination |
| `references/system-reminder-team-shutdown.md` | System reminder for team shutdown |
| `references/system-reminder-terminal-and-ide-click-tier-restrictions.md` | Explains click-tier limits for terminal and IDE apps, including no keyboard input, context-menu paste, or drag-drop |
| `references/system-reminder-todowrite-reminder.md` | Reminder to use TodoWrite tool for task tracking |
| `references/system-reminder-token-usage.md` | Current token usage statistics |
| `references/system-reminder-ultracode-enabled.md` | Instructs the agent to optimize for exhaustive correctness and use Workflow on substantive tasks when Ultracode is enabled |
| `references/system-reminder-ultraplan-mode.md` | System reminder for using Ultraplan mode to create a detailed implementation plan with multi-agent exploration and critique. |
| `references/system-reminder-usd-budget.md` | Current USD budget statistics |
| `references/system-reminder-workflow-isolated-worktree.md` | Tells a workflow subagent it is running in an isolated git worktree separate from the main working directory |
