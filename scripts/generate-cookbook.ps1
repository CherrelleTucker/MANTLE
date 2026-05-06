# Generate KITCHEN Cookbook for a Project Coordinator
# Pulls everything a PC needs day-one (program facts, stakeholders, meetings,
# acronyms, decisions, tasks, equivalency map) and writes a Word document.
#
# Assumes:
#   Connect-PnPOnline -UseWebLogin already run against the target site
#   Microsoft Word installed locally (uses Word COM)
#
# Power Automate replacement: see design/pa-replacement-generate-cookbook.md

param(
    [string]$PCName,
    [string]$OutputPath
)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
function Get-CurrentUserEmail {
    # Prefer UPN, fall back to env username
    try {
        $upn = (whoami /upn 2>$null)
        if ($upn) { return ($upn.Trim()) }
    } catch {}
    return $env:USERNAME
}

function Read-Choice($prompt, $options) {
    Write-Host $prompt -ForegroundColor Cyan
    for ($i = 0; $i -lt $options.Count; $i++) {
        Write-Host "  [$($i + 1)] $($options[$i])"
    }
    while ($true) {
        $r = Read-Host "Enter number (1-$($options.Count))"
        if ($r -match '^\d+$' -and [int]$r -ge 1 -and [int]$r -le $options.Count) {
            return ([int]$r - 1)
        }
        Write-Host "Invalid selection." -ForegroundColor Yellow
    }
}

# ---------------------------------------------------------------------------
# Resolve PC
# ---------------------------------------------------------------------------
# PCname is the Person/Group column on PCs (display name "Coordinator Name").
# It's the canonical PC identifier; Title text is often empty.
[array]$pcs = Get-PnPListItem -List "PCs" -Fields "ID","Title","Email","Contract","Hire_x0020_date","Status","PCname"

# Helper: get a friendly display name for a PC row, preferring Person column
function Get-PCDisplayName($pc) {
    $title = $pc.FieldValues["Title"]
    if ($title) { return $title }
    $person = $pc.FieldValues["PCname"]
    if ($person -and $person.LookupValue) { return $person.LookupValue }
    if ($person -and $person.Email) { return $person.Email }
    $email = $pc.FieldValues["Email"]
    if ($email) { return $email }
    return "PC #$($pc.Id)"
}

$selectedPc = $null
if ($PCName) {
    # Try matching against Title, Person.LookupValue, or Email
    $needle = $PCName.ToLower().Trim()
    $selectedPc = $pcs | Where-Object {
        $t = $_.FieldValues["Title"]
        $p = $_.FieldValues["PCname"]
        $e = $_.FieldValues["Email"]
        ($t -and $t.ToLower().Trim() -eq $needle) -or
        ($p -and $p.LookupValue -and $p.LookupValue.ToLower().Trim() -eq $needle) -or
        ($e -and $e.ToLower().Trim() -eq $needle)
    } | Select-Object -First 1
    if (-not $selectedPc) {
        Write-Host "ERROR: No PC found matching '$PCName' (checked Title, Coordinator Name, and Email)." -ForegroundColor Red
        return
    }
} else {
    $email = Get-CurrentUserEmail
    Write-Host "No -PCName given. Looking up current user: $email" -ForegroundColor Cyan
    $needle = $email.ToLower().Trim()
    $userPart = ($email -split '@')[0].ToLower().Trim()

    # Try Person column first (binds to M365 user, handles AD-UPN-vs-email mismatch)
    $selectedPc = $pcs | Where-Object {
        $p = $_.FieldValues["PCname"]
        if (-not $p) { return $false }
        ($p.Email -and $p.Email.ToLower().Trim() -eq $needle) -or
        ($p.LookupValue -and $p.LookupValue.ToLower().Trim() -eq $needle) -or
        ($p.Email -and $p.Email.ToLower() -like "*$userPart*") -or
        ($p.LookupValue -and $p.LookupValue.ToLower() -like "*$userPart*")
    } | Select-Object -First 1
    if ($selectedPc) {
        Write-Host "Matched via Person column" -ForegroundColor Green
    }

    # Fallback: Email column exact match
    if (-not $selectedPc) {
        $selectedPc = $pcs | Where-Object {
            $e = $_.FieldValues["Email"]
            $e -and $e.ToLower().Trim() -eq $needle
        } | Select-Object -First 1
    }

    # Fallback: Email column substring match on username portion
    if (-not $selectedPc) {
        $selectedPc = $pcs | Where-Object {
            $e = $_.FieldValues["Email"]
            $e -and $e.ToLower() -like "*$userPart*"
        } | Select-Object -First 1
        if ($selectedPc) {
            Write-Host "Matched via Email username substring" -ForegroundColor Yellow
        }
    }

    # Final fallback: interactive picker
    if (-not $selectedPc) {
        Write-Host "Could not auto-resolve your PC. Pick from the list:" -ForegroundColor Yellow
        [array]$pcList = $pcs | ForEach-Object {
            "$(Get-PCDisplayName $_)  ($($_.FieldValues['Email']))"
        }
        if ($pcList.Count -eq 0) {
            Write-Host "ERROR: No PCs exist in the PCs list. Add yourself first." -ForegroundColor Red
            return
        }
        $idx = Read-Choice "Which PC's cookbook do you want to generate?" $pcList
        $selectedPc = $pcs[$idx]
    }
}

