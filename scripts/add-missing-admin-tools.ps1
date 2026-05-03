$missingTools = @(
    "Google Workspace Admin",
    "M365 Admin Center",
    "Google Groups",
    "Microsoft 365 Groups"
)

$added = 0
$skipped = 0
$failed = @()

foreach ($title in $missingTools) {
    $existing = Get-PnPListItem -List "Tools" -Query "<View><Query><Where><Eq><FieldRef Name='Title'/><Value Type='Text'>$title</Value></Eq></Where></Query></View>"
    if ($existing) {
        Write-Host "Skipping (already exists): $title" -ForegroundColor Yellow
        $skipped++
        continue
    }

    try {
        $item = Add-PnPListItem -List "Tools" -Values @{ "Title" = $title } -ErrorAction Stop
        Write-Host "Added: $title (ID $($item.Id))" -ForegroundColor Green
        $added++
    } catch {
        Write-Host "FAILED to add: $title" -ForegroundColor Red
        Write-Host "  Reason: $($_.Exception.Message)" -ForegroundColor Red
        $failed += $title
    }
}

Write-Host ""
Write-Host "Added: $added | Skipped: $skipped | Failed: $($failed.Count)" -ForegroundColor Cyan
