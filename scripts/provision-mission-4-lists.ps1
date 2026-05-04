# Provision Mission 4 Lists: 30-60-90 Tasks, PC-Program History, Program-Tool
# Assumes: Connect-PnPOnline -UseWebLogin already run against the target site.
# Requires existing 'PCs', 'Programs', 'Tools' lists for Lookup fields.
# 'Stakeholders' is optional (Mission 3) -- 30-60-90 Tasks gets a Linked stakeholder
# Lookup only if Stakeholders exists.
#
# NOTE on naming: schemas.md uses "PC<arrow>Program History" and "Program<arrow>Tool"
# with Unicode up/down arrow characters in the prose. SharePoint list titles are
# safer with ASCII, so this script provisions:
#   "PC-Program History"  (junction: PCs <-> Programs)
#   "Program-Tool"        (junction: Programs <-> Tools)

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

# Resolve dependent list IDs once
$pcsListId          = $null
$programsListId     = $null
$toolsListId        = $null
$stakeholdersListId = $null

try {
    $pcsList = Get-PnPList -Identity "PCs" -ErrorAction Stop
    $pcsListId = $pcsList.Id.ToString()
    Write-Host "PCs list found. Id = $pcsListId" -ForegroundColor Cyan
} catch {
    Write-Host "WARNING: 'PCs' list not found. PC Lookup fields will be skipped." -ForegroundColor Yellow
}

try {
    $programsList = Get-PnPList -Identity "Programs" -ErrorAction Stop
    $programsListId = $programsList.Id.ToString()
    Write-Host "Programs list found. Id = $programsListId" -ForegroundColor Cyan
} catch {
    Write-Host "WARNING: 'Programs' list not found. Program Lookup fields will be skipped." -ForegroundColor Yellow
}

try {
    $toolsList = Get-PnPList -Identity "Tools" -ErrorAction Stop
    $toolsListId = $toolsList.Id.ToString()
    Write-Host "Tools list found. Id = $toolsListId" -ForegroundColor Cyan
} catch {
    Write-Host "WARNING: 'Tools' list not found. Tool Lookup fields will be skipped." -ForegroundColor Yellow
}

try {
    $stakeholdersList = Get-PnPList -Identity "Stakeholders" -ErrorAction Stop
    $stakeholdersListId = $stakeholdersList.Id.ToString()
    Write-Host "Stakeholders list found. Id = $stakeholdersListId" -ForegroundColor Cyan
} catch {
    Write-Host "NOTE: 'Stakeholders' list not found. 'Linked stakeholder' Lookup will be skipped." -ForegroundColor Yellow
}

# ---------------------------------------------------------------------------
# 1. 30-60-90 Tasks
# ---------------------------------------------------------------------------
$listName = "30-60-90 Tasks"
Write-Host ""
Write-Host "=== $listName ===" -ForegroundColor Cyan
try {
    if (Test-PnPListExists $listName) {
        Write-Host "$listName already exists. Skipping." -ForegroundColor Yellow
        $skipped += $listName
    } else {
        New-PnPList -Title $listName -Template GenericList -OnQuickLaunch | Out-Null
        Set-PnPField -List $listName -Identity "Title" -Values @{ Title = "Task" } | Out-Null

        if ($pcsListId) {
            $xml = "<Field Type='Lookup' DisplayName='PC' Name='PC' List='{$pcsListId}' ShowField='Title' />"
            Add-PnPFieldFromXml -List $listName -FieldXml $xml | Out-Null
        }

        Add-PnPField -List $listName -DisplayName "Phase" -InternalName "Phase" -Type Choice -Choices "Days 1-30","Days 31-60","Days 61-90","Ongoing" | Out-Null
        Add-PnPField -List $listName -DisplayName "Lane" -InternalName "Lane" -Type Choice -Choices "Relationships","Knowledge","Deliverables","Quick Wins","Improvements" | Out-Null
        Add-PnPField -List $listName -DisplayName "Due date" -InternalName "DueDate" -Type DateTime | Out-Null
        Add-PnPField -List $listName -DisplayName "Status" -InternalName "TaskStatus" -Type Choice -Choices "Not Started","In Progress","Done","Blocked" | Out-Null
        Add-PnPField -List $listName -DisplayName "Notes" -InternalName "Notes" -Type Note | Out-Null

        if ($stakeholdersListId) {
            $xml = "<Field Type='Lookup' DisplayName='Linked stakeholder' Name='LinkedStakeholder' List='{$stakeholdersListId}' ShowField='Title' />"
            Add-PnPFieldFromXml -List $listName -FieldXml $xml | Out-Null
        }

        Write-Host "$listName created." -ForegroundColor Green
        $created += $listName
    }
} catch {
    Write-Host "FAILED $listName : $($_.Exception.Message)" -ForegroundColor Red
    $failed += [PSCustomObject]@{ List = $listName; Error = $_.Exception.Message }
}