$pcId   = $selectedPc.Id
$pcName = Get-PCDisplayName $selectedPc
Write-Host "Generating cookbook for PC: $pcName (Id $pcId)" -ForegroundColor Green

# ---------------------------------------------------------------------------
# Resolve Trainee Profile (prompt if multiple)
# ---------------------------------------------------------------------------
$profiles = Get-PnPListItem -List "Trainee Profiles" -Fields "ID","Title","PCs","Program","StartDate_x002d_CurrentRole","PreviousTools","Previouscolecontext"
$myProfiles = @()
foreach ($p in $profiles) {
    $pcField = $p.FieldValues["PCs"]
    if ($pcField -and $pcField.LookupId -eq $pcId) { $myProfiles += $p }
}

if ($myProfiles.Count -eq 0) {
    Write-Host "ERROR: No Trainee Profile exists for $pcName. Run process-welcome-responses.ps1 first." -ForegroundColor Red
    return
}

$profile = $null
if ($myProfiles.Count -eq 1) {
    $profile = $myProfiles[0]
} else {
    $opts = @()
    foreach ($p in $myProfiles) { $opts += $p.FieldValues["Title"] }
    $idx = Read-Choice "Multiple Trainee Profiles found. Pick one:" $opts
    $profile = $myProfiles[$idx]
}

$programId = $null
$programName = "(unassigned)"
$pf = $profile.FieldValues["Program"]
if ($pf -and $pf.LookupId) {
    $programId = $pf.LookupId
    $programName = $pf.LookupValue
}

# Tools-they-came-from for equivalency filter
$prevToolIds = @()
$ttcf = $profile.FieldValues["PreviousTools"]
if ($ttcf) {
    foreach ($lv in $ttcf) {
        if ($lv.LookupId) { $prevToolIds += $lv.LookupId }
    }
}

# ---------------------------------------------------------------------------
# Pull Program details
# ---------------------------------------------------------------------------
$program = $null
if ($programId) {
    try { $program = Get-PnPListItem -List "Programs" -Id $programId } catch {}
}

# ---------------------------------------------------------------------------
# Pull cascading data
# ---------------------------------------------------------------------------
function Get-LinkedItems($listName, $lookupField, $targetId) {
    if (-not $targetId) { return @() }
    $all = Get-PnPListItem -List $listName
    $matched = @()
    foreach ($it in $all) {
        $fv = $it.FieldValues[$lookupField]
        if (-not $fv) { continue }
        if ($fv -is [array] -or $fv.GetType().Name -eq "FieldLookupValue[]") {
            foreach ($lv in $fv) {
                if ($lv.LookupId -eq $targetId) { $matched += $it; break }
            }
        } else {
            if ($fv.LookupId -eq $targetId) { $matched += $it }
        }
    }
    return $matched
}

Write-Host "Reading Stakeholders..." -ForegroundColor DarkGray
$stakeholders = Get-LinkedItems "Stakeholders" "Programs" $programId

Write-Host "Reading Meetings..." -ForegroundColor DarkGray
$meetings = Get-LinkedItems "Meetings" "Program" $programId

Write-Host "Reading Acronyms..." -ForegroundColor DarkGray
$allAcronyms = Get-PnPListItem -List "Acronyms"
$acronyms = @()
foreach ($a in $allAcronyms) {
    $programsField = $a.FieldValues["Programs"]
    $isUniversal = (-not $programsField) -or ($programsField.Count -eq 0)
    $isProgramTagged = $false
    if ($programsField -and $programId) {
        foreach ($lv in $programsField) {
            if ($lv.LookupId -eq $programId) { $isProgramTagged = $true; break }
        }
    }
    if ($isUniversal -or $isProgramTagged) { $acronyms += $a }
}

Write-Host "Reading Decisions Log..." -ForegroundColor DarkGray
$decisions = Get-LinkedItems "Decisions Log" "Program" $programId

