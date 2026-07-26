$headers = [System.Collections.Generic.HashSet[string]]::new()
$data = @()
$txtPath = "testdata.txt"

if (Test-Path $txtPath) {
    # Read line-by-line using Get-Content (without -Raw)
    Get-Content -Path $txtPath | ForEach-Object {
        $line = $_.Trim()
        
        # Skip empty lines or stray braces
        if (-not $line -or $line -eq '{' -or $line -eq '}') { return }

        try {
            # Standard PowerShell cmdlet to parse JSON strings
            $obj = $line | ConvertFrom-Json

            # Collect unique property names for headers
            foreach ($prop in $obj.PSObject.Properties) {
                [void]$headers.Add($prop.Name)
            }

            $data += $obj
        }
        catch {
            Write-Host "Error parsing line: $line" -ForegroundColor Red
            Write-Host $_.Exception.Message -ForegroundColor Yellow
        }
    }

    Write-Host "Parsed $($data.Count) entries with $($headers.Count) headers" -ForegroundColor Green
    Write-Host "Headers: $($headers -join ', ')"

    # TODO: Export to CSV or process further
    # $data | Export-Csv -Path "testdata.csv" -NoTypeInformation
}
else {
    Write-Host "File not found: $txtPath" -ForegroundColor Red
}