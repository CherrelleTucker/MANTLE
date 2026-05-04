# Process MANTLE Welcome Form Responses
# Reads an Excel export of Microsoft Forms responses, then for each unprocessed
# row creates a Trainee Profile, seeds 16 starter 30-60-90 tasks (first one is
# the welcome/setup task), and best-effort assigns a Planner task to the user
# in the MANTLE Team's 30-60-90 board.
#
# Notification approach (Power Automate is blocked on this tenant):
#   1. The first 30-60-90 task ("Welcome to MANTLE - complete your profile")
#      is the persistent in-platform welcome.
#   2. A Planner task assigned to the user (best-effort) gives a Teams
#      notification AND introduces Planner as a tool.
#   3. Email confirmation is intentionally NOT implemented here - that's
#      for Power Automate to add when/if PA is enabled on this tenant.
#
# Assumes:
#   Connect-PnPOnline -UseWebLogin already run against $siteUrl
#   The user has exported Form responses to the path in $inboxPath
#   Lists exist: PCs, Programs, Trainee Profiles, 30-60-90 Tasks
#
# Power Automate replacement: see design/pa-replacement-process-responses.md

# ---------------------------------------------------------------------------
# Configurable parameters
# ---------------------------------------------------------------------------
$inboxPath = "C:\Users\cjtucke3\Documents\Personal\Career\MANTLE\inbox\welcome-responses.xlsx"
$siteUrl   = "https://nasa.sharepoint.com/teams/PCTransitionSandbox"

# Planner integration (best-effort - if cmdlets/permissions fail, script
# continues and the SharePoint task still serves as the welcome).
# Group ID = the M365 Group behind the MANTLE Team. Found in the Teams
# channel link as the groupId= parameter.
$mantleGroupId     = "c5daa449-8142-4179-a0a9-1cdfb9316ba3"
$plannerPlanName   = "30-60-90"
$plannerBucketName = "Days 1-30"

# Column header names as they appear in the Forms-exported xlsx. Adjust if
# the Form question wording changes.
$colEmail        = "Email"
$colName         = "Your name"
$colMode         = "What brings you here today?"
$colStartDate    = "Start date in your new role"
$colProgram      = "Which program/customer are you supporting?"
$colPrevTools    = "Which tools did you use in your previous role?"
$colNotes        = "Anything else we should know?"

