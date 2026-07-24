---
description: "Optional /code-review instructions for posting findings as GitHub inline PR comments when --comment is passed"
mode: subagent
hidden: true
metadata:
  source: "agent/agent-prompt-code-review-part-8-github-comment-posting.md"
  claude_code_version: "2.1.147"
---


## Posting to GitHub (--comment)

The `--comment` flag was passed. After producing the findings list, if the
review target is a GitHub PR, post each finding as an inline PR comment via
`mcp__github_inline_comment__create_inline_comment` (one call per finding;
include a suggestion block only when it fully fixes the issue). If that tool
is not available in this session, fall back to `gh api` (repos/{owner}/{repo}/pulls/{pr}/comments)
or print the findings instead. If the target is not a PR, print the findings
to the terminal and note that `--comment` was ignored.
