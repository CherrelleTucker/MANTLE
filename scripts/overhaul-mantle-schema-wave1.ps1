# Wave 1 schema refactor for KITCHEN.
#
# What this script DOES:
#   * Stakeholders list:
#       - Rename 6 prior-pass deprecated fields to "[DELETE] ..."
#         (EditingPreference, NoticePreference, DocumentStyle, DecisionStyle,
#          WorkingHours, Quirks)
#       - Rename 11 bad-schema fields to "[DELETE] ..."
#         (EditsLeaveStyle, EditsReceiveStyle, DecisionTimingSelf,
#          DecisionTimingOthers, InclusionPreference, ReceiveFeedback,
#          GiveFeedback, ReceiveRecognition, GiveRecognition, ThinkerType,
#          DeepWorkStyle)
#       - Add 11 corrected replacement fields with internal-name suffix "2"
#         and display names matching the Working Styles Matrix wording
#         (multi-select Choice where the matrix expects multi)
#       - Add 4 brand-new fields: Person, Contracts, MeetingTimePreference,
#         Overthinker
#   * PCs list:
#       - Add Person (people picker)
#       - Add all 23 working-style fields with matrix wording
#         (PCs has none of these yet, so clean internal names; no suffix)
#   * Acronyms list:
#       - Add Contract lookup (single, optional)
#   * Meetings list:
#       - Add Contract lookup (single, required by typical use)
#   * Equivalency Map Real -> Equivalency Map (rename display name)
#   * Old broken Equivalency Map -> "[ARCHIVED] Equivalency Map" (rename only)
#   * Program-Tool -> "[ARCHIVED] Program-Tool" (rename only)
#   * Remove [ARCHIVED] entries from Quick Launch nav
#
# What this script DOES NOT DO:
#   * Touch the Contracts list. Period. Task ID and all other Contracts
#     columns are untouched.
#   * Delete any column. Bad-schema columns are renamed "[DELETE] ..." so the
#     OWNER deletes them via the SharePoint UI when ready.
#   * Delete any list (cannot via API on this tenant). Lists become
#     "[ARCHIVED] ..." instead and are removed from nav.
#   * Migrate Choice -> Lookup on Contracts (Wave 2, manual via UI).
#
# Idempotent: safe to re-run. Existing fields are skipped with a friendly
# message. Renames are no-ops if the field is already renamed.
#
# Module: legacy SharePointPnPPowerShellOnline (Windows PowerShell 5.1).
# Assumes: Connect-PnPOnline -UseWebLogin already run against:
#   https://nasa.sharepoint.com/teams/PCTransitionSandbox

# ===========================================================================
# Configuration
# ===========================================================================
$listStakeholders = "Stakeholders"
$listPCs          = "PCs"
$listAcronyms     = "Acronyms"
$listMeetings     = "Meetings"
$listContracts    = "Contracts"
$listEqMapReal    = "Equivalency Map Real"
$listEqMapOld     = "Equivalency Map"
$listProgramTool  = "Program-Tool"

# ===========================================================================
# Tracking
# ===========================================================================
$renamedFields    = @()
$addedFields      = @()
$skippedFields    = @()
$failedFields     = @()
$renamedLists     = @()
$navCleanups      = @()
$listFailures     = @()

# ===========================================================================
# Helpers
# ===========================================================================
function Test-PnPFieldExists {
    param([string]$List, [string]$InternalName)
    try {
        $f = Get-PnPField -List $List -Identity $InternalName -ErrorAction Stop
        return ($null -ne $f)
    } catch { return $false }
}

function Get-PnPListSafe {
    param([string]$Name)
    try { return Get-PnPList -Identity $Name -ErrorAction Stop }
    catch { return $null }
}