# ---------------------------------------------------------------------------
# Starter 30-60-90 tasks (copied from design/welcome-form-build-guide.md Phase 3)
# ---------------------------------------------------------------------------
$starterTasks = @(
    @{ title = "Welcome to MANTLE - review your profile and complete setup";                        phase = "Days 1-30";  lane = "Quick Wins";    offsetDays = 1;  notes = "Open your Trainee Profile and fill in 'Tools they came from' (multi-select Lookup). This is your first task." },
    @{ title = "Meet your Barrios manager 1:1 and confirm expectations";                            phase = "Days 1-30";  lane = "Relationships"; offsetDays = 5;  notes = "Bring your draft 30-60-90 to this meeting." },
    @{ title = "Meet your NASA customer (PC Customer) and ask how they prefer to communicate";      phase = "Days 1-30";  lane = "Relationships"; offsetDays = 7;  notes = "Cadence, channel, what 'urgent' means to them." },
    @{ title = "Read the role baseline document end-to-end";                                        phase = "Days 1-30";  lane = "Knowledge";     offsetDays = 3;  notes = "Tier 1 universal PC content - link on MANTLE home." },
    @{ title = "Walk the meeting catalog for your program and accept recurring invites";            phase = "Days 1-30";  lane = "Knowledge";     offsetDays = 4;  notes = "Open the Meetings list filtered to your program." },
    @{ title = "Browse the NASA acronyms list - search the ten you've already heard";               phase = "Days 1-30";  lane = "Quick Wins";    offsetDays = 2;  notes = "Acronyms list is search-first." },
    @{ title = "Add your first three stakeholders to the Stakeholders list";                        phase = "Days 1-30";  lane = "Deliverables";  offsetDays = 14; notes = "Name, role, why they matter - one sentence each." },
    @{ title = "Schedule your 30-day supervisor check-in";                                          phase = "Days 1-30";  lane = "Quick Wins";    offsetDays = 1;  notes = "Use the Outlook template on MANTLE home." },
    @{ title = "Identify the top three meetings where you need to make a deliverable contribution"; phase = "Days 31-60"; lane = "Deliverables";  offsetDays = 35; notes = "Move from Observer to Participant where appropriate." },
    @{ title = "Map the equivalencies from your previous tools to NASA's stack";                    phase = "Days 31-60"; lane = "Knowledge";     offsetDays = 32; notes = "Open Equivalency Map filtered to your previous tools." },
    @{ title = "Build your stakeholder map - influence vs. interest";                               phase = "Days 31-60"; lane = "Relationships"; offsetDays = 45; notes = "Use the By Influence view in Stakeholders." },
    @{ title = "Document one process you do weekly that isn't written down";                        phase = "Days 31-60"; lane = "Deliverables";  offsetDays = 50; notes = "This is your first cookbook contribution." },
    @{ title = "Run a 30-day retro with your supervisor - what's working, what's not";              phase = "Days 31-60"; lane = "Relationships"; offsetDays = 30; notes = "Honest. Specific. Two-way." },
    @{ title = "Take ownership of one recurring deliverable end-to-end";                            phase = "Days 61-90"; lane = "Deliverables";  offsetDays = 65; notes = "Pick one and own it from intake to delivery." },
    @{ title = "Identify one improvement to a process and propose it";                              phase = "Days 61-90"; lane = "Improvements";  offsetDays = 75; notes = "One slide, one paragraph, one ask." },
    @{ title = "Run your first 60-day review - present 30-60-90 progress to your supervisor";       phase = "Days 61-90"; lane = "Relationships"; offsetDays = 60; notes = "Use the My Open Tasks view as your agenda backbone." }
)

# ---------------------------------------------------------------------------
# Counters
# ---------------------------------------------------------------------------
$processed = 0
$skipped   = 0
$failed    = @()

# ---------------------------------------------------------------------------
# Sanity checks
# ---------------------------------------------------------------------------
if (-not (Test-Path $inboxPath)) {
    Write-Host "ERROR: Inbox file not found at $inboxPath" -ForegroundColor Red
    Write-Host "Export Form responses to Excel and save to that path." -ForegroundColor Yellow
    return
}

