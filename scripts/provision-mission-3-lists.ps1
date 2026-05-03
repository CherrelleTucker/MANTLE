# Provision Mission 3 Lists: Stakeholders, Meetings, Acronyms, Decisions Log
# Assumes: Connect-PnPOnline -UseWebLogin already run against the target site.
# Requires existing 'Programs' list for Lookup fields.

$created = @()
$skipped = @()
$failed  = @()

function Test-PnPListExists {
    param([string]$Name)
    try {
        $l = Get-PnPList -Identity $Name -ErrorAction Stop
        return ($null -ne $l)
    } catch {
        return $false
    }
}

# Resolve Programs list ID once (used by all four lists for Lookup)
$programsListId = $null
try {
    $programsList = Get-PnPList -Identity "Programs" -ErrorAction Stop
    $programsListId = $programsList.Id.ToString()
    Write-Host "Programs list found. Id = $programsListId" -ForegroundColor Cyan
} catch {
    Write-Host "WARNING: 'Programs' list not found. Lookup fields will be skipped." -ForegroundColor Yellow
}

# ---------------------------------------------------------------------------
# 1. Stakeholders
# ---------------------------------------------------------------------------
$listName = "Stakeholders"
Write-Host ""
Write-Host "=== $listName ===" -ForegroundColor Cyan
try {
    if (Test-PnPListExists $listName) {
        Write-Host "$listName already exists. Skipping." -ForegroundColor Yellow
        $skipped += $listName
    } else {
        New-PnPList -Title $listName -Template GenericList -OnQuickLaunch | Out-Null
        Set-PnPField -List $listName -Identity "Title" -Values @{ Title = "Contact Name" } | Out-Null

        Add-PnPField -List $listName -DisplayName "Role" -InternalName "Role" -Type Text | Out-Null
        Add-PnPField -List $listName -DisplayName "Org or Team" -InternalName "OrgOrTeam" -Type Text | Out-Null

        if ($programsListId) {
            $xml = "<Field Type='LookupMulti' Mult='TRUE' DisplayName='Programs' Name='Programs' List='{$programsListId}' ShowField='Title' />"
            Add-PnPFieldFromXml -List $listName -FieldXml $xml | Out-Null
        }

        Add-PnPField -List $listName -DisplayName "Influence" -InternalName "Influence" -Type Choice -Choices "High","Medium","Low" | Out-Null
        Add-PnPField -List $listName -DisplayName "Interest" -InternalName "Interest" -Type Choice -Choices "High","Medium","Low" | Out-Null
        Add-PnPField -List $listName -DisplayName "Relationship status" -InternalName "RelationshipStatus" -Type Choice -Choices "Strong","Neutral","Strained","Unknown" | Out-Null
        Add-PnPField -List $listName -DisplayName "First met" -InternalName "FirstMet" -Type DateTime | Out-Null
        Add-PnPField -List $listName -DisplayName "Last contact" -InternalName "LastContact" -Type DateTime | Out-Null
        Add-PnPField -List $listName -DisplayName "Cadence" -InternalName "Cadence" -Type Choice -Choices "Weekly","Bi-weekly","Monthly","Quarterly","Ad hoc" | Out-Null
        Add-PnPField -List $listName -DisplayName "Sensitive" -InternalName "Sensitive" -Type Boolean | Out-Null
        Add-PnPField -List $listName -DisplayName "Notes" -InternalName "Notes" -Type Note | Out-Null
        Add-PnPField -List $listName -DisplayName "Owner" -InternalName "Owner" -Type User | Out-Null

        Write-Host "$listName created." -ForegroundColor Green
        $created += $listName
    }
} catch {
    Write-Host "FAILED $listName : $($_.Exception.Message)" -ForegroundColor Red
    $failed += [PSCustomObject]@{ List = $listName; Error = $_.Exception.Message }
}

# ---------------------------------------------------------------------------
# 2. Meetings
# ---------------------------------------------------------------------------
$listName = "Meetings"
Write-Host ""
Write-Host "=== $listName ===" -ForegroundColor Cyan
try {
    if (Test-PnPListExists $listName) {
        Write-Host "$listName already exists. Skipping." -ForegroundColor Yellow
        $skipped += $listName
    } else {
        New-PnPList -Title $listName -Template GenericList -OnQuickLaunch | Out-Null
        Set-PnPField -List $listName -Identity "Title" -Values @{ Title = "Meeting Name" } | Out-Null

        if ($programsListId) {
            $xml = "<Field Type='Lookup' DisplayName='Program' Name='Program' List='{$programsListId}' ShowField='Title' />"
            Add-PnPFieldFromXml -List $listName -FieldXml $xml | Out-Null
        }

        Add-PnPField -List $listName -DisplayName "Cadence" -InternalName "Cadence" -Type Choice -Choices "Daily","Weekly","Bi-weekly","Monthly","Quarterly","Annual","Ad hoc" | Out-Null
        Add-PnPField -List $listName -DisplayName "Day and time" -InternalName "DayAndTime" -Type Text | Out-Null
        Add-PnPField -List $listName -DisplayName "Type" -InternalName "MeetingType" -Type Choice -Choices "Internal","External","Reporting","Informational" | Out-Null
        Add-PnPField -List $listName -DisplayName "Owner" -InternalName "Owner" -Type User | Out-Null
        Add-PnPField -List $listName -DisplayName "PC role" -InternalName "PCRole" -Type Choice -Choices "Lead","Co-lead","Participant","Observer","Optional" | Out-Null
        Add-PnPField -List $listName -DisplayName "PC responsibilities" -InternalName "PCResponsibilities" -Type Note | Out-Null
        Add-PnPField -List $listName -DisplayName "Resources" -InternalName "Resources" -Type Note | Out-Null

        Write-Host "$listName created." -ForegroundColor Green
        $created += $listName
    }
} catch {
    Write-Host "FAILED $listName : $($_.Exception.Message)" -ForegroundColor Red
    $failed += [PSCustomObject]@{ List = $listName; Error = $_.Exception.Message }
}

