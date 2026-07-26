# Parse JSONL and convert to CSV
Add-Type -AssemblyName System.Web

$headers = @()
$data = @()`
$firstLine = $true
$csvPath = "testdata.csv"

while ($line = Get-Content -Path "testdata.txt" -Raw) {
    if (-not $line.Trim() -or $line -eq '{') { continue }
    
    try {
        $obj = [System.Web.HttpUtility]::JsonDeserialize($null, [PSCustomObject], $line)
        foreach ($key in $obj.PSObject.Properties.Name) {
            if (-not $headers.Contains($key)) {
                $headers += $key
            }
        }
        
        if ($firstLine) {
            $data += $obj
            $firstLine = $false
        } else {
            $data += $obj
        }
    } catch {
        Write-Host "Error parsing: $line" -ForegroundColor Red
        break
    }
}

$data | Export-Csv -Path "$csvPath" -NoTypeInformation -Delimiter ",`r\n" -Encoding UTF8