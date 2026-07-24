# AGENTS.md - Workspace Operations Standard

## 1. Environment & Setup Commands

Execute these commands on session initialization to establish workspace context:

| Purpose | Command | Verification Criteria |
|---|---|---|
| Active Directory | `Get-Location` | Path returned |
| Workspace State | `git status --short` | Exit status `$LASTEXITCODE -eq 0` |
| Node Environment | `node -v` | Output version string |
| Python Environment | `python --version` | Output version string |

---

## 2. Task-Organized Workflows

### A. Code Modification & File Operations

When creating or editing codebase files, always verify filesystem updates immediately:

```powershell
# Write file using explicit UTF-8 encoding
Set-Content -LiteralPath "<FILE_PATH>" -Value "<CONTENT>" -Encoding utf8

# Verify file presence and inspect output
Test-Path -LiteralPath "<FILE_PATH>"
Get-Content -LiteralPath "<FILE_PATH>" -Tail 20
```

### B. Testing & Validation Loop

Execute local verification suites after any code changes:

```powershell
# Run project test suite
npm test # OR python: pytest

# Verify command execution status
$LASTEXITCODE
```

---

## 3. Definition of Done (Closure Criteria)

A task is considered **COMPLETE** if and only if all of the following conditions are met:

1. **Existence Verification:** All modified/created files exist and `Test-Path -LiteralPath "<FILE_PATH>"` evaluates to `$true`.
2. **Clean Test Execution:** Test commands complete successfully with exit code `$LASTEXITCODE -eq 0`.
3. **Clean Diff Check:** `git diff` shows intended changes without unhandled errors, broken files, or leftover debug logs.
4. **Concrete Evidence:** Output includes the actual `stdout`/`stderr` logs demonstrating passing test suites.

---

## 4. Escalation & Retry Policy

If a command or test suite fails during execution:

* **Attempts 1–3:** Read the execution logs (`stderr`), isolate the error source, apply a targeted fix, and re-run the exact verification command.
* **After 3 Failures:** **HALT IMMEDIATELY.** Do not attempt destructive workarounds (e.g., deleting lockfiles, forcing git wipes, or bypassing checks).
* **Reporting:** Output the failing command, paste the final 15 lines of error logs, state the root cause, and request human guidance.

---

## 5. PowerShell Execution Guardrails

* **Non-Interactive Execution:** Append `-Force` and `-Confirm:$false` to avoid hanging interactive shell prompts.
* **Literal Path Safety:** Prefer `-LiteralPath` over `-Path` to prevent wildcard parsing errors on special characters (e.g., `[`, `]`).
* **Log Management:** Avoid token bloat by piping terminal output using `Get-Content -Tail 50` or `Select-Object -First 30`.