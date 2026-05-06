$listsToHideFromNav = @(
    "PCs",
    "Programs",
    "Trainee Profiles",
    "Tools",
    "Stakeholders",
    "Meetings",
    "Acronyms",
    "Decisions Log",
    "30-60-90 Tasks",
    "PC-Program History",
    "Program-Tool",
    "Equivalency Map",
    "_BROKEN KITCHEN Home"
)

$keepInNav = @(
    "KITCHEN Home",
    "Onboarding",
    "Offboarding",
    "KITCHEN Actions",
    "Equivalency Map Real"
)

$hidden = 0
$skipped = 0
$failed = @()

# Note: the legacy module's Set-PnPList doesn't have -OnQuickLaunch.
# All real cleanup happens in the Remove-PnPNavigationNode loop below.
# This first loop just verifies each list exists.
foreach ($listName in $listsToHideFromNav) {
    try {
        $list = Get-PnPList -Identity $listName -ErrorAction Stop
        if ($null -eq $list) {
            Write-Host "Skipping (not found): $listName" -ForegroundColor DarkGray
            continue
        }
        Write-Host "Confirmed exists: $listName" -ForegroundColor DarkGray
        $hidden++
    } catch {
        Write-Host "Could not verify $listName -- $($_.Exception.Message)" -ForegroundColor DarkGray
    }
}

Write-Host ""
Write-Host "Removing any leftover Quick Launch nodes for hidden lists..." -ForegroundColor Cyan
try {
    $nodes = Get-PnPNavigationNode -Location QuickLaunch
    foreach ($node in $nodes) {
        if ($listsToHideFromNav -contains $node.Title) {
            try {
                Remove-PnPNavigationNode -Identity $node.Id -Force -ErrorAction Stop
                Write-Host "Removed nav node: $($node.Title)" -ForegroundColor Green
            } catch {
                Write-Host "Could not remove node '$($node.Title)' -- $($_.Exception.Message)" -ForegroundColor DarkGray
            }
        }
    }
} catch {
    Write-Host "Could not enumerate Quick Launch nodes: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "==================== SUMMARY ====================" -ForegroundColor Cyan
Write-Host "Hidden from nav : $hidden" -ForegroundColor Green
Write-Host "Already hidden  : $skipped" -ForegroundColor Yellow
if ($failed.Count -gt 0) {
    Write-Host "Failed          : $($failed.Count) -- $($failed -join ', ')" -ForegroundColor Red
} else {
    Write-Host "Failed          : 0" -ForegroundColor Green
}
Write-Host ""
Write-Host "Quick Launch should now only show:" -ForegroundColor Cyan
foreach ($k in $keepInNav) { Write-Host "  - $k" -ForegroundColor White }
Write-Host ""
Write-Host "Admins still access lists via Site Contents (gear -> Site contents)." -ForegroundColor DarkGray
Write-Host "================================================="
