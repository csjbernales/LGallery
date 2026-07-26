# COMPLETE FIX: Read all valid JSON lines and write them fresh

# Get all valid JSON object lines (start with {, exactly one pair of braces)
$validLines = @()

$content = Get-Content "C:\Users\Clark\.config\opencode\testdata.txt"
foreach ($line in $content) {
    # Skip empty lines
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    
    # Split on '{' to handle concatenated objects on same line
    $parts = $line -split '\{'
    foreach ($part in $parts) {
        $trimmed = $part.Trim()
        if ($trimmed.StartsWith('{')) {
            # Count braces to ensure it's a complete object
            $braceCount = ([regex]::Match($trimmed, '[{}]').Matches.Count)
            if ($braceCount -eq 1) {
                $validLines += $trimmed
            }
        }
    }
}

# Write fresh file with only valid JSON lines
$validLines | Set-Content -Path "C:\Users\Clark\.config\opencode\testdata.txt" -Encoding utf8
