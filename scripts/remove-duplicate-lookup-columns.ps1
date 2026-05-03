$columnsToRemove = @("FromToolLookup", "ToToolLookup")
$removed = 0
$failed = @()

foreach ($col in $columnsToRemove) {
    try {
        Remove-PnPField -List "Equivalency Map Real" -Identity $col -Force -ErrorAction Stop
        Write-Host "Removed: $col" -ForegroundColor Green
        $removed++
    } catch {
        Write-Host "Failed to remove $col -- $($_.Exception.Message)" -ForegroundColor Red
        $failed += $col
    }
}

Write-Host ""
Write-Host "Removed: $removed - Failed: $($failed.Count)" -ForegroundColor Cyan
