param(
    [string]$CsvPath = "C:\Users\cjtucke3\Documents\Personal\Career\Transition_Package\data\nsitemo-meetings.csv",
    [string]$ListName = "Meetings"
)

# Imports rows from a Meetings CSV into the SharePoint Meetings list.
# Skips rows whose Title already exists. Leaves the Program lookup blank
# (manual link or follow-up script after import).
#
# Expected CSV columns (header row required):
#   Title, Cadence, Day and time, Type, PC role, PC responsibilities, Resources
#
# Assumes you have already connected via Connect-PnPOnline before running.

if (-not (Test-Path -LiteralPath $CsvPath)) {
    Write-Host "CSV not found: $CsvPath" -ForegroundColor Red
    exit 1
}

$rows = Import-Csv -LiteralPath $CsvPath
if (-not $rows -or $rows.Count -eq 0) {
    Write-Host "CSV contained no data rows: $CsvPath" -ForegroundColor Yellow
    exit 0
}

# Build a lookup of existing meeting Titles so we can skip duplicates.
$existing = @{}
$existingItems = Get-PnPListItem -List $ListName -Fields "ID","Title"
foreach ($item in $existingItems) {
    $t = $item.FieldValues["Title"]
    if ($t) { $existing[$t.ToLower().Trim()] = $item.Id }
}

$added   = 0
$skipped = 0
$failed  = @()

foreach ($row in $rows) {
    $title = ($row.Title | Out-String).Trim()
    if (-not $title) {
        $failed += [PSCustomObject]@{ Title = "(blank)"; Reason = "Empty Title" }
        continue
    }

    if ($existing.ContainsKey($title.ToLower())) {
        Write-Host "Skipping (already exists): $title" -ForegroundColor Yellow
        $skipped++
        continue
    }

    $values = @{ "Title" = $title }

    # Map CSV columns to SharePoint internal field names.
    # Adjust these if your tenant created columns under different internal names.
    $columnMap = @{
        "Cadence"             = "Cadence"
        "Day and time"        = "DayAndTime"          # actual internal name on this tenant
        "Type"                = "MeetingType"         # actual internal name (avoids reserved 'Type')
        "PC role"             = "PCRole"              # actual internal name
        "PC responsibilities" = "PCResponsibilities"  # actual internal name
        "Resources"           = "Resources"
    }

    foreach ($csvCol in $columnMap.Keys) {
        $value = $row.$csvCol
        if ($null -ne $value) {
            $value = ($value | Out-String).Trim()
            if ($value -ne "") {
                $values[$columnMap[$csvCol]] = $value
            }
        }
    }

    # Note: Program (Lookup -> Programs, internal name 'Program') is intentionally
    # left blank here. Link meetings to programs after import via a follow-up
    # script or manual edit in SharePoint.

    try {
        $newItem = Add-PnPListItem -List $ListName -Values $values -ErrorAction Stop
        Write-Host "Added: $title (ID $($newItem.Id))" -ForegroundColor Green
        $added++
    } catch {
        Write-Host "FAILED to add: $title" -ForegroundColor Red
        Write-Host "  Reason: $($_.Exception.Message)" -ForegroundColor Red
        $failed += [PSCustomObject]@{ Title = $title; Reason = $_.Exception.Message }
    }
}

Write-Host ""
Write-Host "===== Meetings Import Summary =====" -ForegroundColor Cyan
Write-Host "Added:   $added"   -ForegroundColor Green
Write-Host "Skipped: $skipped" -ForegroundColor Yellow
Write-Host "Failed:  $($failed.Count)" -ForegroundColor $(if ($failed.Count -gt 0) { "Red" } else { "Green" })

if ($failed.Count -gt 0) {
    Write-Host ""
    Write-Host "Failed rows:" -ForegroundColor Red
    $failed | Format-Table -AutoSize
}

Write-Host ""
Write-Host "Reminder: Program (Lookup -> Programs) was not set. Link meetings to a Program post-import." -ForegroundColor Cyan
