# Claude Code internals → OpenCode

This directory is an **OpenCode-compatible port** of a large collection of extracted
Claude Code internal prompts and reference material (system prompts, agent prompts,
tool descriptions, and reference data). It is intended for **educational / study use** —
to see how Claude Code is built and to reuse the pieces inside [OpenCode](https://opencode.ai).

The original files in the sibling folders (`agent/`, `data/`, `skills/`, `system prompt/`,
`system reminder/`, `tool description/`, `tool parameter/`) are **untouched**. Everything
here was generated from them.

> These prompts describe Claude Code's own tools and behaviors. They are reference material,
> not turnkey config — see [Caveats](#caveats) before relying on any single file.

---

## What's here

| Folder | Count | OpenCode kind | How it's used |
| --- | --- | --- | --- |
| `skills/` | **81** skills | Skill (`<name>/SKILL.md`) | Loaded **on demand by the model** via the `skill` tool when the description matches the task |
| `commands/` | **9** commands | Command (`<name>.md`) | Run **by you** by typing `/<name>` in the TUI |
| `agents/` | **61** agents | Subagent (`<name>.md`) | Invoked with `@<name>` or automatically by a primary agent |
| `plugins/` | **3** plugins | Plugin (`*.ts`) | **Auto-loaded** at startup; hook into tool/session events |

Of the 81 skills, **77** are direct 1:1 ports of individual Claude Code skills and **4** are
grouped *reference libraries* (below) that together bundle **463** source documents verbatim.

Of the 61 agents, **10** are reusable subagents and **51** are internal Claude Code prompts
kept for reference and marked `hidden: true` (they won't clutter `@` autocomplete).

---

## Install

OpenCode reads these from a **global** config dir or a **per-project** dir. The folder names
here (`skills/ agents/ commands/ plugins/`) match OpenCode's layout, so installation is a copy.

**Global (available in every project):**

```bash
# copy the contents of this folder into your OpenCode config
cp -r skills   ~/.config/opencode/skills
cp -r agents   ~/.config/opencode/agents
cp -r commands ~/.config/opencode/commands
cp -r plugins  ~/.config/opencode/plugins
```

**Per-project (only inside one repo):**

```bash
mkdir -p /path/to/project/.opencode
cp -r skills agents commands plugins /path/to/project/.opencode/
```

Notes:
- OpenCode also reads skills from `.claude/skills/` and `~/.claude/skills/`, so the `skills/`
  folder is portable between Claude Code and OpenCode.
- Skill `name:` **must match its folder name** (all of these already do).
- Plugins `import type { Plugin } from "@opencode-ai/plugin"`; OpenCode resolves that package
  at runtime. (For local type-checking, `npm i -D @opencode-ai/plugin`.)

---

## Skills

Each skill is `skills/<name>/SKILL.md` with frontmatter OpenCode understands:

```yaml
---
name: artifact-dashboard              # matches the folder
description: Create a dashboard artifact — KPI tiles, ...   # what it does + when to use
metadata:                             # extra context (OpenCode ignores unknown keys)
  source: "skills/skill-artifact-dashboard.md"
  claude_code_version: "2.1.208"
---
```

The model picks a skill based on its `description`, so descriptions are written as
"does X — use when Y". The body is the original instruction text, preserved verbatim.

### Reference libraries (the 4 grouped skills)

The 463 reference fragments (system prompts, reminders, tool docs, data) were **not** turned
into 463 micro-skills — that would flood OpenCode's skill picker and defeat on-demand loading.
Instead they are bundled into four skills, each with the originals under `references/` and an
index table in `SKILL.md`. The model reads the index, then opens only the file(s) it needs:

| Skill | Bundled docs | Covers |
| --- | --- | --- |
| `claude-code-system-prompts` | 133 | Behavioral rules, operating guidelines, mode instructions |
| `claude-code-system-reminders` | 84 | Runtime context notices injected mid-session |
| `claude-code-tool-reference` | 154 | Built-in tool descriptions + tool parameters |
| `claude-code-internals-data` | 92 | Model catalog, API/SDK references, event schemas, platform guides |

---

## Commands (`/<name>`)

Ported from the source `*-slash-command` prompts. Type `/` then the name in OpenCode.

| Command | From |
| --- | --- |
| `/simplify` `/review` `/security-review` `/schedule` `/batch` | `agent/` slash-command prompts |
| `/doctor` `/explain-usage` `/loop` `/stuck` | `skills/` slash-command prompts |

Commands support `$ARGUMENTS` / `$1`, shell injection with `` !`cmd` ``, and file refs with `@file`.
Where a source prompt clearly consumed user input, a trailing `$ARGUMENTS` was appended.

---

## Agents (`@<name>`)

**Reusable subagents** (summon with `@name`):

`explore`, `general-purpose`, `general-purpose-agent`, `general-task-agent`,
`plan-mode-enhanced`, `read-only-search-agent`, `claude-code-guide`, `claude-guide-agent`,
`worker-fork`, `coordinator-worker-instructions`

**Internal / reference agents** (`hidden: true`) — 51 prompts that Claude Code runs
behind the scenes (summarizers, title/branch generators, hook-condition evaluators, memory
attach/consolidation, the `code-review-part-*` fragments, state classifiers, etc.). They're
kept for study; hidden so they don't appear in `@` autocomplete.

Each agent file:

```yaml
---
description: System prompt for the Explore subagent
mode: subagent
# hidden: true        # present only on internal agents
metadata:
  source: "agent/agent-prompt-explore.md"
  claude_code_version: "2.1.118"
---
```

---

## Plugins (auto-loaded)

Educational TypeScript examples showing how event-driven Claude Code behaviors map onto
OpenCode's plugin hooks (signatures taken from `@opencode-ai/plugin`):

| Plugin | Hook(s) | Ports the concept of |
| --- | --- | --- |
| `bash-command-guard.ts` | `tool.execute.before` | Claude Code's *bash command prefix detection* — blocks obvious command-injection patterns before a shell command runs (defensive; tune to your policy) |
| `session-reminder.ts` | `chat.message` | Claude Code's *system reminders* — injects contextual notes into each user message |
| `tool-audit-logger.ts` | `tool.execute.after`, `event` | Claude Code's *hooks / observability* — appends a per-tool-call audit line to `.opencode/tool-audit.log` |

Enable/disable a plugin by adding/removing its file. Each file's header comment names the
source concept it came from.

---

## Optionally: skill permissions

OpenCode can gate which skills the model may use. Example `opencode.json` (or `opencode.jsonc`):

```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "permission": {
    // pattern-based rules: "allow" | "ask" | "deny"
    "skills": {
      "*": "allow",
      "computer-use-mcp": "ask"
    }
  }
}
```

---

## Caveats

- **Template variables.** Many bodies keep Claude Code's `${VARIABLE}` placeholders
  (e.g. `${GLOB_TOOL_NAME}`, `${DIFF_GATHERING_PHASE}`). OpenCode does **not** expand these —
  they render as literal text. Substitute or delete them for your setup where it matters.
- **Claude-Code-specific references.** Prompts mention Claude Code tools/features (Artifact,
  the `Agent` tool, claude.ai, etc.) that don't all exist in OpenCode. They're preserved for
  fidelity; adapt as needed.
- **Not reviewed line-by-line.** This is a bulk, faithful port. Read a file before depending on
  it in a real workflow.

---

## Provenance

Generated from the sibling source folders. Mapping:

| Source | → | Target |
| --- | --- | --- |
| `skills/skill-*.md` (81) | → | 77 `skills/<name>/SKILL.md` + 4 `commands/*.md` |
| `agent/agent-prompt-*.md` (66) | → | 10 reusable + 51 hidden `agents/*.md` + 5 `commands/*.md` |
| `system prompt/` (133) | → | `skills/claude-code-system-prompts/references/` |
| `system reminder/` (84) | → | `skills/claude-code-system-reminders/references/` |
| `tool description/` + `tool parameter/` (154) | → | `skills/claude-code-tool-reference/references/` |
| `data/` (92) | → | `skills/claude-code-internals-data/references/` |
| _(new)_ | → | 3 example `plugins/*.ts` |

Each converted file records its original path under `metadata.source`.