Write-Host "Reading 30-60-90 Tasks..." -ForegroundColor DarkGray
$allTasks = Get-PnPListItem -List "30-60-90 Tasks"
$tasks = @()
foreach ($t in $allTasks) {
    # Try both common internal names for the PC lookup column
    $f = $t.FieldValues["PCs"]
    if (-not $f) { $f = $t.FieldValues["PC"] }
    if ($f -and $f.LookupId -eq $pcId) { $tasks += $t }
}

Write-Host "Reading Equivalency Map..." -ForegroundColor DarkGray
$allEq = Get-PnPListItem -List "Equivalency Map"
$equivs = @()
if ($prevToolIds.Count -gt 0) {
    foreach ($e in $allEq) {
        $f = $e.FieldValues["From_x002d_Tool"]
        if ($f -and $prevToolIds -contains $f.LookupId) { $equivs += $e }
    }
} else {
    $equivs = $allEq
}

# ---------------------------------------------------------------------------
# Resolve OutputPath
# ---------------------------------------------------------------------------
if (-not $OutputPath) {
    $dateStamp = (Get-Date).ToString("yyyy-MM-dd")
    $safeName = ($pcName -replace '[^a-zA-Z0-9_-]', '_')
    $outDir = "C:\Users\cjtucke3\Documents\Personal\Career\KITCHEN\cookbooks"
    if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }
    $OutputPath = Join-Path $outDir "$($safeName)_$dateStamp.docx"
}

