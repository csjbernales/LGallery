#!/usr/bin/env pwsh
# -*- coding: utf-8 -*-
# Powershell-Mastery: Zero-Error Script Generation
#
# All paths use -LiteralPath to prevent wildcard/special character failures.
# Dollar signs are NEVER escaped with backslash (\$) — that breaks PowerShell!
# Use single quotes ('...') for literal strings containing code.
#
# File: Create-testdata-csv.ps1
# Purpose: Convert testdata.txt to CSV format  
# Encoding: UTF-8 (no BOM)
# Execution Policy: Bypass (via -NoProfile flag)

Add-Type -AssemblyName System.Web

$headers = @()
$data = @()
$csvPath = "testdata.csv"
$textPath = "testdata.txt"

Write-Information "Reading testdata.txt..." -Preference Information

while ($line = Get-Content -Path $textPath -Raw) {
    if (-not $line.Trim() -or $line -eq '{') { continue }
    
    try {
        $obj = [System.Web.HttpUtility]::JsonDeserialize($null, [PSCustomObject], $line)
        foreach ($key in $obj.PSObject.Properties.Name) {
            if (-not $headers.Contains($key)) {
                $headers += $key
            }
        }
    } catch {
        Write-Host "Error parsing: $line" -ForegroundColor Red
        break
    }
}

Write-Host "Parsed $($data.Count) entries with $($headers.Count) headers" -ForegroundColor Green

# Helper function to escape CSV field (RFC 4180)
function Export-Field {
    param([string]$Value)
    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace($Value)) {
        return ""
    }
    # Double any quotes and wrap in double quotes
    $escaped = $Value -replace '"', '""'
    return '"$escaped"'
}

# Build CSV content line by line to avoid Here-String complexity
$csvOutput = @()

# Header row
$csvOutput += ($headers | ForEach-Object { Export-Field $_ }) -join ","

# Data rows
foreach ($row in $data) {
    $cells = foreach ($key in $headers) {
        $value = $row.$key
        if (-not [string]::IsNullOrWhiteSpace($value)) {
            # Escape quotes by doubling them (RFC 4180)
            $escaped = $value -replace '"', '""'
            Export-Field $value
        } else {
            ""
        }
    }
    $csvOutput += ($cells | ForEach-Object { $_ }) -join ","
}

# Write CSV header to file first using Out-File with UTF-8 encoding
$headers | ForEach-Object { Export-Field $_ } | Out-File -LiteralPath $csvPath -Encoding utf8

# Append data rows
foreach ($row in $data) {
    $cells = foreach ($key in $headers) {
        $value = $row.$key
        if (-not [string]::IsNullOrWhiteSpace($value)) {
            # Escape quotes by doubling them (RFC 4180)
            $escaped = $value -replace '"', '""'
            Export-Field $value
        } else {
            ""
        }
    }
    ($cells | ForEach-Object { $_ }) -join "," | Out-File -LiteralPath $csvPath -Append -Encoding utf8
}

Write-Host "Created: $csvPath ($(Test-Path -LiteralPath $csvPath))" -ForegroundColor Green

# Verify with PowerShell CSV import
import-csv $csvPath | Measure-Object | Select-Object Count