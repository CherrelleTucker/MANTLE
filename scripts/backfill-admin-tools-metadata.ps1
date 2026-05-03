$toolsToBackfill = @(
    @{ Title = "Google Workspace Admin"; Category = "Identity"; Vendor = "Google"; Description = "Admin console for managing Google Workspace users, groups, licenses, and settings." },
    @{ Title = "M365 Admin Center"; Category = "Identity"; Vendor = "Microsoft"; Description = "Microsoft 365 admin portal for managing users, groups, licenses, and core services." },
    @{ Title = "Google Groups"; Category = "Identity"; Vendor = "Google"; Description = "Mailing lists, shared inboxes, and group permissions in Google Workspace." },
    @{ Title = "Microsoft 365 Groups"; Category = "Identity"; Vendor = "Microsoft"; Description = "M365 group construct combining shared mailbox, calendar, SharePoint site, Teams team, and Planner." }
)

$updated = 0
$failed = @()

foreach ($t in $toolsToBackfill) {
    $existing = Get-PnPListItem -List "Tools" -Query "<View><Query><Where><Eq><FieldRef Name='Title'/><Value Type='Text'>$($t.Title)</Value></Eq></Where></Query></View>"
    if (-not $existing) {
        Write-Host "Not found: $($t.Title)" -ForegroundColor Red
        $failed += $t.Title
        continue
    }
    try {
        Set-PnPListItem -List "Tools" -Identity $existing.Id -Values @{
            "field_1" = $t.Category
            "field_2" = $t.Vendor
            "field_3" = $t.Description
        } -ErrorAction Stop | Out-Null
        Write-Host "Backfilled: $($t.Title)" -ForegroundColor Green
        $updated++
    } catch {
        Write-Host "FAILED: $($t.Title) -- $($_.Exception.Message)" -ForegroundColor Red
        $failed += $t.Title
    }
}

Write-Host ""
Write-Host "Backfilled: $updated | Failed: $($failed.Count)" -ForegroundColor Cyan