# ---------------------------------------------------------------------------
# Word COM: build document
# ---------------------------------------------------------------------------
Write-Host "Generating Word document..." -ForegroundColor Cyan
$word = $null
$doc = $null
try {
    $word = New-Object -ComObject Word.Application
    $word.Visible = $false
    $doc = $word.Documents.Add()
    $sel = $word.Selection

    # --- Cover page ---
    $sel.Style = "Title"
    $sel.TypeText("KITCHEN Cookbook")
    $sel.TypeParagraph()

    $sel.Style = "Subtitle"
    $sel.TypeText("$pcName  |  $programName")
    $sel.TypeParagraph()

    $sel.Style = "Normal"
    $sel.TypeText("Generated: " + (Get-Date).ToString("yyyy-MM-dd HH:mm"))
    $sel.TypeParagraph()
    $sel.InsertNewPage()

    function Write-Heading($text, $level) {
        $sel.Style = "Heading $level"
        $sel.TypeText($text)
        $sel.TypeParagraph()
    }

    function Write-Para($text) {
        $sel.Style = "Normal"
        if ($text) { $sel.TypeText([string]$text) } else { $sel.TypeText("(none)") }
        $sel.TypeParagraph()
    }

    function Write-Table($headers, $rows) {
        if ($rows.Count -eq 0) {
            Write-Para "(none)"
            return
        }
        $rowCount = $rows.Count + 1
        $colCount = $headers.Count
        $range = $sel.Range
        $tbl = $doc.Tables.Add($range, $rowCount, $colCount)
        $tbl.Borders.Enable = $true
        for ($c = 0; $c -lt $colCount; $c++) {
            $tbl.Cell(1, $c + 1).Range.Text = $headers[$c]
            $tbl.Cell(1, $c + 1).Range.Bold = $true
        }
        for ($r = 0; $r -lt $rows.Count; $r++) {
            for ($c = 0; $c -lt $colCount; $c++) {
                $val = $rows[$r][$c]
                if ($null -eq $val) { $val = "" }
                $tbl.Cell($r + 2, $c + 1).Range.Text = [string]$val
            }
        }
        $sel.EndKey(6) | Out-Null  # wdStory = 6
        $sel.TypeParagraph()
    }

    # --- PC + Program facts ---
    Write-Heading "PC & Program Overview" 1
    Write-Heading "Project Coordinator" 2
    Write-Para ("Name: " + $pcName)
    Write-Para ("Email: " + $selectedPc.FieldValues["Email"])
    Write-Para ("Contract: " + $selectedPc.FieldValues["Contract"])
    $hd = $selectedPc.FieldValues["Hire_x0020_date"]
    if ($hd) { Write-Para ("Hire date: " + ([datetime]$hd).ToString("yyyy-MM-dd")) }

    Write-Heading "Program" 2
    if ($program) {
        Write-Para ("Program: " + $program.FieldValues["Title"])
        Write-Para ("Customer: " + $program.FieldValues["Customer"])
        Write-Para ("Center: " + $program.FieldValues["Center"])
        Write-Para ("Description: " + $program.FieldValues["Description"])
        $bl = $program.FieldValues["Barrios_x0020_Lead"]
        if ($bl) { Write-Para ("Barrios Lead: " + $bl.LookupValue) }
        $cu = $program.FieldValues["PC_x0020_Customer"]
        if ($cu) { Write-Para ("PC Customer: " + $cu.LookupValue) }
    } else {
        Write-Para "(No program assigned)"
    }
    $sel.InsertNewPage()

    # --- Stakeholders ---
    Write-Heading "Stakeholders" 1
    $rows = @()
    foreach ($s in $stakeholders) {
        $rows += ,@($s.FieldValues["Title"], $s.FieldValues["Role"], $s.FieldValues["OrgOrTeam"], $s.FieldValues["Influence"], $s.FieldValues["Cadence"])
    }
    Write-Table @("Name","Role","Org","Influence","Cadence") $rows
    $sel.InsertNewPage()

    # --- Meetings ---
    Write-Heading "Meetings" 1
    $rows = @()
    foreach ($m in $meetings) {
        $rows += ,@($m.FieldValues["Title"], $m.FieldValues["Cadence"], $m.FieldValues["DayAndTime"], $m.FieldValues["PCRole"])
    }
    Write-Table @("Meeting","Cadence","When","PC Role") $rows
    $sel.InsertNewPage()

    # --- Acronyms ---
    Write-Heading "Acronyms" 1
    $rows = @()
    foreach ($a in $acronyms) {
        $rows += ,@($a.FieldValues["Title"], $a.FieldValues["Expansion"], $a.FieldValues["AcronymContext"])
    }
    Write-Table @("Acronym","Expansion","Context") $rows
    $sel.InsertNewPage()

    # --- Decisions Log ---
    Write-Heading "Decisions Log" 1
    $rows = @()
    foreach ($d in $decisions) {
        $dd = $d.FieldValues["DateDecided"]
        $dateStr = ""
        if ($dd) { $dateStr = ([datetime]$dd).ToString("yyyy-MM-dd") }
        $rows += ,@($dateStr, $d.FieldValues["Title"], $d.FieldValues["DecisionDetail"])
    }
    Write-Table @("Date","Decision","Detail") $rows
    $sel.InsertNewPage()

    # --- 30-60-90 Tasks ---
    Write-Heading "30-60-90 Tasks" 1
    $rows = @()
    foreach ($t in $tasks) {
        $du = $t.FieldValues["Due_x0020_date"]
        $dueStr = ""
        if ($du) { $dueStr = ([datetime]$du).ToString("yyyy-MM-dd") }
        $rows += ,@($t.FieldValues["Phase"], $t.FieldValues["Title"], $t.FieldValues["Lane"], $dueStr, $t.FieldValues["Status"])
    }
    Write-Table @("Phase","Task","Lane","Due","Status") $rows
    $sel.InsertNewPage()

    # --- Equivalency Map ---
    Write-Heading "Equivalency Map" 1
    $rows = @()
    foreach ($e in $equivs) {
        $rows += ,@($e.FieldValues["Title"], $e.FieldValues["Maturity"], $e.FieldValues["Gotchas"])
    }
    Write-Table @("Mapping","Maturity","Gotchas") $rows

    # --- Save ---
    # Force string + variable indirection — Word COM SaveAs is fussy when PowerShell wraps args
    $savePath = [string]$OutputPath
    $fmt = 16  # wdFormatDocumentDefault (.docx)
    $doc.SaveAs([ref]$savePath, [ref]$fmt)
    Write-Host "Saved: $OutputPath" -ForegroundColor Green
}
catch {
    Write-Host "ERROR generating document: $($_.Exception.Message)" -ForegroundColor Red
}
finally {
    if ($doc)  { $doc.Close() | Out-Null }
    if ($word) { $word.Quit() | Out-Null }
    if ($doc)  { [System.Runtime.Interopservices.Marshal]::ReleaseComObject($doc)  | Out-Null }
    if ($word) { [System.Runtime.Interopservices.Marshal]::ReleaseComObject($word) | Out-Null }
    [GC]::Collect() | Out-Null
    [GC]::WaitForPendingFinalizers() | Out-Null
}

Write-Host ""
Write-Host "==================== SUMMARY ====================" -ForegroundColor Cyan
Write-Host "PC:           $pcName"
Write-Host "Program:      $programName"
Write-Host "Stakeholders: $($stakeholders.Count)"
Write-Host "Meetings:     $($meetings.Count)"
Write-Host "Acronyms:     $($acronyms.Count)"
Write-Host "Decisions:    $($decisions.Count)"
Write-Host "Tasks:        $($tasks.Count)"
Write-Host "Equivalency:  $($equivs.Count)"
Write-Host "Output:       $OutputPath"
Write-Host "================================================="