function Rename-FieldDisplay {
    param(
        [string]$List,
        [string]$InternalName,
        [string]$NewDisplay
    )
    if (-not (Test-PnPFieldExists -List $List -InternalName $InternalName)) {
        Write-Host "  [skip] '$InternalName' on '$List' does not exist." -ForegroundColor DarkGray
        return
    }
    try {
        $cur = Get-PnPField -List $List -Identity $InternalName -ErrorAction Stop
        if ($cur.Title -eq $NewDisplay) {
            Write-Host "  [skip] '$InternalName' already named '$NewDisplay'." -ForegroundColor DarkGray
            return
        }
        Set-PnPField -List $List -Identity $InternalName -Values @{ Title = $NewDisplay } | Out-Null
        Write-Host "  [renamed] $InternalName -> '$NewDisplay'" -ForegroundColor Green
        $script:renamedFields += "$List/$InternalName -> $NewDisplay"
    } catch {
        Write-Host "  [FAIL] rename $InternalName : $($_.Exception.Message)" -ForegroundColor Red
        $script:failedFields += [PSCustomObject]@{ List = $List; Field = $InternalName; Op = "rename"; Error = $_.Exception.Message }
    }
}

function Add-ChoiceField {
    param(
        [string]$List,
        [string]$DisplayName,
        [string]$InternalName,
        [string[]]$Choices,
        [bool]$Multi = $false,
        [bool]$AllowFillIn = $false
    )
    if (Test-PnPFieldExists -List $List -InternalName $InternalName) {
        Write-Host "  [skip] '$InternalName' already exists." -ForegroundColor DarkGray
        $script:skippedFields += "$List/$InternalName"
        return
    }
    try {
        if ($Multi) {
            # MultiChoice via XML for reliability across legacy module versions.
            $choiceXml = ($Choices | ForEach-Object { "<CHOICE>$([System.Security.SecurityElement]::Escape($_))</CHOICE>" }) -join ""
            $fieldXml = "<Field Type='MultiChoice' DisplayName='$([System.Security.SecurityElement]::Escape($DisplayName))' Name='$InternalName' Required='FALSE'><CHOICES>$choiceXml</CHOICES></Field>"
            Add-PnPFieldFromXml -List $List -FieldXml $fieldXml | Out-Null
            Set-PnPField -List $List -Identity $InternalName -Values @{} -ErrorAction SilentlyContinue | Out-Null
        } else {
            Add-PnPField -List $List -DisplayName $DisplayName -InternalName $InternalName -Type Choice -Choices $Choices -AddToDefaultView | Out-Null
            if ($AllowFillIn) {
                try {
                    $ctx = Get-PnPContext
                    $field = Get-PnPField -List $List -Identity $InternalName -ErrorAction Stop
                    $cf = [Microsoft.SharePoint.Client.FieldChoice]$ctx.CastTo($field, [Microsoft.SharePoint.Client.FieldChoice])
                    $cf.FillInChoice = $true
                    $cf.Update()
                    $ctx.ExecuteQuery()
                } catch {
                    Write-Host "    (could not enable FillInChoice on $InternalName)" -ForegroundColor DarkGray
                }
            }
        }
        Write-Host "  [added] $InternalName ($(if ($Multi) { 'MultiChoice' } else { 'Choice' }))" -ForegroundColor Green
        $script:addedFields += "$List/$InternalName"
    } catch {
        Write-Host "  [FAIL] add $InternalName : $($_.Exception.Message)" -ForegroundColor Red
        $script:failedFields += [PSCustomObject]@{ List = $List; Field = $InternalName; Op = "add"; Error = $_.Exception.Message }
    }
}

function Add-TextField {
    param([string]$List, [string]$DisplayName, [string]$InternalName)
    if (Test-PnPFieldExists -List $List -InternalName $InternalName) {
        Write-Host "  [skip] '$InternalName' already exists." -ForegroundColor DarkGray
        $script:skippedFields += "$List/$InternalName"
        return
    }
    try {
        Add-PnPField -List $List -DisplayName $DisplayName -InternalName $InternalName -Type Text -AddToDefaultView | Out-Null
        Write-Host "  [added] $InternalName (Text)" -ForegroundColor Green
        $script:addedFields += "$List/$InternalName"
    } catch {
        Write-Host "  [FAIL] add $InternalName : $($_.Exception.Message)" -ForegroundColor Red
        $script:failedFields += [PSCustomObject]@{ List = $List; Field = $InternalName; Op = "add"; Error = $_.Exception.Message }
    }
}

