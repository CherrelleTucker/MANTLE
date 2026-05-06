# Import Stakeholders into the 'Stakeholders' SharePoint List from a CSV.
#
# The CSV is parameterized so this script (which lives in the public repo) does
# not contain real names. Real-name CSVs should live OUTSIDE the public repo
# (default path below points to the private Transition_Package folder).
#
# Assumes:
#   * Connect-PnPOnline -UseWebLogin already run against the target site.
#   * The 'Stakeholders' list already exists with the columns Title, Role,
#     Org / Team, Influence, Interest, RelationshipStatus, Cadence, Notes.
#   * Programs (Lookup) is intentionally NOT populated here; set manually
#     after import.
#
# Idempotent: rows whose Title already exists are skipped.
# Style: matches scripts/populate-equivalency-lookups.ps1 (try/catch + summary).

param(
    [string]$CsvPath = "C:\Users\cjtucke3\Documents\Personal\Career\Transition_Package\data\nsitemo-stakeholders.csv",
    [string]$ListName = "Stakeholders"
)

# ---------------------------------------------------------------------------
# Internal-name map. SharePoint mangles spaces and special chars in internal
# field names. Adjust the right-hand side here if your tenant created the
# fields under different internal names.
# ---------------------------------------------------------------------------
$fieldMap = @{
    Title              = "Title"
    Role               = "Role"
    OrgTeam            = "OrgOrTeam"                       # actual internal name on this tenant
    Influence          = "Influence"
    Interest           = "Interest"
    RelationshipStatus = "RelationshipStatus"              # actual internal name on this tenant
    Cadence            = "Cadence"
    Notes              = "Notes"
}

# Allowed Choice values per the schema. Anything not in these sets falls back
# to the documented default and is logged.
$influenceChoices = @("High","Medium","Low")
$interestChoices  = @("High","Medium","Low")
$statusChoices    = @("Strong","Neutral","Strained","Unknown")
$cadenceChoices   = @("Weekly","Bi-weekly","Monthly","Quarterly","Ad hoc")

