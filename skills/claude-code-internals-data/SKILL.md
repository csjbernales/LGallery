---
name: claude-code-internals-data
description: "Reference data used by Claude Code: the model catalog, API and SDK references across languages, event schemas, and platform guides. Use when you need Claude Code canonical reference data."
---
A bundled, verbatim collection of reference data files shipped with Claude Code, including the model catalog and multi-language API references.

## How to use this skill

This skill bundles the source documents under `references/`. Scan the index below, then read the specific file(s) you need with your file-reading tool. Do not load everything at once.

## Reference index

| Document | What it covers |
| --- | --- |
| `references/data-anthropic-cli.md` | Reference documentation for the ant CLI covering installation, authentication, command structure, input and output shaping, managed agents workflows, and scripting patterns |
| `references/data-artifact-connector-call-observation-requirement.md` | Requires observing a connector tool request and response before publishing an Artifact that calls it |
| `references/data-artifact-mcp-connector-guidance.md` | Explains how Artifact MCP manifests identify claude.ai connectors and discover upstream tool names |
| `references/data-artifact-runtime-capability-declarations.md` | Defines Artifact runtime capability declaration, carry-forward, clearing, replacement, and contract pinning semantics |
| `references/data-auto-mode-setup-usage.md` | Defines /auto-mode-setup proposal and reviewed-apply command syntax, request ID ordering, save-target validation, and integrity requirements |
| `references/data-background-tasks-changed-event-schema.md` | Schema description for the background_tasks_changed system event and its replace-set semantics |
| `references/data-claude-api-reference-c.md` | C# SDK reference including installation, client initialization, basic requests, streaming, and tool use |
| `references/data-claude-api-reference-curl.md` | Raw API reference for Claude API for use with cURL or else Raw HTTP |
| `references/data-claude-api-reference-go.md` | Go SDK reference |
| `references/data-claude-api-reference-java.md` | Java SDK reference including installation, client initialization, basic requests, streaming, and beta tool use |
| `references/data-claude-api-reference-php.md` | PHP SDK reference |
| `references/data-claude-api-reference-python.md` | Python SDK reference including installation, client initialization, basic requests, thinking, and multi-turn conversation |
| `references/data-claude-api-reference-ruby.md` | Ruby SDK reference including installation, client initialization, basic requests, streaming, and beta tool runner |
| `references/data-claude-api-reference-typescript.md` | TypeScript SDK reference including installation, client initialization, basic requests, thinking, and multi-turn conversation |
| `references/data-claude-code-agent-proxy-troubleshooting-guide.md` | Troubleshooting guide for Claude Code's policy-enforcing HTTPS agent proxy, covering TLS trust setup, status checks, git, docker, and unsupported traffic |
| `references/data-claude-code-gateway-protocol.md` | Markdown reference documenting the Claude Code gateway wire contract, including OAuth 2.0 device flow, RFC 8414 discovery, Messages API inference, managed settings, model discovery, OTLP telemetry, error envelopes, TLS certificate pinning, and proxying to Bedrock, Vertex, and Foundry |
| `references/data-claude-code-live-documentation-sources.md` | WebFetch URLs for fetching current Claude Code documentation from official sources |
| `references/data-claude-code-recent-changes-reference.md` | Reference mapping of recently removed or renamed Claude Code commands, flags, and terms to their current replacements |
| `references/data-claude-gateway-landing-page.md` | HTML status page served at a Claude Code gateway root, showing the gateway logo, the running gateway URL, the identity-provider host, an OAuth discovery link, and the gateway version |
| `references/data-claude-model-catalog.md` | Catalog of current and legacy Claude models with exact model IDs, aliases, context windows, and pricing |
| `references/data-claude-platform-on-aws-reference.md` | Reference documentation for using the Claude Developer Platform through AWS infrastructure, including AnthropicAWS clients, required region and workspace configuration, SigV4 authentication, and short-term API keys |
| `references/data-claude-tag-claude-in-slack-reference.md` | Offline reference for Claude Tag, Claude Code's org-managed Slack surface, covering what it is, availability, setup, configuration, and how it differs from the earlier Claude in Slack app |
| `references/data-code-change-published-event-schema.md` | Schema description for the code_change_published system event, including provenance, idempotency, trust boundaries, and best-effort delivery |
| `references/data-cowork-plugin-component-schemas.md` | Reference documentation for Cowork plugin component formats, including skills, agents, hooks, MCP servers, legacy commands, CONNECTORS.md, and README.md |
| `references/data-cowork-plugin-examples.md` | Reference examples of minimal, medium, and complex Cowork plugin structures with plugin metadata, skills, agents, hooks, MCP config, README, and connectors |
| `references/data-cowork-plugin-mcp-discovery-and-connection.md` | Reference guidance for finding MCP connectors during plugin customization, using search and suggestion tools, mapping categories to keywords, and writing .mcp.json entries |
| `references/data-data-visualization-anti-patterns.md` | Reference list of chart and dashboard anti-patterns to check against before shipping a data visualization |
| `references/data-data-visualization-choosing-a-form.md` | Reference guidance for choosing the appropriate chart, stat tile, or non-chart form based on the data's job |
| `references/data-data-visualization-components.md` | Reference specification for the HTML/SVG pieces, layers, and system parameters that make up a data visualization |
| `references/data-data-visualization-interaction.md` | Reference guidance for chart hover layers, tooltips, filters, linked highlighting, and interaction behavior |
| `references/data-data-visualization-marks-and-anatomy.md` | Reference specifications for chart marks, spacing, labels, axes, legends, and stat-tile anatomy |
| `references/data-data-visualization-reference-palette.md` | Reference palette instance for the data visualization method, including ramps, categorical order, status colors, surfaces, and typography |
| `references/data-directoryadded-hook-description.md` | Describes when the DirectoryAdded hook fires, its input fields, and how failures and output are handled for add-dir and register_repo_root sources |
| `references/data-files-api-reference-go.md` | Go Files API reference including file upload, listing, deletion, and usage in messages |
| `references/data-files-api-reference-python.md` | Python Files API reference including file upload, listing, deletion, and usage in messages |
| `references/data-files-api-reference-typescript.md` | TypeScript Files API reference including file upload, listing, deletion, and usage in messages |
| `references/data-gateway-device-code-entry-page.md` | HTML verification page served at a gateway device endpoint, prompting the user to enter the short device code shown by Claude Code so they can sign in through their company identity provider |
| `references/data-github-actions-workflow-for-claude-mentions.md` | GitHub Actions workflow template for triggering Claude Code via @claude mentions |
| `references/data-github-app-installation-pr-description.md` | Template for PR description when installing Claude Code GitHub App integration |
| `references/data-governed-github-cli-shim-header.md` | Header comments for the per-session governed GitHub CLI shim that routes github.com gh traffic through the agent proxy while preserving customer-token and GitHub Enterprise traffic |
| `references/data-governed-github-cli-shim-routing.md` | Shell routing logic for the governed gh shim, including GitHub host detection, real gh fallback execution, agent proxy settings, CA bundle configuration, and proxy-injected tokens |
| `references/data-http-error-codes-reference.md` | Reference for HTTP error codes returned by the Claude API with common causes and handling strategies |
| `references/data-interrupt-cancel-queued-parameter.md` | Schema description for the optional interrupt cancel_queued request parameter and its queued-command cancellation semantics |
| `references/data-interrupt-receipt-cancelled-field.md` | Schema description for the cancelled UUID list returned when an interrupt request cancels queued commands |
| `references/data-interrupt-receipt-still-queued-field.md` | Schema description for the still_queued UUID list returned by interrupt control responses |
| `references/data-knowledge-mcp-search-strategies.md` | Reference query patterns for using knowledge MCPs to discover organization-specific tool names, project identifiers, team names, and workflow details during plugin customization |
| `references/data-live-documentation-sources.md` | WebFetch URLs for fetching current Claude API and Agent SDK documentation from official sources |
| `references/data-managed-agents-client-patterns.md` | Reference guide of common client-side patterns for driving Managed Agent sessions, including stream reconnection, idle-break gating, tool confirmations, interrupts, and custom tools |
| `references/data-managed-agents-core-concepts.md` | Reference documentation for the Managed Agents API covering core concepts (Agents, Sessions, Environments, Containers), lifecycle, versioning, endpoints, and usage patterns |
| `references/data-managed-agents-endpoint-reference.md` | Comprehensive reference for Managed Agents API endpoints, SDK methods, request/response schemas, error handling, and rate limits |
| `references/data-managed-agents-environments-and-resources.md` | Reference documentation covering Managed Agents environments, file resources, GitHub repository mounting, and the Files API with SDK examples |
| `references/data-managed-agents-events-and-steering.md` | Reference guide for sending and receiving events on managed agent sessions, including streaming, polling, reconnection, message queuing, interrupts, and event payload details |
| `references/data-managed-agents-memory-stores-reference.md` | Reference documentation for managed agents memory stores, memory versions, attachment, and direct memory management |
| `references/data-managed-agents-multiagent-sessions.md` | Reference documentation for Managed Agents multiagent sessions, including coordinator rosters, threads, session stream events, subagent tool permissions, and pitfalls |
| `references/data-managed-agents-outcomes.md` | Reference documentation for Managed Agents outcomes, including user.define_outcome events, rubrics, outcome evaluation events, deliverables, and interaction rules |
| `references/data-managed-agents-overview.md` | Provides the agent with a comprehensive overview of the Managed Agents API architecture, mandatory agent-then-session flow, beta headers, documentation reading guide, and common pitfalls |
| `references/data-managed-agents-reference-curl.md` | Provides cURL and raw HTTP request examples for the Managed Agents API including environment, agent, and session lifecycle operations |
| `references/data-managed-agents-reference-go.md` | Reference guide for using the Anthropic Go SDK to create and manage agents, environments, sessions, and tools |
| `references/data-managed-agents-reference-java.md` | Reference guide for using the Anthropic Java SDK to create and manage agents, environments, and sessions |
| `references/data-managed-agents-reference-php.md` | Reference guide for using the Anthropic PHP SDK to create and manage agents, environments, and sessions |
| `references/data-managed-agents-reference-python.md` | Reference guide for using the Anthropic Python SDK to create and manage agents, sessions, environments, streaming, custom tools, files, and MCP servers |
| `references/data-managed-agents-reference-ruby.md` | Reference guide for using the Anthropic Ruby SDK to create and manage agents, environments, and sessions |
| `references/data-managed-agents-reference-typescript.md` | Reference guide for using the Anthropic TypeScript SDK to create and manage agents, sessions, environments, streaming, custom tools, file uploads, and MCP server integration |
| `references/data-managed-agents-scheduled-deployments.md` | Reference documentation for Managed Agents scheduled deployments, including cron schedule creation, deployment runs, lifecycle operations, failure behavior, and manual runs |
| `references/data-managed-agents-self-hosted-sandboxes.md` | Reference documentation for running Managed Agents tool execution in self-hosted infrastructure, including environment setup, workers, webhook-driven wake, orchestration, monitoring, credentials, and security responsibilities |
| `references/data-managed-agents-tools-and-skills.md` | Reference documentation covering the Managed Agents SDK's tool types (agent toolset, MCP, custom), permission policies, vault credential management, and skills API for building specialized agents |
| `references/data-managed-agents-webhooks.md` | Reference documentation for Managed Agents webhooks, including endpoint registration, signature verification, payload envelopes, supported event types, delivery behavior, and pitfalls |
| `references/data-message-batches-api-reference-python.md` | Python Batches API reference including batch creation, status polling, and result retrieval at 50% cost |
| `references/data-message-batches-api-typescript.md` | TypeScript usage guide for Claude's asynchronous Message Batches endpoint |
| `references/data-peer-sender-display-name-field.md` | Schema description for the normalized display name on cross-session peer message senders |
| `references/data-plan-artifact-html-template.md` | Standalone HTML template used for published plan artifacts, including layout, fill contract, and light/dark styling |
| `references/data-platform-availability.md` | Feature availability matrix across Claude API provider platforms (first-party, Claude Platform on AWS, Bedrock, Vertex, and Foundry) |
| `references/data-prompt-caching-design-optimization.md` | Document on how to design prompt-building code for effective caching, including placement patterns and anti-patterns. |
| `references/data-rewind-files-skippedlinks-field.md` | Describes the rewindFiles skippedLinks count, including link-safety refusal semantics and dry-run behavior |
| `references/data-sandbox-filesystem-disabled-setting.md` | Describes sandbox.filesystem.disabled behavior, platform limits, read-protection effects, and configuration precedence |
| `references/data-sdk-protocol-capabilities-field.md` | Schema description for the optional system init capabilities list used by SDK consumers to feature-detect interrupt receipt and queued-cancellation behavior |
| `references/data-streaming-reference-c.md` | C# streaming reference including streaming events and the RawMessageStreamEvent TryPick methods |
| `references/data-streaming-reference-php.md` | PHP streaming reference including streaming events and handling content block deltas (requires SDK v0.5.0+) |
| `references/data-streaming-reference-python.md` | Python streaming reference including sync/async streaming and handling different content types |
| `references/data-streaming-reference-typescript.md` | TypeScript streaming reference including basic streaming and handling different content types |
| `references/data-thin-client-diff-dialog-schema.md` | Internal data description for workspace git diff payloads used by the thin-client diff dialog |
| `references/data-token-counting-reference.md` | Reference documentation for counting Claude model tokens with the Messages count_tokens endpoint and Anthropic SDK or CLI examples, including warnings against OpenAI tokenizers |
| `references/data-tool-use-concepts.md` | Conceptual foundations of tool use with the Claude API including tool definitions, tool choice, and best practices |
| `references/data-tool-use-display-metadata-field.md` | Documents the tool_use_meta wire field carrying per-block display metadata for a message's tool_use blocks; it is wrapper-level UI metadata and is not replayed to the model |
| `references/data-tool-use-reference-c.md` | C# tool use reference including defining tools and reconstructing response content for the follow-up assistant message |
| `references/data-tool-use-reference-go.md` | Go tool use reference including the beta tool runner with automatic schema generation and the manual agentic loop |
| `references/data-tool-use-reference-java.md` | Java tool use reference including defining tools and the manual agentic loop |
| `references/data-tool-use-reference-php.md` | PHP tool use reference including the beta tool runner and the manual agentic loop with camelCase keys |
| `references/data-tool-use-reference-python.md` | Python tool use reference including tool runner, manual agentic loop, code execution, and structured outputs |
| `references/data-tool-use-reference-typescript.md` | TypeScript tool use reference including tool runner, manual agentic loop, code execution, and structured outputs |
| `references/data-vcs-state-changed-event-schema.md` | Schema description for the vcs_state_changed system event as a best-effort repository cache-invalidation signal |
| `references/data-workshop-artifact-html-template.md` | Standalone HTML template used for published workshop artifacts, including decision rendering, fill contract, interaction controls, and light/dark styling |