function Add-NoteField {
    param([string]$List, [string]$DisplayName, [string]$InternalName)
    if (Test-PnPFieldExists -List $List -InternalName $InternalName) {
        Write-Host "  [skip] '$InternalName' already exists." -ForegroundColor DarkGray
        $script:skippedFields += "$List/$InternalName"
        return
    }
    try {
        Add-PnPField -List $List -DisplayName $DisplayName -InternalName $InternalName -Type Note | Out-Null
        Write-Host "  [added] $InternalName (Note)" -ForegroundColor Green
        $script:addedFields += "$List/$InternalName"
    } catch {
        Write-Host "  [FAIL] add $InternalName : $($_.Exception.Message)" -ForegroundColor Red
        $script:failedFields += [PSCustomObject]@{ List = $List; Field = $InternalName; Op = "add"; Error = $_.Exception.Message }
    }
}

function Add-PersonField {
    param([string]$List, [string]$DisplayName, [string]$InternalName)
    if (Test-PnPFieldExists -List $List -InternalName $InternalName) {
        Write-Host "  [skip] '$InternalName' already exists." -ForegroundColor DarkGray
        $script:skippedFields += "$List/$InternalName"
        return
    }
    try {
        Add-PnPField -List $List -DisplayName $DisplayName -InternalName $InternalName -Type User -AddToDefaultView | Out-Null
        Write-Host "  [added] $InternalName (User)" -ForegroundColor Green
        $script:addedFields += "$List/$InternalName"
    } catch {
        Write-Host "  [FAIL] add $InternalName : $($_.Exception.Message)" -ForegroundColor Red
        $script:failedFields += [PSCustomObject]@{ List = $List; Field = $InternalName; Op = "add"; Error = $_.Exception.Message }
    }
}

function Add-LookupField {
    param(
        [string]$List,
        [string]$DisplayName,
        [string]$InternalName,
        [string]$SourceListName,
        [bool]$Multi = $false
    )
    if (Test-PnPFieldExists -List $List -InternalName $InternalName) {
        Write-Host "  [skip] '$InternalName' already exists." -ForegroundColor DarkGray
        $script:skippedFields += "$List/$InternalName"
        return
    }
    $srcList = Get-PnPListSafe -Name $SourceListName
    if ($null -eq $srcList) {
        Write-Host "  [FAIL] source list '$SourceListName' not found for lookup '$InternalName'" -ForegroundColor Red
        $script:failedFields += [PSCustomObject]@{ List = $List; Field = $InternalName; Op = "add-lookup"; Error = "source list missing" }
        return
    }
    try {
        $listId = $srcList.Id.ToString()
        if ($Multi) {
            $fieldXml = "<Field Type='LookupMulti' Mult='TRUE' DisplayName='$([System.Security.SecurityElement]::Escape($DisplayName))' Name='$InternalName' List='{$listId}' ShowField='Title' />"
        } else {
            $fieldXml = "<Field Type='Lookup' DisplayName='$([System.Security.SecurityElement]::Escape($DisplayName))' Name='$InternalName' List='{$listId}' ShowField='Title' />"
        }
        Add-PnPFieldFromXml -List $List -FieldXml $fieldXml | Out-Null
        Write-Host "  [added] $InternalName ($(if ($Multi) { 'LookupMulti' } else { 'Lookup' }) -> $SourceListName)" -ForegroundColor Green
        $script:addedFields += "$List/$InternalName"
    } catch {
        Write-Host "  [FAIL] add $InternalName : $($_.Exception.Message)" -ForegroundColor Red
        $script:failedFields += [PSCustomObject]@{ List = $List; Field = $InternalName; Op = "add-lookup"; Error = $_.Exception.Message }
    }
}

function Rename-ListDisplay {
    param([string]$CurrentTitle, [string]$NewTitle)
    $list = Get-PnPListSafe -Name $CurrentTitle
    if ($null -eq $list) {
        Write-Host "  [skip] list '$CurrentTitle' not found." -ForegroundColor DarkGray
        return
    }
    if ($list.Title -eq $NewTitle) {
        Write-Host "  [skip] '$CurrentTitle' already named '$NewTitle'." -ForegroundColor DarkGray
        return
    }
    try {
        Set-PnPList -Identity $CurrentTitle -Title $NewTitle | Out-Null
        Write-Host "  [renamed list] '$CurrentTitle' -> '$NewTitle'" -ForegroundColor Green
        $script:renamedLists += "$CurrentTitle -> $NewTitle"
    } catch {
        Write-Host "  [FAIL] rename list '$CurrentTitle': $($_.Exception.Message)" -ForegroundColor Red
        $script:listFailures += "rename $CurrentTitle : $($_.Exception.Message)"
    }
}