function Resolve-Choice {
    param(
        [string]$Value,
        [string[]]$Allowed,
        [string]$Default,
        [string]$FieldName,
        [string]$RowTitle
    )
    if (-not $Value) { return $Default }
    $trimmed = $Value.Trim()
    foreach ($a in $Allowed) {
        if ($a.Equals($trimmed, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $a
        }
    }
    Write-Host ("  WARNING: '{0}' is not a valid {1} value for '{2}'. Defaulting to '{3}'." -f $trimmed, $FieldName, $RowTitle, $Default) -ForegroundColor Yellow
    return $Default
}

# ---------------------------------------------------------------------------
# Verify list exists.
# ---------------------------------------------------------------------------
try {
    $list = Get-PnPList -Identity $ListName -ErrorAction Stop
    Write-Host ("Target list found: {0}" -f $ListName) -ForegroundColor Cyan
} catch {
    Write-Host ("ERROR: list '{0}' not found on this site. Aborting." -f $ListName) -ForegroundColor Red
    return
}

# ---------------------------------------------------------------------------
# Verify CSV exists and load it.
# ---------------------------------------------------------------------------
if (-not (Test-Path -LiteralPath $CsvPath)) {
    Write-Host ("ERROR: CSV not found at '{0}'. Aborting." -f $CsvPath) -ForegroundColor Red
    return
}

try {
    $rows = Import-Csv -Path $CsvPath -Encoding UTF8
} catch {
    Write-Host ("ERROR: failed to read CSV: {0}" -f $_.Exception.Message) -ForegroundColor Red
    return
}

Write-Host ("Loaded {0} row(s) from {1}" -f $rows.Count, $CsvPath) -ForegroundColor Cyan

# ---------------------------------------------------------------------------
# Pre-load existing Titles so duplicate detection is one round-trip, not N.
# ---------------------------------------------------------------------------
$existingTitles = @{}
try {
    $existing = Get-PnPListItem -List $ListName -Fields "Title" -PageSize 500
    foreach ($e in $existing) {
        $t = $e.FieldValues["Title"]
        if ($t) { $existingTitles[$t.ToLower().Trim()] = $true }
    }
    Write-Host ("Found {0} existing Stakeholder(s) in the list." -f $existingTitles.Count) -ForegroundColor DarkGray
} catch {
    Write-Host ("WARNING: could not pre-load existing items ({0}). Will rely on per-row checks instead." -f $_.Exception.Message) -ForegroundColor Yellow
}

# ---------------------------------------------------------------------------
# Import loop.
# ---------------------------------------------------------------------------
$imported = 0
$skipped  = 0
$failed   = @()

foreach ($row in $rows) {
    $title = if ($row.Title) { $row.Title.Trim() } else { "" }
    if (-not $title) {
        $failed += [PSCustomObject]@{ Title = "(blank)"; Reason = "Empty Title column" }
        continue
    }

    $key = $title.ToLower()
    if ($existingTitles.ContainsKey($key)) {
        Write-Host ("Skipping '{0}' (already exists)." -f $title) -ForegroundColor Yellow
        $skipped++
        continue
    }

    $role      = if ($row.Role) { $row.Role.Trim() } else { "" }
    $orgTeam   = if ($row.'Org or Team') { $row.'Org or Team'.Trim() } else { "" }
    $notes     = if ($row.Notes) { $row.Notes } else { "" }

    $influence = Resolve-Choice -Value $row.Influence            -Allowed $influenceChoices -Default "Medium"  -FieldName "Influence"            -RowTitle $title
    $interest  = Resolve-Choice -Value $row.Interest             -Allowed $interestChoices  -Default "Medium"  -FieldName "Interest"             -RowTitle $title
    $relStatus = Resolve-Choice -Value $row.'Relationship status' -Allowed $statusChoices    -Default "Unknown" -FieldName "Relationship status" -RowTitle $title
    $cadence   = Resolve-Choice -Value $row.Cadence              -Allowed $cadenceChoices   -Default "Ad hoc"  -FieldName "Cadence"              -RowTitle $title

    $values = @{
        $fieldMap.Title              = $title
        $fieldMap.Role               = $role
        $fieldMap.OrgTeam            = $orgTeam
        $fieldMap.Influence          = $influence
        $fieldMap.Interest           = $interest
        $fieldMap.RelationshipStatus = $relStatus
        $fieldMap.Cadence            = $cadence
        $fieldMap.Notes              = $notes
    }

    try {
        Add-PnPListItem -List $ListName -Values $values -ErrorAction Stop | Out-Null
        Write-Host ("Imported: {0}" -f $title) -ForegroundColor Green
        $existingTitles[$key] = $true
        $imported++
    } catch {
        Write-Host ("FAILED '{0}': {1}" -f $title, $_.Exception.Message) -ForegroundColor Red
        $failed += [PSCustomObject]@{ Title = $title; Reason = $_.Exception.Message }
    }
}

# ---------------------------------------------------------------------------
# Summary.
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "==================== SUMMARY ====================" -ForegroundColor Cyan
Write-Host ("Imported ({0})" -f $imported) -ForegroundColor Green
Write-Host ("Skipped  ({0})" -f $skipped)  -ForegroundColor Yellow
if ($failed.Count -gt 0) {
    Write-Host ("Failed   ({0}):" -f $failed.Count) -ForegroundColor Red
    $failed | Format-Table -AutoSize
} else {
    Write-Host "Failed   (0): none" -ForegroundColor Green
}
Write-Host "================================================="
Write-Host ""
Write-Host "NOTE: 'Programs' lookup column was intentionally not set." -ForegroundColor DarkGray
Write-Host "      Populate Programs manually in the SharePoint UI after import." -ForegroundColor DarkGray
