# Import Acronyms from CSV into the SharePoint Acronyms list.
#
# Usage:
#   Connect-PnPOnline -Url <site-url> -Interactive
#   .\import-acronyms-from-csv.ps1 -CsvPath C:\path\to\nasa-acronyms.csv
#
# CSV columns (header row required):
#   Title,Expansion,Context,Programs,Source,Notes
#
# - Title (Acronym) is the unique key. Existing rows with the same Title are skipped.
# - Programs column is currently ignored on import (Lookup column - set manually later).
# - Context must be one of: Agency, Center, Program, Project, Industry. Blank is allowed.

[CmdletBinding()]
param(
    [string]$CsvPath = "C:\Users\cjtucke3\Documents\Personal\Career\Transition_Package\data\nasa-acronyms.csv",
    [string]$ListName = "Acronyms"
)

if (-not (Test-Path -LiteralPath $CsvPath)) {
    Write-Host "CSV not found: $CsvPath" -ForegroundColor Red
    exit 1
}

$rows = Import-Csv -LiteralPath $CsvPath
if (-not $rows -or $rows.Count -eq 0) {
    Write-Host "CSV has no rows: $CsvPath" -ForegroundColor Yellow
    exit 0
}

Write-Host "Loaded $($rows.Count) rows from $CsvPath"

# Build a lookup of existing Titles to make the script idempotent.
$existing = Get-PnPListItem -List $ListName -Fields "ID","Title" -PageSize 2000
$existingTitles = @{}
foreach ($item in $existing) {
    $t = $item.FieldValues["Title"]
    if ($t) { $existingTitles[$t.ToString().ToLower().Trim()] = $item.Id }
}

Write-Host "Found $($existingTitles.Count) existing acronyms in list '$ListName'"

$validContexts = @("Agency", "Center", "Program", "Project", "Industry")

$created = 0
$skipped = 0
$failed  = @()

foreach ($row in $rows) {
    $title = $null
    if ($row.Title) { $title = $row.Title.ToString().Trim() }
    if (-not $title) {
        $failed += [PSCustomObject]@{ Title = "(blank)"; Reason = "Title is empty" }
        continue
    }

    $key = $title.ToLower()
    if ($existingTitles.ContainsKey($key)) {
        $skipped++
        continue
    }

    $values = @{ Title = $title }

    if ($row.Expansion) {
        $exp = $row.Expansion.ToString().Trim()
        if ($exp) { $values["Expansion"] = $exp }
    }

    if ($row.Context) {
        $ctx = $row.Context.ToString().Trim()
        if ($ctx) {
            if ($validContexts -contains $ctx) {
                $values["AcronymContext"] = $ctx
            } else {
                $failed += [PSCustomObject]@{ Title = $title; Reason = "Invalid Context value '$ctx'" }
                continue
            }
        }
    }

    if ($row.Source) {
        $src = $row.Source.ToString().Trim()
        if ($src) { $values["Source"] = $src }
    }

    if ($row.Notes) {
        $notes = $row.Notes.ToString().Trim()
        if ($notes) { $values["Notes"] = $notes }
    }

    try {
        Add-PnPListItem -List $ListName -Values $values | Out-Null
        $existingTitles[$key] = -1
        $created++
    } catch {
        $failed += [PSCustomObject]@{ Title = $title; Reason = $_.Exception.Message }
    }
}

Write-Host ""
Write-Host "Created: $created" -ForegroundColor Green
Write-Host "Skipped (already present): $skipped" -ForegroundColor Yellow
if ($failed.Count -gt 0) {
    Write-Host "Failed: $($failed.Count)" -ForegroundColor Red
    $failed | Format-Table -AutoSize
} else {
    Write-Host "Failed: 0" -ForegroundColor Green
}