function Remove-FromQuickLaunch {
    param([string]$Title)
    try {
        $nodes = Get-PnPNavigationNode -Location QuickLaunch -ErrorAction Stop
        $matchNodes = $nodes | Where-Object { $_.Title -eq $Title }
        if (-not $matchNodes -or $matchNodes.Count -eq 0) {
            Write-Host "  [skip] no Quick Launch node titled '$Title'." -ForegroundColor DarkGray
            return
        }
        foreach ($n in $matchNodes) {
            Remove-PnPNavigationNode -Identity $n.Id -Force -ErrorAction Stop | Out-Null
            Write-Host "  [nav] removed '$Title' from Quick Launch." -ForegroundColor Green
            $script:navCleanups += $Title
        }
    } catch {
        Write-Host "  [FAIL] nav cleanup '$Title': $($_.Exception.Message)" -ForegroundColor Red
    }
}

# ===========================================================================
# Pre-flight
# ===========================================================================
Write-Host ""
Write-Host "==================== PRE-FLIGHT ====================" -ForegroundColor Cyan
$preflightOk = $true
foreach ($name in @($listStakeholders, $listPCs, $listAcronyms, $listMeetings, $listContracts)) {
    $l = Get-PnPListSafe -Name $name
    if ($null -eq $l) {
        Write-Host "  [MISSING] '$name' not found on this site." -ForegroundColor Red
        $preflightOk = $false
    } else {
        Write-Host "  [ok] '$name' present." -ForegroundColor DarkGray
    }
}
if (-not $preflightOk) {
    Write-Host "Aborting: required list(s) missing. Connect to the right site and retry." -ForegroundColor Red
    return
}

# ===========================================================================
# 1. Stakeholders: rename 17 deprecated fields to [DELETE] prefix
# ===========================================================================
Write-Host ""
Write-Host "==================== STAKEHOLDERS: rename deprecated ====================" -ForegroundColor Magenta

# 6 prior-pass deprecated fields (already had [OLD] prefix)
Rename-FieldDisplay -List $listStakeholders -InternalName "EditingPreference" -NewDisplay "[DELETE] Editing Preference"
Rename-FieldDisplay -List $listStakeholders -InternalName "NoticePreference"  -NewDisplay "[DELETE] Notice Preference"
Rename-FieldDisplay -List $listStakeholders -InternalName "DocumentStyle"     -NewDisplay "[DELETE] Document Style"
Rename-FieldDisplay -List $listStakeholders -InternalName "DecisionStyle"     -NewDisplay "[DELETE] Decision Style"
Rename-FieldDisplay -List $listStakeholders -InternalName "WorkingHours"      -NewDisplay "[DELETE] Working Hours"
Rename-FieldDisplay -List $listStakeholders -InternalName "Quirks"            -NewDisplay "[DELETE] Quirks"

# 11 bad-schema fields from the previous matrix pass
Rename-FieldDisplay -List $listStakeholders -InternalName "EditsLeaveStyle"      -NewDisplay "[DELETE] How I leave edits (use new)"
Rename-FieldDisplay -List $listStakeholders -InternalName "EditsReceiveStyle"    -NewDisplay "[DELETE] How others should leave edits (use new)"
Rename-FieldDisplay -List $listStakeholders -InternalName "DecisionTimingSelf"   -NewDisplay "[DELETE] Time I need (use new)"
Rename-FieldDisplay -List $listStakeholders -InternalName "DecisionTimingOthers" -NewDisplay "[DELETE] Time I'll wait (use new)"
Rename-FieldDisplay -List $listStakeholders -InternalName "InclusionPreference"  -NewDisplay "[DELETE] When to include me (use new)"
Rename-FieldDisplay -List $listStakeholders -InternalName "ReceiveFeedback"      -NewDisplay "[DELETE] Receive feedback (use new)"
Rename-FieldDisplay -List $listStakeholders -InternalName "GiveFeedback"         -NewDisplay "[DELETE] Give feedback (use new)"
Rename-FieldDisplay -List $listStakeholders -InternalName "ReceiveRecognition"   -NewDisplay "[DELETE] Receive recognition (use new)"
Rename-FieldDisplay -List $listStakeholders -InternalName "GiveRecognition"      -NewDisplay "[DELETE] Give recognition (use new)"
Rename-FieldDisplay -List $listStakeholders -InternalName "ThinkerType"          -NewDisplay "[DELETE] Thinker type (use new)"
Rename-FieldDisplay -List $listStakeholders -InternalName "DeepWorkStyle"        -NewDisplay "[DELETE] Deep work style (use new)"

