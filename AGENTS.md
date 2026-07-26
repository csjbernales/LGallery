# AGENTS.md - Workspace Operations Standard & Execution Runtime

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

### C. Safety Checkpointing
- Before performing multi-file refactors or complex script modifications, verify git status (`git status`).
- If working on a dirty working tree, create a temporary stash or commit (`git stash` or `git commit -m "checkpoint before agent edits"`) so changes can be reverted if execution retries fail.

---

## 3. Error Logging & Write-Only Append Execution (PowerShell Protocol)

Whenever a command fails or throws an unhandled error (`$LASTEXITCODE -ne 0`):

```powershell
# Ensure errors directory exists
if (-not (Test-Path -LiteralPath "errors")) { New-Item -ItemType Directory -Path "errors" }

# Append error directly to timestamped log without reading log content
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$logPath = "errors\log_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').txt"
@'
[TIMESTAMP]: $timestamp
[ACTION/COMMAND]: <FAILED_COMMAND_NAME>
[ERROR DETAILS]: <STDERR_OR_ERROR_OUTPUT>
---
'@ | Out-File -FilePath $logPath -Append -Encoding utf8
```
*Note: Do NOT execute `Get-Content` or read operations on `errors\log_*.txt` after writing.*

---

## 4. Definition of Done (Closure Criteria)

A task is considered **COMPLETE** if and only if all of the following conditions are met:

1. **Existence Verification:** All modified/created files exist and `Test-Path -LiteralPath "<FILE_PATH>"` evaluates to `$true`.
2. **Clean Test Execution:** Test commands complete successfully with exit code `$LASTEXITCODE -eq 0`.
3. **Clean Diff Check:** `git diff` shows intended changes without unhandled errors, broken files, or leftover debug logs.
4. **Concrete Evidence:** Output includes the actual `stdout`/`stderr` logs demonstrating passing test suites.

---

## 5. Escalation & Retry Policy

If a command or test suite fails during execution:

* **Attempts 1–3:** Read the execution logs (`stderr`), isolate the error source, log the failure to `errors/`, apply a targeted fix, and re-run the exact verification command.
* **After 3 Failures:** **HALT IMMEDIATELY.** Do not attempt destructive workarounds (e.g., deleting lockfiles, forcing git wipes, or bypassing checks).
* **Reporting:** Output the failing command, paste the final 15 lines of error logs, state the root cause, and request human guidance.

---

## 6. PowerShell Execution Guardrails

* **Non-Interactive Execution:** Append `-Force` and `-Confirm:$false` to avoid hanging interactive shell prompts.
* **Literal Path Safety:** Prefer `-LiteralPath` over `-Path` to prevent wildcard parsing errors on special characters (e.g., `[`, `]`).
* **Log Management:** Avoid token bloat by piping terminal output using `Get-Content -Tail 50` or `Select-Object -First 30`.
* **Syntax Isolation:** NEVER append tool metadata, parameter wrappers (e.g., `"timeout": 60000`, `}}`), or JSON schemas directly onto terminal command strings. Commands passed to shell execution MUST strictly consist of valid PowerShell code.
* **Escape Safety:** NEVER use backslashes (`\`) to escape dollar signs (`\$`) or quotes (`"`) in PowerShell commands. Use single quotes (`'...'`) for string literals or single-quoted Here-Strings (`@' ... '@`) for multiline content.

---

## 7. Context Isolation & Query Handling

* **Intent Boundary Evaluation:** On every user query, evaluate whether it depends on prior session context.
  - **Related Queries:** If the request builds upon past steps, maintain state and apply past execution context.
  - **Unrelated / Independent Queries:** If the user asks a stand-alone or unrelated question, answer it directly without citing, referencing, or dragging in previous context, script paths, or historical logs.

---

## 8. File Structure & Inspection Protocol

* **Content Inspection Before Script Execution:** Prior to creating or running a script on a target file (e.g., `.txt`, `.md`, `.json`), run a preliminary read (`Get-Content -Head 10`) to identify the actual internal schema (e.g., identifying JSON saved inside a `.txt` extension) before selecting processing tools.

---

## 9. Web Research, URL Safety & Browser Protocol

* **Strict No-Guessing Rule:** NEVER construct or invent unverified full URLs (e.g., guessing paths like `/browse/league-of-legends-tournaments`) directly into `WebFetch` or browser navigation commands.
* **Search-First Mandatory Workflow:**
  1. **Step 1 (Search):** If a full, verified URL has not been explicitly provided by the user or returned in previous verified tool outputs, ALWAYS execute a web search query first.
  2. **Step 2 (Verify):** Inspect returned search results to extract real, active URLs.
  3. **Step 3 (Fetch/Navigate):** Pass ONLY the verified, real URLs obtained from Step 2 into `WebFetch` or browser automation tools.
* **Fallback Handling:** If `WebFetch` returns a 404 error, redirect error, or failed request, immediately revert to executing a search query rather than guessing alternative URL paths.
* **Browser Configuration:**
  - **Default Browser Executable:** `C:\Program Files\BraveSoftware\Brave-Browser\Application\brave.exe`
  - **Execution Guardrail:** When launching or opening web pages via shell commands, invoke Brave explicitly using `-LiteralPath` or quoted string:
    ```powershell
    Start-Process -FilePath "C:\Program Files\BraveSoftware\Brave-Browser\Application\brave.exe" -ArgumentList "https://example.com"
    ```