# ---------------------------------------------------------------------------
# 3. Acronyms
# ---------------------------------------------------------------------------
$listName = "Acronyms"
Write-Host ""
Write-Host "=== $listName ===" -ForegroundColor Cyan
try {
    if (Test-PnPListExists $listName) {
        Write-Host "$listName already exists. Skipping." -ForegroundColor Yellow
        $skipped += $listName
    } else {
        New-PnPList -Title $listName -Template GenericList -OnQuickLaunch | Out-Null
        Set-PnPField -List $listName -Identity "Title" -Values @{ Title = "Acronym" } | Out-Null

        Add-PnPField -List $listName -DisplayName "Expansion" -InternalName "Expansion" -Type Text | Out-Null
        Add-PnPField -List $listName -DisplayName "Context" -InternalName "AcronymContext" -Type Choice -Choices "Agency","Center","Program","Project","Industry" | Out-Null

        if ($programsListId) {
            $xml = "<Field Type='LookupMulti' Mult='TRUE' DisplayName='Programs' Name='Programs' List='{$programsListId}' ShowField='Title' />"
            Add-PnPFieldFromXml -List $listName -FieldXml $xml | Out-Null
        }

        Add-PnPField -List $listName -DisplayName "Source" -InternalName "Source" -Type Text | Out-Null
        Add-PnPField -List $listName -DisplayName "Notes" -InternalName "Notes" -Type Note | Out-Null

        Write-Host "$listName created." -ForegroundColor Green
        $created += $listName
    }
} catch {
    Write-Host "FAILED $listName : $($_.Exception.Message)" -ForegroundColor Red
    $failed += [PSCustomObject]@{ List = $listName; Error = $_.Exception.Message }
}

# ---------------------------------------------------------------------------
# 4. Decisions Log
# ---------------------------------------------------------------------------
$listName = "Decisions Log"
Write-Host ""
Write-Host "=== $listName ===" -ForegroundColor Cyan
try {
    if (Test-PnPListExists $listName) {
        Write-Host "$listName already exists. Skipping." -ForegroundColor Yellow
        $skipped += $listName
    } else {
        New-PnPList -Title $listName -Template GenericList -OnQuickLaunch | Out-Null
        Set-PnPField -List $listName -Identity "Title" -Values @{ Title = "Decision" } | Out-Null

        if ($programsListId) {
            $xml = "<Field Type='Lookup' DisplayName='Program' Name='Program' List='{$programsListId}' ShowField='Title' />"
            Add-PnPFieldFromXml -List $listName -FieldXml $xml | Out-Null
        }

        Add-PnPField -List $listName -DisplayName "Date decided" -InternalName "DateDecided" -Type DateTime | Out-Null
        Add-PnPField -List $listName -DisplayName "Decider" -InternalName "Decider" -Type User | Out-Null
        Add-PnPField -List $listName -DisplayName "Context" -InternalName "DecisionContext" -Type Note | Out-Null
        Add-PnPField -List $listName -DisplayName "Decision detail" -InternalName "DecisionDetail" -Type Note | Out-Null
        Add-PnPField -List $listName -DisplayName "Rationale" -InternalName "Rationale" -Type Note | Out-Null
        Add-PnPField -List $listName -DisplayName "Linked artifacts" -InternalName "LinkedArtifacts" -Type Note | Out-Null

        Write-Host "$listName created." -ForegroundColor Green
        $created += $listName
    }
} catch {
    Write-Host "FAILED $listName : $($_.Exception.Message)" -ForegroundColor Red
    $failed += [PSCustomObject]@{ List = $listName; Error = $_.Exception.Message }
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "==================== SUMMARY ====================" -ForegroundColor Cyan
Write-Host "Created ($($created.Count)): $($created -join ', ')" -ForegroundColor Green
Write-Host "Skipped ($($skipped.Count)): $($skipped -join ', ')" -ForegroundColor Yellow
if ($failed.Count -gt 0) {
    Write-Host "Failed  ($($failed.Count)):" -ForegroundColor Red
    $failed | Format-Table -AutoSize
} else {
    Write-Host "Failed  (0): none" -ForegroundColor Green
}
Write-Host "================================================="
