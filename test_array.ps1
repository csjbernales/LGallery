# More test
$myArray = @()
$flag = $true
foreach ($i in 1..3) {
    if ($flag) {
        $myArray += $i
        $flag = $false
    }
}
Write-Host "Array: $($myArray -join ',')" -ForegroundColor Green