# ===========================================================================
# 2. Stakeholders: add 11 corrected replacement fields (suffix "2")
# ===========================================================================
Write-Host ""
Write-Host "==================== STAKEHOLDERS: add replacements ====================" -ForegroundColor Magenta

# Multi-select Choice fields with matrix wording
$editStyleChoices = @(
    "Edit in Suggestion mode",
    "Leave comments with suggestions for doc owner",
    "Let the document owner decide and communicate"
)
Add-ChoiceField -List $listStakeholders `
    -DisplayName "How I leave edits in shared files" -InternalName "EditsLeaveStyle2" `
    -Choices $editStyleChoices -Multi $true

Add-ChoiceField -List $listStakeholders `
    -DisplayName "How others should leave edits in my files" -InternalName "EditsReceiveStyle2" `
    -Choices $editStyleChoices -Multi $true

# Single Choice with matrix wording
Add-ChoiceField -List $listStakeholders `
    -DisplayName "Time I need between info and decision" -InternalName "DecisionTimingSelf2" `
    -Choices @(
        "I prefer as much lead time as possible for all new information and do not feel comfortable making quick decisions.",
        "I like to think things over for a day.",
        "I'm ok making quick decisions and giving immediate responses MOST of the time"
    ) -Multi $false

Add-ChoiceField -List $listStakeholders `
    -DisplayName "Time I'll wait for others' decisions" -InternalName "DecisionTimingOthers2" `
    -Choices @(
        "I am ok with the people I am requesting work from to prioritize their own response time, as long as I am aware of it and when I can check back in.",
        "I am willing to wait a business day for requests MOST of the time.",
        "I expect immediate responses MOST of the time"
    ) -Multi $false

Add-ChoiceField -List $listStakeholders `
    -DisplayName "When to include me in others' work" -InternalName "InclusionPreference2" `
    -Choices @(
        "Whenever they think I should be included.",
        "At the beginning, when they have the idea",
        "In the middle, when they have something tangible to share",
        "At the beginning, when the idea has been fleshed out and they know it is feasible."
    ) -Multi $false

# Multi-select feedback / recognition with matrix wording
$receiveFeedbackChoices = @(
    "softened with context",
    "private conversation",
    "straight to the point",
    "In the moment",
    "Written first (Slack, Teams, etc)"
)
Add-ChoiceField -List $listStakeholders `
    -DisplayName "How I prefer to RECEIVE corrective feedback" -InternalName "ReceiveFeedback2" `
    -Choices $receiveFeedbackChoices -Multi $true
Add-ChoiceField -List $listStakeholders `
    -DisplayName "How I GIVE corrective feedback" -InternalName "GiveFeedback2" `
    -Choices $receiveFeedbackChoices -Multi $true

$recognitionChoices = @(
    "Public (Slack/Teams channels)",
    "Private 1:1",
    "Email/written to Leadership",
    "Among peers",
    "no preference"
)
Add-ChoiceField -List $listStakeholders `
    -DisplayName "How I prefer to RECEIVE recognition" -InternalName "ReceiveRecognition2" `
    -Choices $recognitionChoices -Multi $true
Add-ChoiceField -List $listStakeholders `
    -DisplayName "How I GIVE recognition" -InternalName "GiveRecognition2" `
    -Choices $recognitionChoices -Multi $true

# ThinkerType as proper MultiChoice
Add-ChoiceField -List $listStakeholders `
    -DisplayName "Type of thinker I am" -InternalName "ThinkerType2" `
    -Choices @(
        "Big picture / strategic (zoom out, see patterns, frame problems)",
        "Detail-oriented / analytical (zoom in, validate, ground in evidence)",
        "Process / sequential (define the steps, run them in order)",
        "Synthesizer / connector (joins disparate threads, sees relationships)",
        "Pragmatic / problem-solver (what's broken, what fixes it)",
        "Creative / generative",
        "Other"
    ) -Multi $true