# ---------------------------------------------------------------------------
# Read the xlsx via Excel COM
# ---------------------------------------------------------------------------
Write-Host "Opening $inboxPath ..." -ForegroundColor Cyan
$excel = $null
$workbook = $null
try {
    $excel = New-Object -ComObject Excel.Application
    $excel.Visible = $false
    $excel.DisplayAlerts = $false
    $workbook = $excel.Workbooks.Open($inboxPath)
    $sheet = $workbook.Sheets.Item(1)
    $usedRange = $sheet.UsedRange
    $rowCount = $usedRange.Rows.Count
    $colCount = $usedRange.Columns.Count

    # Build header map: column-name -> 1-based index
    $headerMap = @{}
    for ($c = 1; $c -le $colCount; $c++) {
        $h = $sheet.Cells.Item(1, $c).Value2
        if ($h) { $headerMap[[string]$h] = $c }
    }

    function Get-Cell($row, $name) {
        if (-not $headerMap.ContainsKey($name)) { return $null }
        $v = $sheet.Cells.Item($row, $headerMap[$name]).Value2
        if ($null -eq $v) { return $null }
        return [string]$v
    }

    # Cache existing Trainee Profiles + PCs to keep loop fast
    $existingProfiles = Get-PnPListItem -List "Trainee Profiles" -Fields "ID","Title","PC"
    $profileEmails = @{}
    foreach ($p in $existingProfiles) {
        $pcField = $p.FieldValues["PC"]
        if ($pcField -and $pcField.LookupId) {
            try {
                $pcItem = Get-PnPListItem -List "PCs" -Id $pcField.LookupId -Fields "Email"
                $em = $pcItem.FieldValues["Email"]
                if ($em) { $profileEmails[$em.ToLower().Trim()] = $true }
            } catch {}
        }
    }

    $pcs = Get-PnPListItem -List "PCs" -Fields "ID","Title","Email"
    $pcByEmail = @{}
    foreach ($pc in $pcs) {
        $em = $pc.FieldValues["Email"]
        if ($em) { $pcByEmail[$em.ToLower().Trim()] = @{ Id = $pc.Id; Title = $pc.FieldValues["Title"] } }
    }

    $programs = Get-PnPListItem -List "Programs" -Fields "ID","Title"
    $programByName = @{}
    foreach ($pg in $programs) {
        $t = $pg.FieldValues["Title"]
        if ($t) { $programByName[$t.ToLower().Trim()] = $pg.Id }
    }

    Write-Host "Found $($rowCount - 1) response rows. Processing..." -ForegroundColor Cyan

    for ($r = 2; $r -le $rowCount; $r++) {
        $email = Get-Cell $r $colEmail
        if (-not $email) {
            $failed += [PSCustomObject]@{ Row = $r; Email = ""; Reason = "No email column value" }
            continue
        }
        $emailKey = $email.ToLower().Trim()

        if ($profileEmails.ContainsKey($emailKey)) {
            Write-Host "Row $r ($email): already has Trainee Profile. Skipping." -ForegroundColor Yellow
            $skipped++
            continue
        }

        try {
            $name      = Get-Cell $r $colName
            $mode      = Get-Cell $r $colMode
            $startDate = Get-Cell $r $colStartDate
            $programNm = Get-Cell $r $colProgram
            $prevTools = Get-Cell $r $colPrevTools
            $notes     = Get-Cell $r $colNotes

            if (-not $name) { $name = $email }

            # Resolve PC (auto-create if missing)
            $pcId = $null
            if ($pcByEmail.ContainsKey($emailKey)) {
                $pcId = $pcByEmail[$emailKey].Id
            } else {
                $newPc = Add-PnPListItem -List "PCs" -Values @{
                    Title    = $name
                    Email    = $email
                    Status   = "Active"
                    Contract = "CPSS"
                }
                $pcId = $newPc.Id
                $pcByEmail[$emailKey] = @{ Id = $pcId; Title = $name }
                Write-Host "  Auto-created PC row for $email (Id $pcId)" -ForegroundColor Cyan
            }

            # Resolve Program (auto-create with Pending Review if no match)
            $programId = $null
            if ($programNm -and $programNm.Trim() -and $programNm -ne "Not yet assigned" -and $programNm -ne "Other") {
                $key = $programNm.ToLower().Trim()
                if ($programByName.ContainsKey($key)) {
                    $programId = $programByName[$key]
                } else {
                    $newProg = Add-PnPListItem -List "Programs" -Values @{
                        Title  = $programNm
                        Status = "Pending Review"
                    }
                    $programId = $newProg.Id
                    $programByName[$key] = $programId
                    Write-Host "  Auto-created Program '$programNm' (Id $programId, Pending Review)" -ForegroundColor Cyan
                }
            }

            # Build Trainee Profile values
            $profileTitle = "$name"
            if ($programNm) { $profileTitle = "$name - $programNm" }

            $profileValues = @{
                Title = $profileTitle
                PC    = $pcId
            }
            if ($programId)  { $profileValues["Current_x0020_program"] = $programId }
            if ($startDate)  {
                try { $profileValues["Start_x0020_date_x0020_in_x0020_current_x0020_role"] = [datetime]$startDate } catch {}
            }
            if ($notes)      { $profileValues["Previous_x0020_role_x0020_context"] = $notes }

            $newProfile = Add-PnPListItem -List "Trainee Profiles" -Values $profileValues
            Write-Host "  Created Trainee Profile (Id $($newProfile.Id))" -ForegroundColor Green

            # Compute task base date
            $baseDate = (Get-Date)
            if ($startDate) {
                try { $baseDate = [datetime]$startDate } catch {}
            }

            # Seed 30-60-90 tasks
            $taskCount = 0
            foreach ($t in $starterTasks) {
                $vals = @{
                    Title  = $t.title
                    PC     = $pcId
                    Phase  = $t.phase
                    Lane   = $t.lane
                    Status = "Not Started"
                    Notes  = $t.notes
                }
                $vals["Due_x0020_date"] = $baseDate.AddDays($t.offsetDays)
                Add-PnPListItem -List "30-60-90 Tasks" -Values $vals | Out-Null
                $taskCount++
            }
            Write-Host "  Seeded $taskCount starter tasks" -ForegroundColor Green

            # Best-effort: assign a Planner task to the user. Gives a Teams
            # notification AND introduces Planner. If the cmdlets aren't
            # available or the call fails, log a friendly note and continue -
            # the SharePoint welcome task still serves as the in-platform nudge.
            try {
                $plans = Get-PnPPlannerPlan -Group $mantleGroupId -ErrorAction Stop
                $plan = $plans | Where-Object { $_.Title -eq $plannerPlanName } | Select-Object -First 1
                if (-not $plan) {
                    Write-Host "  (Planner: plan '$plannerPlanName' not found in Team - skipping)" -ForegroundColor DarkGray
                } else {
                    $buckets = Get-PnPPlannerBucket -Plan $plan.Id -ErrorAction Stop
                    $bucket = $buckets | Where-Object { $_.Name -eq $plannerBucketName } | Select-Object -First 1
                    if (-not $bucket) {
                        Write-Host "  (Planner: bucket '$plannerBucketName' not found - skipping)" -ForegroundColor DarkGray
                    } else {
                        Add-PnPPlannerTask -Plan $plan.Id -Bucket $bucket.Id `
                            -Title "Welcome to MANTLE - complete your profile setup" `
                            -AssignedTo $email `
                            -ErrorAction Stop | Out-Null
                        Write-Host "  Planner task assigned to $email" -ForegroundColor Green
                    }
                }
            } catch {
                Write-Host "  (Planner step skipped: $($_.Exception.Message))" -ForegroundColor DarkGray
            }
            # Email confirmation intentionally NOT sent. PA-replacement
            # design (design/pa-replacement-process-responses.md) covers the
            # email step for when Power Automate is enabled on this tenant.

            $profileEmails[$emailKey] = $true
            $processed++
        } catch {
            Write-Host "  FAILED row $r ($email): $($_.Exception.Message)" -ForegroundColor Red
            $failed += [PSCustomObject]@{ Row = $r; Email = $email; Reason = $_.Exception.Message }
        }
    }
}
finally {
    if ($workbook) { $workbook.Close($false) | Out-Null }
    if ($excel)    { $excel.Quit() | Out-Null }
    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($workbook) | Out-Null
    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($excel)    | Out-Null
    [GC]::Collect() | Out-Null
    [GC]::WaitForPendingFinalizers() | Out-Null
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "==================== SUMMARY ====================" -ForegroundColor Cyan
Write-Host "Processed: $processed" -ForegroundColor Green
Write-Host "Skipped (already done): $skipped" -ForegroundColor Yellow
if ($failed.Count -gt 0) {
    Write-Host "Failed: $($failed.Count)" -ForegroundColor Red
    $failed | Format-Table -AutoSize
} else {
    Write-Host "Failed: 0" -ForegroundColor Green
}
Write-Host "================================================="
