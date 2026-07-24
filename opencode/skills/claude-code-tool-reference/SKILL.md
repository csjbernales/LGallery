---
name: claude-code-tool-reference
description: "Reference library of Claude Code built-in tool descriptions and tool parameters (Bash, Read, Edit, Agent, Artifact, WebFetch, and more). Use when studying how Claude Code documents its tools and parameters to the model."
---
A bundled, verbatim collection of Claude Code tool descriptions and tool-parameter documentation, one document per file.

## How to use this skill

This skill bundles the source documents under `references/`. Scan the index below, then read the specific file(s) you need with your file-reading tool. Do not load everything at once.

## Reference index

| Document | What it covers |
| --- | --- |
| `references/tool-description-agent-explicit-spawn-restriction.md` | Restricts agent spawning to explicit user requests or named agent types instead of inferred thoroughness |
| `references/tool-description-agent-simple-usage-notes.md` | Simplified usage notes for the Agent tool, including when to delegate, fork behavior, resumption, worktree isolation, background execution, parallel launches, and context restrictions |
| `references/tool-description-agent-usage-notes.md` | Usage notes and instructions for the Task/Agent tool, including guidance on launching subagents, background execution, resumption, and worktree isolation |
| `references/tool-description-agent-when-to-launch-subagents.md` | Describes _when_ to use the Agent tool - for launching specialized subagent subprocesses to autonomously handle complex multi-step tasks |
| `references/tool-description-artifact.md` | Describes the Artifact tool for deploying self-contained HTML or Markdown pages, including file-first usage, update behavior, CSP constraints, responsive design, and favicon requirements |
| `references/tool-description-artifact-brief.md` | Brief description of the Artifact tool for publishing a default-private HTML or Markdown page on claude.ai |
| `references/tool-description-artifact-publishing-and-update-guidance.md` | Provides Artifact lookup, update, ownership, watch, content-safety, self-containment, responsive design, theme, favicon, and anti-impersonation requirements |
| `references/tool-description-artifact-runtime-capabilities-guidance.md` | Explains when Artifact runtime capabilities require loading the artifact-capabilities skill and how redeploys preserve or clear capabilities |
| `references/tool-description-artifact-supporting-files-guidance.md` | Explains how Artifact supporting-file maps, source paths, content types, and root directory resolution work |
| `references/tool-description-artifact-supporting-files-summary.md` | Summarizes an Artifact publish with a computed count of supporting files |
| `references/tool-description-askuserquestion.md` | Tool description for asking user questions. |
| `references/tool-description-askuserquestion-decision-guidance.md` | Additional guidance for using AskUserQuestion only when the user's answer changes what the agent should do next |
| `references/tool-description-askuserquestion-preview-field.md` | Instructions for using the HTML preview field on single-select question options to display visual artifacts like UI mockups, code snippets, and diagrams |
| `references/tool-description-background-monitor-streaming-events.md` | Describes the background monitor tool that streams stdout events from long-running scripts as chat notifications, with guidelines on script quality, output volume, and selective filtering |
| `references/tool-description-background-monitor-websocket-source.md` | Addendum to the background monitor tool description covering the WebSocket (ws) source, which opens a WebSocket and streams each incoming text frame as a notification event instead of running a shell command, with notes on binary frames, socket close, and rate limiting |
| `references/tool-description-bash-alternative-communication.md` | Bash tool alternative: output text directly instead of echo/printf |
| `references/tool-description-bash-alternative-content-search.md` | Bash tool alternative: use Grep for content search instead of grep/rg |
| `references/tool-description-bash-alternative-edit-files.md` | Bash tool alternative: use Edit for file editing instead of sed/awk |
| `references/tool-description-bash-alternative-file-search.md` | Bash tool alternative: use Glob for file search instead of find/ls |
| `references/tool-description-bash-alternative-read-files.md` | Bash tool alternative: use Read for file reading instead of cat/head/tail |
| `references/tool-description-bash-alternative-write-files.md` | Bash tool alternative: use Write for file writing instead of echo/cat |
| `references/tool-description-bash-built-in-tools-note.md` | Note that built-in tools provide better UX than Bash equivalents |
| `references/tool-description-bash-git-avoid-destructive-ops.md` | Bash tool git instruction: consider safer alternatives to destructive operations |
| `references/tool-description-bash-git-commit-and-pr-creation-instructions.md` | Instructions for creating git commits and GitHub pull requests |
| `references/tool-description-bash-git-never-skip-hooks.md` | Bash tool git instruction: never skip hooks or bypass signing unless user requests it |
| `references/tool-description-bash-git-prefer-new-commits.md` | Bash tool git instruction: prefer new commits over amending |
| `references/tool-description-bash-maintain-cwd.md` | Bash tool instruction: use absolute paths and avoid cd |
| `references/tool-description-bash-overview.md` | Opening line of the Bash tool description |
| `references/tool-description-bash-prefer-dedicated-tools.md` | Warning to prefer dedicated tools over Bash for find, grep, cat, etc. |
| `references/tool-description-bash-prefer-dedicated-tools-bullet.md` | Bulleted warning to prefer dedicated tools over Bash for find, grep, cat, etc. |
| `references/tool-description-bash-quote-file-paths.md` | Bash tool instruction: quote file paths containing spaces |
| `references/tool-description-bash-sandbox-adjust-settings.md` | Work with user to adjust sandbox settings on failure |
| `references/tool-description-bash-sandbox-default-to-sandbox.md` | Default to sandbox; only bypass when user asks or evidence of sandbox restriction |
| `references/tool-description-bash-sandbox-evidence-access-denied.md` | Sandbox evidence: access denied to paths outside allowed directories |
| `references/tool-description-bash-sandbox-evidence-list-header.md` | Header for list of sandbox-caused failure evidence |
| `references/tool-description-bash-sandbox-evidence-network-failures.md` | Sandbox evidence: network connection failures to non-whitelisted hosts |
| `references/tool-description-bash-sandbox-evidence-operation-not-permitted.md` | Sandbox evidence: operation not permitted errors |
| `references/tool-description-bash-sandbox-evidence-unix-socket-errors.md` | Sandbox evidence: unix socket connection errors |
| `references/tool-description-bash-sandbox-explain-restriction.md` | Explain which sandbox restriction caused the failure |
| `references/tool-description-bash-sandbox-failure-evidence-condition.md` | Condition: command failed with evidence of sandbox restrictions |
| `references/tool-description-bash-sandbox-mandatory-mode.md` | Policy: all commands must run in sandbox mode |
| `references/tool-description-bash-sandbox-no-exceptions.md` | Commands cannot run outside sandbox under any circumstances |
| `references/tool-description-bash-sandbox-no-sensitive-paths.md` | Do not suggest adding sensitive paths to sandbox allowlist |
| `references/tool-description-bash-sandbox-per-command.md` | Treat each command individually; default to sandbox for future commands |
| `references/tool-description-bash-sandbox-response-header.md` | Header for how to respond when seeing sandbox-caused failures |
| `references/tool-description-bash-sandbox-retry-without-sandbox.md` | Immediately retry with dangerouslyDisableSandbox on sandbox failure |
| `references/tool-description-bash-sandbox-tmpdir.md` | Use $TMPDIR for temporary files in sandbox mode |
| `references/tool-description-bash-sleep-keep-short.md` | Bash tool instruction: keep sleep duration to 1-5 seconds |
| `references/tool-description-bash-sleep-no-polling-background-tasks.md` | Bash tool instruction: do not poll background tasks, wait for notification |
| `references/tool-description-bash-sleep-run-immediately.md` | Bash tool instruction: do not sleep between commands that can run immediately |
| `references/tool-description-bash-sleep-use-check-commands.md` | Bash tool instruction: use check commands rather than sleeping when polling |
| `references/tool-description-bash-timeout.md` | Bash tool instruction: optional timeout configuration |
| `references/tool-description-bash-verify-parent-directory.md` | Bash tool instruction: verify parent directory before creating files |
| `references/tool-description-bash-working-directory.md` | Bash tool note about working directory persistence and shell state |
| `references/tool-description-browserbatch.md` | Tool description for BrowserBatch, which executes multiple browser tool calls sequentially in one round trip |
| `references/tool-description-browser-file-upload.md` | Describes the browser file upload tool, which uploads shared files directly to a page file input by element ref and enforces the 10 MB combined size limit |
| `references/tool-description-chrome-browser-automation.md` | Describes Chrome browser automation tools for page interaction, screenshots, console logs, and navigation |
| `references/tool-description-claude-ai-project.md` | Read and write the claude.ai Project bound to the session — a shared, persistent knowledge container — via project_info/read/search/write/delete methods, including knowledge-budget enforcement, the claude/ namespace default for agent-written docs, prompt-cache churn warnings, and treating doc contents as untrusted data |
| `references/tool-description-claudedesign.md` | Describes the ClaudeDesign tool for working with claude.ai/design projects, including project and file operations, previews, plan tokens, and live design output conventions |
| `references/tool-description-claude-in-chrome-bridge-disconnect-error.md` | Error message shown when a Claude in Chrome tool call fails because the Chrome extension disconnects mid-operation |
| `references/tool-description-claude-in-chrome-bridge-timeout-error.md` | Error message shown when a Claude in Chrome tool does not respond before timing out |
| `references/tool-description-claude-in-chrome-find.md` | Describes the Claude in Chrome find tool for locating page elements by natural language or text content |
| `references/tool-description-claude-in-chrome-get-page-text.md` | Describes the Claude in Chrome get_page_text tool for extracting raw text content from a page |
| `references/tool-description-claude-in-chrome-javascript-tool.md` | Describes the Claude in Chrome JavaScript execution tool for running code in the current page context |
| `references/tool-description-claude-in-chrome-read-console-messages.md` | Describes the Claude in Chrome read_console_messages tool for reading filtered browser console output |
| `references/tool-description-claude-in-chrome-read-network-requests.md` | Describes the Claude in Chrome read_network_requests tool for inspecting HTTP requests made by the current page |
| `references/tool-description-claude-in-chrome-read-page.md` | Describes the Claude in Chrome read_page tool for retrieving an accessibility tree of page elements |
| `references/tool-description-claude-in-chrome-shortcuts-execute.md` | Describes the Claude in Chrome shortcuts_execute tool for starting a shortcut or workflow in a side panel |
| `references/tool-description-claude-in-chrome-switch-browser.md` | Describes the Claude in Chrome switch_browser tool for letting the user choose a browser from inside connected Chrome extensions |
| `references/tool-description-claude-in-chrome-tabs-context.md` | Describes the Claude in Chrome tabs_context_mcp tool for retrieving the current MCP tab group context |
| `references/tool-description-code-review-command.md` | Describes the code review command and its effort levels, PR comment mode, and fix mode |
| `references/tool-description-computer.md` | Main description for the Chrome browser computer automation tool |
| `references/tool-description-computer-computer-batch.md` | Describes the computer-use computer_batch tool for executing a sequence of computer actions in one call |
| `references/tool-description-computer-hold-key.md` | Describes the computer-use hold_key tool for pressing and holding keys or key combinations with allowlist and system-combo checks |
| `references/tool-description-computer-left-mouse-down.md` | Describes the computer-use left_mouse_down tool for holding the left mouse button at the current cursor position |
| `references/tool-description-computer-left-mouse-up.md` | Describes the computer-use left_mouse_up tool for releasing the left mouse button at the current cursor position |
| `references/tool-description-computer-request-access.md` | Describes the computer-use request_access tool for asking user permission to control applications in the session |
| `references/tool-description-computer-type.md` | Describes the computer-use type tool for entering text into the focused allowlisted application |
| `references/tool-description-computer-zoom.md` | Describes the computer-use zoom tool for taking read-only higher-resolution screenshots of regions |
| `references/tool-description-cowork-onboarding-role-picker.md` | Describes the Cowork onboarding role-picker tool that returns a selected or typed role and should only be used while setting up Cowork for the user's job function |
| `references/tool-description-cowork-plugin-creation.md` | Describes the command for creating or customizing Cowork plugins for an organization |
| `references/tool-description-croncreate.md` | Describes the CronCreate tool for enqueuing one-shot or recurring cron-based jobs with jitter and off-minute scheduling guidance |
| `references/tool-description-croncreate-durability-note.md` | CronCreate insert (shown when durable-cron is enabled) explaining the durable: true vs false trade-off |
| `references/tool-description-designsync.md` | Describes the DesignSync tool for reading and updating claude.ai/design design-system projects, including project listing, plan finalization, file writes and deletes, and asset registration |
| `references/tool-description-edit.md` | Tool for performing exact string replacements in files |
| `references/tool-description-edit-minimal-old-string-guidance.md` | Additional Edit guidance to keep old_string minimal and unique or use replace_all |
| `references/tool-description-edit-single-replacement.md` | Tool description for performing exact string replacement in a file, including prior-read and line-prefix requirements |
| `references/tool-description-endconversation.md` | Defines when the assistant may use the EndConversation tool and the safety constraints that forbid ending the conversation |
| `references/tool-description-enterplanmode.md` | Tool description for entering plan mode to explore and design implementation approaches |
| `references/tool-description-enterplanmode-ambiguous-tasks.md` | Tool for entering plan mode when task has ambiguity |
| `references/tool-description-enterworktree.md` | Tool description for the EnterWorktree tool. |
| `references/tool-description-exitplanmode.md` | Description for the ExitPlanMode tool, which presents a plan dialog for the user to approve |
| `references/tool-description-exitworktree.md` | Roughly, the reverse of the ExitWorktree |
| `references/tool-description-glob.md` | Tool description for file pattern matching and searching by name |
| `references/tool-description-glob-compact.md` | Compact Glob tool description served to newer models — file pattern matching returning paths sorted by modification time |
| `references/tool-description-grep.md` | Tool description for content search using ripgrep |
| `references/tool-description-grep-compact.md` | Compact Grep tool description served to newer models — ripgrep-backed content search preferred over raw grep/rg, with permission-UI integration |
| `references/tool-description-invoke-skill.md` | Tool description for invoking available skills, including skill name selection, optional arguments, scoped skill names, and avoiding duplicate invocation when a skill is already loaded |
| `references/tool-description-listagents.md` | Describes the ListAgents tool, which lists agents you can message — in-process subagents, other local and cloud Claude sessions, and remote bridge sessions |
| `references/tool-description-listconnectors.md` | Describes the ListConnectors tool for listing installed claude.ai MCP connectors, filtering by keyword, and interpreting org-level connection and chat-enabled status |
| `references/tool-description-listmcpresourcestool.md` | Tool description for listing available MCP resources from all configured servers or a specific server |
| `references/tool-description-listmcpresourcestool-prompt.md` | Tool prompt for listing MCP resources and explaining the optional server parameter |
| `references/tool-description-lsp.md` | Description for the LSP tool. |
| `references/tool-description-navigate.md` | Describes the browser navigate tool for opening URLs and moving forward or backward in tab history |
| `references/tool-description-notebookedit.md` | Tool description for editing Jupyter notebook cells by replacing, inserting, or deleting a cell using cell IDs from the read tool |
| `references/tool-description-powershell.md` | Describes the PowerShell command execution tool with syntax guidance, timeout settings, and instructions to prefer specialized tools over PowerShell for file operations |
| `references/tool-description-pushnotification.md` | Tool description for PushNotification. This is a tool that sends a desktop notification in the user's terminal and pushes to their phone if Remote Control is connected. |
| `references/tool-description-readfile.md` | Tool description for reading files |
| `references/tool-description-readfile-compact.md` | Compact file-read tool description served to newer models — absolute path, default line cap, and image/PDF/notebook handling |
| `references/tool-description-readmcpresourcedirtool-prompt.md` | Tool prompt for listing direct children of an MCP directory resource and explaining the required server and uri parameters |
| `references/tool-description-refreshmcptools.md` | Describes when and how to refresh connected MCP servers tool lists to recover missing or stale tools |
| `references/tool-description-refreshmcptools-prompt.md` | Tool prompt for refreshing one or all connected MCP servers tool lists and interpreting per-server results |
| `references/tool-description-remotetrigger-prompt.md` | Tool prompt for calling the claude.ai RemoteTrigger API to list, get, create, update, or run scheduled remote agent routines |
| `references/tool-description-repl.md` | Describes the REPL tool, a JavaScript programming interface for looping, branching, and composing Claude Code tool calls as async functions |
| `references/tool-description-report-code-review-findings.md` | Tool description for reporting verified code-review findings as a typed list for host UI rendering |
| `references/tool-description-request-teach-access-part-of-teach-mode.md` | Describes a tool that requests permission to guide the user through a task step-by-step using fullscreen tooltip overlays instead of direct access |
| `references/tool-description-schedulewakeup-delay-and-reason-guidance.md` | Extends the ScheduleWakeup tool description with no-op reporting, prompt-cache-aware delay selection, and concise reason-field guidance |
| `references/tool-description-searchmcpregistry.md` | Describes the SearchMcpRegistry tool for discovering MCP connectors by keyword, including named-product and intent-based examples and install-state guidance |
| `references/tool-description-searchplugins.md` | Describes the SearchPlugins tool for finding relevant claude.ai org catalog plugins by keyword and suggesting install cards when results fit |
| `references/tool-description-searchskills.md` | Describes the SearchSkills tool for finding relevant claude.ai skills by keyword and suggesting add cards when results fit |
| `references/tool-description-sendfeedback-drafting-guidance.md` | Instructs when and how to queue factual local Claude Code feedback drafts without interrupting the user, duplicating issues, guessing details, or including sensitive information |
| `references/tool-description-sendfile.md` | Describes sending local files to peer, Remote Control, or cloud Claude Code sessions, including addressing, limits, integrity verification, and when to use shared-text messaging instead |
| `references/tool-description-sendmessage.md` | Describes the SendMessage tool for communicating with other agents and handling legacy team protocol responses |
| `references/tool-description-senduserfile.md` | Describes the SendUserFile tool for surfacing generated deliverable files to the user, with optional captions and normal or proactive status |
| `references/tool-description-sendusermessage.md` | Describes the SendUserMessage tool for sending user-visible Markdown messages and attachments with normal or proactive status |
| `references/tool-description-sendusermessage-verbatim.md` | Describes the concise SendUserMessage tool variant for sending verbatim user-visible messages with normal or proactive status |
| `references/tool-description-showonboardingrolepicker.md` | ShowOnboardingRolePicker: presents a row of clickable role chips during Cowork onboarding |
| `references/tool-description-snooze-delay-and-reason-guidance.md` | Extends the snooze tool description with guidance on choosing delaySeconds relative to the 5-minute prompt cache TTL and writing informative reason fields |
| `references/tool-description-suggestconnectors.md` | Describes the SuggestConnectors tool for resolving SearchMcpRegistry directoryUuid values into full connector payloads and install-state guidance |
| `references/tool-description-suggestskills-proactive-guidance.md` | Guides proactive use of SuggestSkills to recommend addable standalone skills for repeatable tasks without interrupting one-off work |
| `references/tool-description-taskcreate.md` | Tool description for TaskCreate tool |
| `references/tool-description-task-get.md` | Retrieve a task by ID with full details and comments |
| `references/tool-description-tasklist.md` | Description for the TaskList tool, which lists all tasks in the task list |
| `references/tool-description-tasklist-teammate-workflow.md` | Conditional section appended to TaskList tool description |
| `references/tool-description-taskupdate.md` | Description for the TaskUpdate tool, which updates Claude's task list |
| `references/tool-description-todowrite.md` | Tool description for creating and managing task lists |
| `references/tool-description-todowrite-compact.md` | Compact tool description for creating and updating a session task list with content, status, and activeForm fields |
| `references/tool-description-todowrite-proactive-update-guidance.md` | Concise TodoWrite guidance to proactively track progress with one in-progress task and activeForm values |
| `references/tool-description-toolsearch-second-part.md` | The bulk of the tool description. |
| `references/tool-description-webfetch.md` | Tool description for web fetch functionality |
| `references/tool-description-webfetch-concise.md` | Concise tool description for WebFetch covering URL fetching, private URL limitations, redirects, and caching |
| `references/tool-description-webfetch-private-url-warning.md` | Warns that WebFetch fails for authenticated or private URLs and includes the standard WebFetch usage notes |
| `references/tool-description-websearch.md` | Tool description for web search functionality |
| `references/tool-description-websearch-concise.md` | Describes the concise WebSearch tool variant with US-only results, current-month guidance, domain filters, and required sources |
| `references/tool-description-workflow.md` | Describes the Workflow tool for running deterministic multi-subagent orchestration scripts, including opt-in requirements, script metadata, agent hooks, concurrency, budgeting, quality patterns, and resume behavior |
| `references/tool-description-write.md` | Tool for writing files to the local filesystem |
| `references/tool-description-write-read-existing-file-first.md` | Tool description for Write in environments where existing files must be read before overwrite |
| `references/tool-parameter-bash-run-in-background-guidance.md` | Explains Bash run_in_background behavior and that commands do not need a trailing ampersand |
| `references/tool-parameter-bash-run-in-background-note.md` | Notes that Bash commands can use run_in_background when the result is not needed immediately |
| `references/tool-parameter-claude-in-chrome-javascript-code.md` | Describes the JavaScript code parameter for the Claude in Chrome JavaScript execution tool |
| `references/tool-parameter-computer-action.md` | Action parameter options for the Chrome browser computer tool |
| `references/tool-parameter-matched-ask-rule.md` | Describes metadata identifying a user-configured permissions.ask rule that forced a tool approval prompt while preserving the tool-authored decision reason |
| `references/tool-parameter-sendusermessage-attachments.md` | Describes optional SendUserMessage attachments as local file paths or pre-resolved file objects |
| `references/tool-parameter-set-cwd-needs-trust-directory.md` | Describes the canonical target directory returned by a set_cwd needs_trust response, which the SDK host must show in a trust dialog and echo back verbatim on accept |