# DeepWorkStyle as Choice (not Note)
Add-ChoiceField -List $listStakeholders `
    -DisplayName "How I prefer to do deep work" -InternalName "DeepWorkStyle2" `
    -Choices @(
        "I prefer to work through the task ON MY OWN, gather points of discussion, then bring that discussion to the group later.",
        "I prefer to work through the task COLLABORATIVELY, in a group working meeting.",
        "I have no preference"
    ) -Multi $false

# ===========================================================================
# 3. Stakeholders: add 4 brand-new fields
# ===========================================================================
Write-Host ""
Write-Host "==================== STAKEHOLDERS: add new fields ====================" -ForegroundColor Magenta

Add-PersonField -List $listStakeholders -DisplayName "Person" -InternalName "Person"
Add-LookupField -List $listStakeholders -DisplayName "Contracts" -InternalName "Contracts" -SourceListName $listContracts -Multi $true
Add-ChoiceField -List $listStakeholders `
    -DisplayName "When do you prefer to attend meetings?" -InternalName "MeetingTimePreference" `
    -Choices @("no preference", "Morning", "Afternoon") -Multi $false
Add-ChoiceField -List $listStakeholders `
    -DisplayName "Do you consider yourself an overthinker?" -InternalName "Overthinker" `
    -Choices @("yes", "no", "maybe/sometimes") -Multi $false

# ===========================================================================
# 4. PCs: add Person + 23 working-style fields (clean internal names)
# ===========================================================================
Write-Host ""
Write-Host "==================== PCs: add Person + 23 working-style fields ====================" -ForegroundColor Magenta

Add-PersonField -List $listPCs -DisplayName "Person" -InternalName "Person"

# Channels
Add-ChoiceField -List $listPCs `
    -DisplayName "Primary preferred channel" -InternalName "PrimaryChannel" `
    -Choices @("Slack", "Teams", "Email", "Phone call", "In person", "Quick ad hoc tag up", "Office Drop in", "Whatever's easiest", "Varies by topic") `
    -Multi $false -AllowFillIn $true
Add-ChoiceField -List $listPCs `
    -DisplayName "Secondary preferred channel" -InternalName "SecondaryChannel" `
    -Choices @("Slack", "Teams", "Email", "Phone call", "In person", "Quick ad hoc tag up", "Office Drop in", "Whatever's easiest", "Varies by topic", "None") `
    -Multi $false -AllowFillIn $true

# Edits (multi)
Add-ChoiceField -List $listPCs `
    -DisplayName "How I leave edits in shared files" -InternalName "EditsLeaveStyle" `
    -Choices $editStyleChoices -Multi $true
Add-ChoiceField -List $listPCs `
    -DisplayName "How others should leave edits in my files" -InternalName "EditsReceiveStyle" `
    -Choices $editStyleChoices -Multi $true

# Decision timing
Add-ChoiceField -List $listPCs `
    -DisplayName "Time I need between info and decision" -InternalName "DecisionTimingSelf" `
    -Choices @(
        "I prefer as much lead time as possible for all new information and do not feel comfortable making quick decisions.",
        "I like to think things over for a day.",
        "I'm ok making quick decisions and giving immediate responses MOST of the time"
    ) -Multi $false
Add-ChoiceField -List $listPCs `
    -DisplayName "Time I'll wait for others' decisions" -InternalName "DecisionTimingOthers" `
    -Choices @(
        "I am ok with the people I am requesting work from to prioritize their own response time, as long as I am aware of it and when I can check back in.",
        "I am willing to wait a business day for requests MOST of the time.",
        "I expect immediate responses MOST of the time"
    ) -Multi $false
Add-ChoiceField -List $listPCs `
    -DisplayName "How I want decisions framed for me" -InternalName "DecisionFormat" `
    -Choices @(
        "Open discussion / brainstorm together",
        "2-3 options with pros/cons",
        "Single recommendation with the reasoning"
    ) -Multi $false

