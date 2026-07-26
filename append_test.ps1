# Append test lines to testdata.txt
Write-Host "Appending test data..."
`" | Out-File -FilePath "C:\Users\Clark\.config\opencode\testdata.txt" -Append
{"test":"empty_line_skipped","ok":true} | Out-File -FilePath "C:\Users\Clark\.config\opencode\testdata.txt" -Append
{"special":"newlineandtab",¡²}" | Out-File -FilePath "C:\Users\Clark\.config\opencode\testdata.txt" -Append