# ---------------------------------------------------------------------------
# 2. PC-Program History (junction; Title is auto-composed elsewhere)
# ---------------------------------------------------------------------------
$listName = "PC-Program History"
Write-Host ""
Write-Host "=== $listName ===" -ForegroundColor Cyan
try {
    if (Test-PnPListExists $listName) {
        Write-Host "$listName already exists. Skipping." -ForegroundColor Yellow
        $skipped += $listName
    } else {
        New-PnPList -Title $listName -Template GenericList -OnQuickLaunch | Out-Null
        # Title is auto-composed (e.g., "PC Name - Program Name") by a flow/formatter,
        # so we leave the Title display name as-is.

        if ($pcsListId) {
            $xml = "<Field Type='Lookup' DisplayName='PC' Name='PC' List='{$pcsListId}' ShowField='Title' />"
            Add-PnPFieldFromXml -List $listName -FieldXml $xml | Out-Null
        }

        if ($programsListId) {
            $xml = "<Field Type='Lookup' DisplayName='Program' Name='Program' List='{$programsListId}' ShowField='Title' />"
            Add-PnPFieldFromXml -List $listName -FieldXml $xml | Out-Null
        }

        Add-PnPField -List $listName -DisplayName "Start date" -InternalName "StartDate" -Type DateTime | Out-Null
        Add-PnPField -List $listName -DisplayName "End date" -InternalName "EndDate" -Type DateTime | Out-Null
        Add-PnPField -List $listName -DisplayName "Role notes" -InternalName "RoleNotes" -Type Note | Out-Null

        Write-Host "$listName created." -ForegroundColor Green
        $created += $listName
    }
} catch {
    Write-Host "FAILED $listName : $($_.Exception.Message)" -ForegroundColor Red
    $failed += [PSCustomObject]@{ List = $listName; Error = $_.Exception.Message }
}

# ---------------------------------------------------------------------------
# 3. Program-Tool (junction; Title is auto-composed elsewhere)
# ---------------------------------------------------------------------------
$listName = "Program-Tool"
Write-Host ""
Write-Host "=== $listName ===" -ForegroundColor Cyan
try {
    if (Test-PnPListExists $listName) {
        Write-Host "$listName already exists. Skipping." -ForegroundColor Yellow
        $skipped += $listName
    } else {
        New-PnPList -Title $listName -Template GenericList -OnQuickLaunch | Out-Null
        # Title is auto-composed (e.g., "Program Name - Tool Name"), leave as-is.

        if ($programsListId) {
            $xml = "<Field Type='Lookup' DisplayName='Program' Name='Program' List='{$programsListId}' ShowField='Title' />"
            Add-PnPFieldFromXml -List $listName -FieldXml $xml | Out-Null
        }

        if ($toolsListId) {
            $xml = "<Field Type='Lookup' DisplayName='Tool' Name='Tool' List='{$toolsListId}' ShowField='Title' />"
            Add-PnPFieldFromXml -List $listName -FieldXml $xml | Out-Null
        }

        Add-PnPField -List $listName -DisplayName "Adopted date" -InternalName "AdoptedDate" -Type DateTime | Out-Null
        Add-PnPField -List $listName -DisplayName "Sunset date" -InternalName "SunsetDate" -Type DateTime | Out-Null
        Add-PnPField -List $listName -DisplayName "Notes" -InternalName "Notes" -Type Note | Out-Null

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
