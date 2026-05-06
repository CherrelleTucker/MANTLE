# Import Working Styles Matrix data into existing Stakeholders rows.
#
# CONTRACT:
#   * NEVER touches Title (Contact Name) or Person columns -- those are
#     already populated by the owner and must be preserved.
#   * NEVER deletes rows.
#   * For each Excel matrix row (row 3+):
#       - Skip if Team Member cell is blank.
#       - Skip if Team Member is "Jordan" (per owner instruction).
#       - Find the existing Stakeholders row whose Title STARTS WITH the
#         matrix first name (case-insensitive) AND has Person populated.
#       - 0 matches -> log and skip.
#       - 1 match   -> update ONLY the working-style fields with non-blank
#                      values from Excel.
#       - 2+ matches -> log conflict and skip.
#   * For each field: only write the value if the Excel cell is non-blank.
#     Blank cells leave the existing value untouched.
#   * Strips smart quotes ("curly" quotes/apostrophes) from cell values to
#     match SharePoint Choice options that use straight ASCII quotes.
#
# Maps Excel columns by HEADER NAME (Excel row 2), not by index. If Excel
# columns ever shift, the script still finds each value by its question text.
#
# Module: legacy SharePointPnPPowerShellOnline (Windows PowerShell 5.1).
# Assumes: Connect-PnPOnline -UseWebLogin already done.

param(
    [string]$Path = "c:\Users\cjtucke3\Downloads\Working Styles Matrix.xlsx",
    [string]$ListName = "Stakeholders"
)

# ===========================================================================
# Excel header text -> SharePoint internal name
#
# The Excel headers in row 2 are the question text. This map keys on
# substring fragments of that text (case-insensitive contains-match) so we
# don't break if Excel headers get tiny edits like added punctuation.
# ===========================================================================
$headerToInternal = [ordered]@{
    "team member"                          = "__SKIP_TITLE__"   # never write
    "primary prefered channel"             = "PreferredChannel"
    "primary preferred channel"            = "PreferredChannel"
    "secondary prefered channel"           = "SecondaryChannel"
    "secondary preferred channel"          = "SecondaryChannel"
    "leave your edits"                     = "EditsLeaveStyle2"
    "others to leave shared file edits"    = "EditsReceiveStyle2"
    "receiving information and making a decision" = "DecisionTimingSelf2"
    "willing to wait for their responses"  = "DecisionTimingOthers2"
    "framed"                               = "DecisionFormat"
    "working day start"                    = "WorkingHoursStart"
    "working day end"                      = "WorkingHoursEnd"
    "prefer to attend meetings"            = "MeetingTimePreference"
    "deep work that requires thought"      = "DeepWorkStyle2"
    "included in others' work"             = "InclusionPreference2"
    "status update cadence"                = "StatusUpdateCadence"
    "process new information"              = "ProcessingStyle"
    "type of thinker"                      = "ThinkerType2"
    "rabbit trails"                        = "RabbitTrails"
    "overthinker"                          = "Overthinker"
    "recieve corrective feedback"          = "ReceiveFeedback2"
    "receive corrective feedback"          = "ReceiveFeedback2"
    "give corrective feedback"             = "GiveFeedback2"
    "receive recognition"                  = "ReceiveRecognition2"
    "give recognition"                     = "GiveRecognition2"
    "default first move"                   = "ConflictDefault"
    "additional comments"                  = "WorkingStyleComments"
}

$multiChoiceFields = @(
    "EditsLeaveStyle2",
    "EditsReceiveStyle2",
    "ThinkerType2",
    "ReceiveFeedback2",
    "GiveFeedback2",
    "ReceiveRecognition2",
    "GiveRecognition2"
)

$timeFields = @("WorkingHoursStart", "WorkingHoursEnd")

# Names to skip entirely
$skipNames = @("jordan")

# ===========================================================================
# Helpers
# ===========================================================================
function Normalize-SmartQuotes {
    param([string]$Text)
    if ([string]::IsNullOrEmpty($Text)) { return $Text }
    $t = $Text
    # curly single quotes / apostrophes -> straight ASCII '
    $t = $t -replace [char]0x2018, "'"
    $t = $t -replace [char]0x2019, "'"
    # curly double quotes -> straight ASCII "
    $t = $t -replace [char]0x201C, '"'
    $t = $t -replace [char]0x201D, '"'
    return $t
}

function Get-CellText {
    param($Cell, [bool]$IsTime = $false)
    if ($null -eq $Cell) { return "" }
    $val = $Cell.Value2
    if ($IsTime -and $val -is [double]) {
        try {
            $dt = [DateTime]::FromOADate($val)
            return $dt.ToString("h:mm tt")
        } catch {
            return Normalize-SmartQuotes ($Cell.Text -as [string])
        }
    }
    $text = ($Cell.Text -as [string])
    if ($null -eq $text) { return "" }
    return Normalize-SmartQuotes ($text.Trim())
}

