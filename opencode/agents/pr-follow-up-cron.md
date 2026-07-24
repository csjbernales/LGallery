---
description: "Cron prompt for checking a pull request created in the session and fixing failures, comments, or conflicts"
mode: subagent
hidden: true
metadata:
  source: "agent/agent-prompt-pr-follow-up-cron.md"
  claude_code_version: "2.1.173"
---
${PR_INSTRUCTIONS_PREFIX}${PR_GENERATED_WITH_CLAUDE_CODE} (created in this session). Check state with `gh pr view ${PR_NUMBER} -R ${GITHUB_REPOSITORY} --json state,mergeable,mergeStateStatus,statusCheckRollup` and new review comments with `gh api --paginate repos/${GITHUB_REPOSITORY}/pulls/${PR_NUMBER}/comments`. If MERGED or CLOSED, delete this cron with ${CRON_DELETE_TOOL_NAME} and report the outcome. If CI is failing, comments are unaddressed, or there are merge conflicts, fix and push.${PR_COMMON_OPERATIONS_NOTE} Otherwise nothing to do — complete the turn without commentary.
