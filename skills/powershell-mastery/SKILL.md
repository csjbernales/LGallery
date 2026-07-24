---
name: powershell-mastery
description: Enforces robust, zero-error PowerShell script generation, path safety, encoding standards, escaping rules, and command execution guardrails.
---

# POWERSHELL MASTERY & ZERO-ERROR SCRIPTING SKILL

## 1. Core Rule: Zero Execution Errors
When generating `.ps1` files or inline PowerShell terminal commands, you MUST adhere to strict syntactic and structural rules. Never write scripts that fail due to missing execution policies, unsafe quoting, invalid object handling, unescaped path variables, or missing UTF-8 encodings.

---

## 2. Mandatory PowerShell Scripting Guardrails

### A. String Quoting & Variable Escaping Standard (Prevents Parser Errors)
PowerShell does **NOT** use the backslash (`\`) to escape dollar signs (`$`). Using `\$Variable` in double-quoted strings results in broken scripts, unhandled empty variables, and `ParserError: Unexpected token`.

* **RULE 1: Use Single-Quoted Here-Strings for Multiline Code Generation**
  When creating or updating `.ps1` files, ALWAYS wrap code in single-quoted Here-Strings (`@' ... '@`). Single quotes prevent PowerShell from expanding `$variables`, eliminating the need to escape them.

```powershell
# CORRECT: Multi-line file creation using single-quoted Here-String
$scriptContent = @'
function ExtractFrontmatter {
    param([string]$Content, [string]$Filename)
    $title = 'Skill'
    return $title
}
'@

Set-Content -LiteralPath 'Convert-Skills.ps1' -Value $scriptContent -Encoding utf8
```

* **RULE 2: Use Single Quotes (`'...'`) for Inline Values**
  Treat string literals containing code or commands as literal blocks by wrapping them in single quotes.

* **RULE 3: Use Backticks (`` ` ``) for Escaping in Double Quotes**
  If double quotes (`"..."`) are required, escape variable dollars with a backtick (``` `$Variable ```), **NEVER** a backslash (`\$Variable`).

---

### B. Non-Interactive Guardrail (Prevents Script Hangs)
All script executions and CLI invocations MUST be strictly non-interactive:
* **Execution Policy Bypass:** Always invoke scripts using `powershell.exe -NoProfile -ExecutionPolicy Bypass -File "script.ps1"`.
* **Prompt Suppression:** Append `-Force`, `-Confirm:$false`, and `-Quiet` to all destructive or interactive cmdlets (`Remove-Item`, `Copy-Item`, `Stop-Process`).

---

### C. Universal Path Safety (`-LiteralPath`)
Wildcards and special characters (like `[`, `]`, `$`, spaces) cause silent failures or syntax errors when using standard `-Path`.
* **RULE:** ALWAYS use `-LiteralPath` instead of `-Path` for standard file operations.

```powershell
# WRONG (Fails if path contains brackets or special characters)
Get-Content -Path "C:\Data\[2026]\config.json"

# CORRECT (Path-safe)
Get-Content -LiteralPath "C:\Data\[2026]\config.json"
```

---

### D. Explicit Encoding Standard (Fixes Syntax & Token Errors)
By default, Windows PowerShell 5.1 writes files in UTF-16, which breaks many developer tools and LLM parser loops.
* **RULE:** ALWAYS specify explicit UTF-8 encoding when writing or reading text files.

```powershell
# Write file safely in UTF-8 (No BOM)
Set-Content -LiteralPath "build.ps1" -Value '$ErrorActionPreference = "Stop"' -Encoding utf8
```

---

## 3. Standard `.ps1` Template Architecture
Every created `.ps1` file MUST follow this structural boilerplate to guarantee clean error bubbling and exit code tracking.

```powershell
# Requires -Version 5.1
<#
.SYNOPSIS
    Production-grade robust script template.
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [string]$TargetDirectory = $PWD.Path
)

# Force script to halt immediately on the first error
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

# Enable native UTF-8 output streams
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

try {
    Write-Information "Executing script logic..."

    # Ensure path exists safely
    if (-not (Test-Path -LiteralPath $TargetDirectory)) {
        throw "Target directory does not exist: $TargetDirectory"
    }

    # Core Execution Body
    Get-ChildItem -LiteralPath $TargetDirectory -File | ForEach-Object {
        Write-Verbose "Processing file: $($_.Name)"
    }

    # Explicit Zero Exit Code on Success
    exit 0
}
catch {
    Write-Error "Script execution failed: $_"
    # Ensure non-zero exit code is returned to terminal/LLM caller
    exit 1
}
```

---

## 4. Common Pitfall Reference & Correct Patterns

### Pitfall 1: Incorrect Variable Escaping (`\$Var`)
PowerShell treats `\$Var` as a literal backslash followed by an expanded `$Var`.
* **Fix:** Use single quotes (`'$Var'`), backticks (``` `$Var ```), or single-quoted Here-Strings (`@'...'@`).

### Pitfall 2: Mixing Native Shell Aliases in `.ps1` Files
Aliases like `curl`, `wget`, `ls`, `rm`, `cat`, and `grep` behave differently in PowerShell than in Linux Bash or standard CMD.
* **Fix:** Use full cmdlet names inside `.ps1` scripts.

| Dangerous Alias | Replacement Cmdlet |
|---|---|
| `curl` / `wget` | `Invoke-WebRequest` / `Invoke-RestMethod` |
| `cat` | `Get-Content -Raw -LiteralPath` |
| `rm` | `Remove-Item -Force -LiteralPath` |
| `cp` | `Copy-Item -LiteralPath` |
| `mv` | `Move-Item -LiteralPath` |
| `grep` | `Select-String -Pattern` |

### Pitfall 3: String Formatting & Variable Scoping Errors
Unescaped variable expansion inside double quotes causes syntax crashes or unhandled empty strings.

```powershell
# WRONG: Evaluates variable inline without proper delimiter
Write-Host "File $file.txt processing"

# CORRECT: Use sub-expression operator $() or single quotes for literals
Write-Host "File $($file.Name) processing"
Write-Host 'Literal string without $variable expansion'
```

### Pitfall 4: Failing External Native Commands (`git`, `npm`, `python`)
PowerShell's `$ErrorActionPreference = 'Stop'` does NOT automatically catch errors from external non-PowerShell executables.
* **Fix:** Check `$LASTEXITCODE` explicitly after running native binaries.

```powershell
# Execute external CLI tool
& npm run build

# Check native binary exit code
if ($LASTEXITCODE -ne 0) {
    throw "Build failed with exit code $LASTEXITCODE"
}
```

---

## 5. Verification Checklist (Run Before Submitting `.ps1` File)

Before writing or executing any `.ps1` script, verify:
- [ ] No backslash escaping used on dollar signs (`\$Var`).
- [ ] Multiline code strings use `@' ... '@` (single-quoted Here-Strings).
- [ ] Script includes `$ErrorActionPreference = 'Stop'`.
- [ ] Try/Catch block catches exceptions and exits with non-zero status (`exit 1`).
- [ ] All filesystem paths use `-LiteralPath`.
- [ ] All `Set-Content` / `Out-File` operations specify `-Encoding utf8`.
- [ ] External commands check `$LASTEXITCODE`.
- [ ] Native cmdlet names are used instead of Linux/Bash aliases.