function Parse-MultiValueCell {
    param([string]$Cell)
    if ([string]::IsNullOrWhiteSpace($Cell)) { return @() }
    $trimmed = $Cell.Trim()
    if ($trimmed.StartsWith('"') -and $trimmed.Contains('", "')) {
        $parts = $trimmed -split '"\s*,\s*"'
        $clean = @()
        foreach ($p in $parts) {
            $v = $p.Trim().TrimStart('"').TrimEnd('"').Trim()
            if (-not [string]::IsNullOrWhiteSpace($v)) { $clean += $v }
        }
        return $clean
    } else {
        return @($trimmed)
    }
}

function Find-Internal {
    # Returns the SharePoint internal name for a given Excel header text,
    # using contains-match against the keys in $headerToInternal.
    param([string]$Header)
    if ([string]::IsNullOrWhiteSpace($Header)) { return $null }
    $h = $Header.ToLower()
    foreach ($key in $script:headerToInternal.Keys) {
        if ($h.Contains($key)) {
            return $script:headerToInternal[$key]
        }
    }
    return $null
}

# ===========================================================================
# Pre-flight
# ===========================================================================
if (-not (Test-Path $Path)) {
    Write-Host "ERROR: Excel file not found at $Path" -ForegroundColor Red
    return
}
try {
    $list = Get-PnPList -Identity $ListName -ErrorAction Stop
    Write-Host "Target list: $ListName" -ForegroundColor Cyan
} catch {
    Write-Host "ERROR: list '$ListName' not found." -ForegroundColor Red
    return
}

# ===========================================================================
# Build existing-rows index keyed by Title.ToLower(), with Person flag
# ===========================================================================
Write-Host "Loading existing Stakeholders..." -ForegroundColor DarkGray
$existing = Get-PnPListItem -List $ListName -Fields "ID","Title","Person"
$existingRows = @()
foreach ($it in $existing) {
    $title = ($it.FieldValues["Title"] -as [string])
    if ([string]::IsNullOrWhiteSpace($title)) { continue }
    $personField = $it.FieldValues["Person"]
    $hasPerson = $false
    if ($null -ne $personField) {
        if ($personField -is [Microsoft.SharePoint.Client.FieldUserValue]) {
            $hasPerson = ($personField.LookupId -gt 0)
        } else {
            $hasPerson = $true
        }
    }
    $existingRows += [PSCustomObject]@{
        Id = $it.Id
        Title = $title.Trim()
        TitleLower = $title.Trim().ToLower()
        HasPerson = $hasPerson
    }
}
Write-Host "  $($existingRows.Count) rows loaded ($(($existingRows | Where-Object { $_.HasPerson }).Count) have Person populated)" -ForegroundColor DarkGray

# ===========================================================================
# Open Excel and parse headers
# ===========================================================================
Write-Host ""
Write-Host "Opening Excel: $Path" -ForegroundColor Cyan
$excel = New-Object -ComObject Excel.Application
$excel.Visible = $false
$excel.DisplayAlerts = $false
$wb = $excel.Workbooks.Open($Path)
$sheet = $wb.Worksheets.Item(1)
$usedRange = $sheet.UsedRange
$totalRows = $usedRange.Rows.Count
$totalCols = $usedRange.Columns.Count
Write-Host "  Sheet '$($sheet.Name)' : $totalRows rows x $totalCols cols" -ForegroundColor DarkGray

# Build column index -> internal name from header row (row 2).
# Plain hashtable (NOT [ordered]) because [ordered] with integer keys
# triggers positional-index access on assignment and throws.
$colMap = @{}
Write-Host ""
Write-Host "Parsing headers (row 2)..." -ForegroundColor Cyan
for ($c = 1; $c -le $totalCols; $c++) {
    $headerCell = $usedRange.Cells.Item(2, $c)
    $headerText = ($headerCell.Text -as [string])
    if ([string]::IsNullOrWhiteSpace($headerText)) { continue }
    $internal = Find-Internal -Header $headerText
    if ($null -ne $internal -and $internal -ne "__SKIP_TITLE__") {
        $colMap[$c] = $internal
        Write-Host "  col $c -> $internal" -ForegroundColor DarkGray
    } elseif ($internal -eq "__SKIP_TITLE__") {
        Write-Host "  col $c -> [TEAM MEMBER, used for matching]" -ForegroundColor DarkGray
    } else {
        Write-Host "  col $c -> [no map] '$headerText'" -ForegroundColor Yellow
    }
}
Write-Host "Mapped $($colMap.Count) of $totalCols columns to SharePoint fields." -ForegroundColor DarkGray

# Find the Team Member column (always col 1 per current matrix structure)
$teamMemberCol = 1
for ($c = 1; $c -le $totalCols; $c++) {
    $headerCell = $usedRange.Cells.Item(2, $c)
    $headerText = (($headerCell.Text -as [string]).ToLower())
    if ($headerText -like "*team member*") {
        $teamMemberCol = $c
        break
    }
}
Write-Host "  Team Member column: $teamMemberCol" -ForegroundColor DarkGray