# Working hours
Add-TextField -List $listPCs -DisplayName "Working day start (preferred timezone)" -InternalName "WorkingHoursStart"
Add-TextField -List $listPCs -DisplayName "Working day end (preferred timezone)"   -InternalName "WorkingHoursEnd"

# Meeting time pref
Add-ChoiceField -List $listPCs `
    -DisplayName "When do you prefer to attend meetings?" -InternalName "MeetingTimePreference" `
    -Choices @("no preference", "Morning", "Afternoon") -Multi $false

# Deep work
Add-ChoiceField -List $listPCs `
    -DisplayName "How I prefer to do deep work" -InternalName "DeepWorkStyle" `
    -Choices @(
        "I prefer to work through the task ON MY OWN, gather points of discussion, then bring that discussion to the group later.",
        "I prefer to work through the task COLLABORATIVELY, in a group working meeting.",
        "I have no preference"
    ) -Multi $false

# Inclusion
Add-ChoiceField -List $listPCs `
    -DisplayName "When to include me in others' work" -InternalName "InclusionPreference" `
    -Choices @(
        "Whenever they think I should be included.",
        "At the beginning, when they have the idea",
        "In the middle, when they have something tangible to share",
        "At the beginning, when the idea has been fleshed out and they know it is feasible."
    ) -Multi $false

# Status cadence
Add-ChoiceField -List $listPCs `
    -DisplayName "Status update cadence I prefer" -InternalName "StatusUpdateCadence" `
    -Choices @("Daily", "Weekly", "Bi-weekly", "Monthly", "Only when blocked", "Real-time channel") -Multi $false

# Processing
Add-ChoiceField -List $listPCs `
    -DisplayName "How I process new info best" -InternalName "ProcessingStyle" `
    -Choices @("write it down", "thinking alone first", "Talk it out", "Combination") -Multi $false

# Thinker (multi)
Add-ChoiceField -List $listPCs `
    -DisplayName "Type of thinker I am" -InternalName "ThinkerType" `
    -Choices @(
        "Big picture / strategic (zoom out, see patterns, frame problems)",
        "Detail-oriented / analytical (zoom in, validate, ground in evidence)",
        "Process / sequential (define the steps, run them in order)",
        "Synthesizer / connector (joins disparate threads, sees relationships)",
        "Pragmatic / problem-solver (what's broken, what fixes it)",
        "Creative / generative",
        "Other"
    ) -Multi $true

# Rabbit trails / overthinker
Add-ChoiceField -List $listPCs -DisplayName "How easily I follow rabbit trails" -InternalName "RabbitTrails" `
    -Choices @("yes", "no", "maybe/sometimes") -Multi $false
Add-ChoiceField -List $listPCs -DisplayName "Do you consider yourself an overthinker?" -InternalName "Overthinker" `
    -Choices @("yes", "no", "maybe/sometimes") -Multi $false

# Feedback (multi)
Add-ChoiceField -List $listPCs `
    -DisplayName "How I prefer to RECEIVE corrective feedback" -InternalName "ReceiveFeedback" `
    -Choices $receiveFeedbackChoices -Multi $true
Add-ChoiceField -List $listPCs `
    -DisplayName "How I GIVE corrective feedback" -InternalName "GiveFeedback" `
    -Choices $receiveFeedbackChoices -Multi $true

# Recognition (multi)
Add-ChoiceField -List $listPCs `
    -DisplayName "How I prefer to RECEIVE recognition" -InternalName "ReceiveRecognition" `
    -Choices $recognitionChoices -Multi $true
Add-ChoiceField -List $listPCs `
    -DisplayName "How I GIVE recognition" -InternalName "GiveRecognition" `
    -Choices $recognitionChoices -Multi $true

# Conflict
Add-ChoiceField -List $listPCs `
    -DisplayName "My default move when conflict arises" -InternalName "ConflictDefault" `
    -Choices @(
        "Sleep on it, then talk",
        "Bring in a third party / mediator",
        "Direct conversation, soon as possible",
        "Wait for them to bring it up",
        "It varies by the person"
    ) -Multi $false

# Comments
Add-NoteField -List $listPCs -DisplayName "Any additional comments on working style" -InternalName "WorkingStyleComments"

