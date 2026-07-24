---
name: code-review-output-findings-json-array
description: "Defines the code-review skill's result shape: a JSON array of findings carrying file, line, summary, and failure_scenario"
metadata:
  source: "skills/skill-code-review-output-findings-json-array.md"
  claude_code_version: "2.1.216"
---
## Output

Return findings as a JSON array of at most ${MAX_FINDINGS} objects:

```json
[
  {
    "file": "path/to/file.ext",
    "line": 123,
    "summary": "one-sentence statement of the bug",
    "failure_scenario": "concrete inputs/state → wrong output/crash"
  }
]
```

Ranked most-severe first. If more than ${MAX_FINDINGS} survive, keep the ${MAX_FINDINGS} most
severe. If nothing survives verification, return `[]`. Do not call the
${REPORT_FINDINGS_TOOL_NAME} tool even if it is available - this review's
output contract is the JSON block above.