# ===========================================================================
# Main loop
# ===========================================================================
$updated = 0
$skippedNoMatch = 0
$skippedConflict = 0
$skippedJordan = 0
$skippedBlank = 0
$failed = @()
$rejectedValues = @()

for ($r = 3; $r -le $totalRows; $r++) {
    $teamMemberCell = $usedRange.Cells.Item($r, $teamMemberCol)
    $teamMember = Get-CellText -Cell $teamMemberCell
    if ([string]::IsNullOrWhiteSpace($teamMember)) {
        $skippedBlank++
        continue
    }
    Write-Host ""
    Write-Host "Row $r : '$teamMember'" -ForegroundColor Cyan

    if ($skipNames -contains $teamMember.ToLower()) {
        Write-Host "  [skip] in skip-list" -ForegroundColor Yellow
        $skippedJordan++
        continue
    }

    # Find matching existing rows: Title starts with teamMember (case-insensitive) AND HasPerson
    $needle = $teamMember.ToLower()
    $matches = $existingRows | Where-Object {
        $_.HasPerson -and (
            $_.TitleLower -eq $needle -or
            $_.TitleLower.StartsWith($needle + " ")
        )
    }
    $matchCount = @($matches).Count

    if ($matchCount -eq 0) {
        Write-Host "  [skip] no existing row with Person populated whose Title starts with '$teamMember'" -ForegroundColor Yellow
        $skippedNoMatch++
        continue
    }
    if ($matchCount -gt 1) {
        $titles = ($matches | ForEach-Object { $_.Title }) -join ", "
        Write-Host "  [skip] $matchCount conflict matches: $titles" -ForegroundColor Yellow
        $skippedConflict++
        continue
    }

    $target = $matches | Select-Object -First 1
    Write-Host "  [match] '$($target.Title)' (id=$($target.Id))" -ForegroundColor Green

    # Build values from non-blank cells
    $values = @{}
    foreach ($colIdx in $colMap.Keys) {
        $internal = $colMap[$colIdx]
        $isTime = ($timeFields -contains $internal)
        $cell = $usedRange.Cells.Item($r, $colIdx)
        $text = Get-CellText -Cell $cell -IsTime $isTime
        if ([string]::IsNullOrWhiteSpace($text)) { continue }

        if ($multiChoiceFields -contains $internal) {
            $arr = Parse-MultiValueCell -Cell $text
            if ($arr.Count -gt 0) { $values[$internal] = $arr }
        } else {
            $values[$internal] = $text
        }
    }

    if ($values.Count -eq 0) {
        Write-Host "  [skip] no non-blank values to write" -ForegroundColor DarkGray
        continue
    }

    Write-Host "  Writing $($values.Count) field(s)..." -ForegroundColor DarkGray

    # Write each field individually so a single rejected choice doesn't block the rest
    $writtenCount = 0
    foreach ($key in $values.Keys) {
        $val = $values[$key]
        try {
            Set-PnPListItem -List $ListName -Identity $target.Id -Values @{ $key = $val } -ErrorAction Stop | Out-Null
            $writtenCount++
        } catch {
            $rejectedValues += [PSCustomObject]@{
                Row = $r
                Person = $target.Title
                Field = $key
                Value = if ($val -is [array]) { $val -join " | " } else { $val }
                Error = $_.Exception.Message
            }
            Write-Host "    [REJECTED] $key : $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    Write-Host "  [done] $writtenCount of $($values.Count) fields written" -ForegroundColor Green
    $updated++
}

# ===========================================================================
# Cleanup Excel
# ===========================================================================
$wb.Close($false)
$excel.Quit()
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($excel) | Out-Null
[GC]::Collect()
[GC]::WaitForPendingFinalizers()

# ===========================================================================
# Summary
# ===========================================================================
Write-Host ""
Write-Host "==================== SUMMARY ====================" -ForegroundColor Cyan
Write-Host "Updated         : $updated" -ForegroundColor Green
Write-Host "Skipped (Jordan): $skippedJordan" -ForegroundColor DarkGray
Write-Host "Skipped (blank) : $skippedBlank" -ForegroundColor DarkGray
Write-Host "Skipped (no match): $skippedNoMatch" -ForegroundColor Yellow
Write-Host "Skipped (conflict): $skippedConflict" -ForegroundColor Yellow

if ($rejectedValues.Count -gt 0) {
    Write-Host ""
    Write-Host "REJECTED VALUES ($($rejectedValues.Count)):" -ForegroundColor Red
    Write-Host "  These Excel cell values did not match a defined Choice option" -ForegroundColor DarkGray
    Write-Host "  on the SharePoint column. Add them to the Choice list (List" -ForegroundColor DarkGray
    Write-Host "  settings > column > add option), or fix the Excel value, then" -ForegroundColor DarkGray
    Write-Host "  re-run this script." -ForegroundColor DarkGray
    Write-Host ""
    foreach ($rv in $rejectedValues) {
        Write-Host "  [$($rv.Person)] $($rv.Field) <- '$($rv.Value)'" -ForegroundColor Red
    }
}
Write-Host "================================================="