# ===========================================================================
# 5. Acronyms: add Contract lookup
# ===========================================================================
Write-Host ""
Write-Host "==================== ACRONYMS: add Contract lookup ====================" -ForegroundColor Magenta
Add-LookupField -List $listAcronyms -DisplayName "Contract" -InternalName "Contract" -SourceListName $listContracts -Multi $false

# ===========================================================================
# 6. Meetings: add Contract lookup
# ===========================================================================
Write-Host ""
Write-Host "==================== MEETINGS: add Contract lookup ====================" -ForegroundColor Magenta
Add-LookupField -List $listMeetings -DisplayName "Contract" -InternalName "Contract" -SourceListName $listContracts -Multi $false

# ===========================================================================
# 7. Lists: rename Equivalency Map / Program-Tool to [ARCHIVED]
# ===========================================================================
Write-Host ""
Write-Host "==================== LISTS: rename + nav cleanup ====================" -ForegroundColor Magenta

# Order matters: archive the broken old map first, THEN rename Real to take its name.
Rename-ListDisplay -CurrentTitle $listEqMapOld   -NewTitle "[ARCHIVED] Equivalency Map"
Rename-ListDisplay -CurrentTitle $listEqMapReal  -NewTitle $listEqMapOld
Rename-ListDisplay -CurrentTitle $listProgramTool -NewTitle "[ARCHIVED] Program-Tool"

# Remove archived entries from Quick Launch
Remove-FromQuickLaunch -Title "[ARCHIVED] Equivalency Map"
Remove-FromQuickLaunch -Title "[ARCHIVED] Program-Tool"
Remove-FromQuickLaunch -Title $listEqMapOld   # in case the original (pre-rename) entry still exists
Remove-FromQuickLaunch -Title $listProgramTool # same

# ===========================================================================
# Summary
# ===========================================================================
Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "                       SUMMARY" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

Write-Host ""
Write-Host "Renamed fields ($($renamedFields.Count)):" -ForegroundColor Green
$renamedFields | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray }

Write-Host ""
Write-Host "Added fields ($($addedFields.Count)):" -ForegroundColor Green
$addedFields | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray }

Write-Host ""
Write-Host "Skipped fields (already present) ($($skippedFields.Count)):" -ForegroundColor Yellow
$skippedFields | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray }

Write-Host ""
Write-Host "Renamed lists ($($renamedLists.Count)):" -ForegroundColor Green
$renamedLists | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray }

Write-Host ""
Write-Host "Quick Launch removals ($($navCleanups.Count)):" -ForegroundColor Green
$navCleanups | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray }

if ($failedFields.Count -gt 0) {
    Write-Host ""
    Write-Host "FAILED field operations ($($failedFields.Count)):" -ForegroundColor Red
    $failedFields | ForEach-Object {
        Write-Host "  [$($_.List)/$($_.Field) $($_.Op)] $($_.Error)" -ForegroundColor Red
    }
}
if ($listFailures.Count -gt 0) {
    Write-Host ""
    Write-Host "FAILED list operations ($($listFailures.Count)):" -ForegroundColor Red
    $listFailures | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "OWNER NEXT STEPS:" -ForegroundColor Yellow
Write-Host "  1. In Stakeholders list settings, delete every field whose display" -ForegroundColor Gray
Write-Host "     name starts with '[DELETE] ' (17 fields total)." -ForegroundColor Gray
Write-Host "  2. Verify the new replacement fields look right in the list view." -ForegroundColor Gray
Write-Host "  3. Manually populate Person column for existing rows by picking the" -ForegroundColor Gray
Write-Host "     real AD user (Contact Name stays as denormalized display backup)." -ForegroundColor Gray
Write-Host "  4. Manually pick Contracts (multi) for each existing Stakeholder row." -ForegroundColor Gray
Write-Host "  5. PCs list now has the full working-style schema. Same drill: Person" -ForegroundColor Gray
Write-Host "     for each existing PC row, then they fill in the matrix questions." -ForegroundColor Gray
Write-Host "  6. Acronyms + Meetings have a Contract column. Tag existing rows" -ForegroundColor Gray
Write-Host "     where the acronym/meeting is contract-specific (leave blank for" -ForegroundColor Gray
Write-Host "     universal items)." -ForegroundColor Gray
Write-Host "============================================================" -ForegroundColor Cyan
