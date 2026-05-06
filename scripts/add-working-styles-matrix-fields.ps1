# Add comprehensive Working Styles Matrix fields to existing 'Stakeholders' list.
# Assumes: Connect-PnPOnline -UseWebLogin already run against the target site.
# Module: SharePointPnPPowerShellOnline (legacy).
#
# Two-pass script:
#   PASS 1 - rename DISPLAY name of 6 prior-pass fields to '[OLD] ...' so the
#            UI clearly steers users to the new fields. Internal names are NOT
#            changed (preserves existing data + backward compatibility).
#   PASS 2 - add 20 new fields per Cherrelle's Working Styles Matrix spec.
#            Each field is wrapped in try/catch so existing fields are skipped
#            with a friendly message (idempotent / re-runnable).
#
# Note on multi-select Choice (ThinkerType, item #13):
#   The legacy SharePointPnPPowerShellOnline 'Add-PnPField' cmdlet does NOT
#   expose -Type MultiChoice in a way that reliably round-trips with the
#   FillInChoice flag. To keep the script safe and idempotent, ThinkerType is
#   created as a single-Choice field with FillInChoice=$true, and users are
#   instructed (via the displayed help text in the form) to enter
#   comma-separated values when more than one applies. This matches the same
#   CSOM cast pattern already used for PreferredChannel in the prior pass.

$listName = "Stakeholders"

$added    = @()
$skipped  = @()
$failed   = @()
$renamed  = @()
$rskipped = @()
$rfailed  = @()

function Test-PnPFieldExists {
    param(
        [string]$List,
        [string]$InternalName
    )
    try {
        $f = Get-PnPField -List $List -Identity $InternalName -ErrorAction Stop
        return ($null -ne $f)
    } catch {
        return $false
    }
}

function Rename-DeprecatedField {
    param(
        [string]$InternalName,
        [string]$NewDisplayName
    )

    Write-Host ""
    Write-Host "--- Rename '$InternalName' -> '$NewDisplayName' ---" -ForegroundColor Cyan

    if (-not (Test-PnPFieldExists -List $script:listName -InternalName $InternalName)) {
        Write-Host "Field '$InternalName' not found on '$script:listName'. Skipping rename." -ForegroundColor Yellow
        $script:rskipped += $InternalName
        return
    }

    try {
        $current = Get-PnPField -List $script:listName -Identity $InternalName -ErrorAction Stop
        if ($current.Title -eq $NewDisplayName) {
            Write-Host "Field '$InternalName' already has display name '$NewDisplayName'. Skipping." -ForegroundColor Yellow
            $script:rskipped += $InternalName
            return
        }

        Set-PnPField -List $script:listName -Identity $InternalName -Values @{ Title = $NewDisplayName } | Out-Null
        Write-Host "Renamed '$InternalName' display to '$NewDisplayName'." -ForegroundColor Green
        $script:renamed += $InternalName
    } catch {
        Write-Host "FAILED rename '$InternalName': $($_.Exception.Message)" -ForegroundColor Red
        $script:rfailed += [PSCustomObject]@{ Field = $InternalName; Error = $_.Exception.Message }
    }
}

function Add-WorkingStyleField {
    param(
        [string]$DisplayName,
        [string]$InternalName,
        [string]$Type,
        [string[]]$Choices,
        [bool]$AllowFillIn = $false
    )

    Write-Host ""
    Write-Host "--- $DisplayName ($InternalName) ---" -ForegroundColor Cyan

    if (Test-PnPFieldExists -List $script:listName -InternalName $InternalName) {
        Write-Host "Field '$InternalName' already exists on '$script:listName'. Skipping." -ForegroundColor Yellow
        $script:skipped += $InternalName
        return
    }

    try {
        if ($Type -eq "Choice") {
            Add-PnPField -List $script:listName -DisplayName $DisplayName -InternalName $InternalName -Type Choice -Choices $Choices -AddToDefaultView | Out-Null

            # Legacy SharePointPnPPowerShellOnline 'Add-PnPField' does not expose
            # a -FillInChoice parameter. If allow-fill-in is needed, set it via
            # the underlying field object after the field is created. Same CSOM
            # cast pattern already used for PreferredChannel.
            if ($AllowFillIn) {
                try {
                    $ctx = Get-PnPContext
                    $field = Get-PnPField -List $script:listName -Identity $InternalName -ErrorAction Stop
                    $choiceField = [Microsoft.SharePoint.Client.FieldChoice]$ctx.CastTo($field, [Microsoft.SharePoint.Client.FieldChoice])
                    $choiceField.FillInChoice = $true
                    $choiceField.Update()
                    $ctx.ExecuteQuery()
                    Write-Host "  FillInChoice enabled on '$InternalName'." -ForegroundColor DarkGray
                } catch {
                    Write-Host "  WARNING: could not set FillInChoice on '$InternalName': $($_.Exception.Message)" -ForegroundColor Yellow
                    Write-Host "  You may need to enable 'allow fill-in choices' manually in list settings." -ForegroundColor Yellow
                }
            }
        }
        elseif ($Type -eq "Text") {
            Add-PnPField -List $script:listName -DisplayName $DisplayName -InternalName $InternalName -Type Text -AddToDefaultView | Out-Null
        }
        elseif ($Type -eq "Note") {
            Add-PnPField -List $script:listName -DisplayName $DisplayName -InternalName $InternalName -Type Note | Out-Null
        }
        else {
            throw "Unsupported field type '$Type'"
        }

        Write-Host "Added '$InternalName'." -ForegroundColor Green
        $script:added += $InternalName
    } catch {
        Write-Host "FAILED '$InternalName': $($_.Exception.Message)" -ForegroundColor Red
        $script:failed += [PSCustomObject]@{ Field = $InternalName; Error = $_.Exception.Message }
    }
}

# Verify list exists before doing anything.
try {
    $list = Get-PnPList -Identity $listName -ErrorAction Stop
    Write-Host "Target list found: $listName" -ForegroundColor Cyan
} catch {
    Write-Host "ERROR: list '$listName' not found on this site. Aborting." -ForegroundColor Red
    return
}

# ===========================================================================
# PASS 1: Rename deprecated prior-pass fields ([OLD] prefix on display name).
# Internal names stay the same so existing data is preserved.
# PreferredChannel is intentionally NOT renamed - it still matches the new Q2.
# ===========================================================================
Write-Host ""
Write-Host "============== PASS 1: rename deprecated fields ==============" -ForegroundColor Magenta

Rename-DeprecatedField -InternalName "EditingPreference" -NewDisplayName "[OLD] Editing Preference (use EditsReceiveStyle)"
Rename-DeprecatedField -InternalName "NoticePreference"  -NewDisplayName "[OLD] Notice Preference (use DecisionTimingOthers)"
Rename-DeprecatedField -InternalName "DocumentStyle"     -NewDisplayName "[OLD] Document Style (use WorkingStyleComments)"
Rename-DeprecatedField -InternalName "DecisionStyle"     -NewDisplayName "[OLD] Decision Style (use WorkingStyleComments)"
Rename-DeprecatedField -InternalName "Quirks"            -NewDisplayName "[OLD] Quirks (use WorkingStyleComments)"
Rename-DeprecatedField -InternalName "WorkingHours"      -NewDisplayName "[OLD] Working Hours (use WorkingHoursStart + End)"

# ===========================================================================
# PASS 2: Add new Working Styles Matrix fields.
# ===========================================================================
Write-Host ""
Write-Host "============== PASS 2: add new matrix fields ==============" -ForegroundColor Magenta

# ---------------------------------------------------------------------------
# 1. Secondary preferred channel (Choice, allow fill-in)
# ---------------------------------------------------------------------------
Add-WorkingStyleField `
    -DisplayName "Secondary preferred channel" `
    -InternalName "SecondaryChannel" `
    -Type "Choice" `
    -Choices @("Email","Teams chat","In person","Phone call","Slack","Walk-over","Whatever's easiest","Varies by topic","None") `
    -AllowFillIn $true

# ---------------------------------------------------------------------------
# 2. How I leave edits in others' files (Choice)
# ---------------------------------------------------------------------------
Add-WorkingStyleField `
    -DisplayName "How I leave edits in others' files" `
    -InternalName "EditsLeaveStyle" `
    -Type "Choice" `
    -Choices @("Suggestions","Direct edits","Comments","Track changes","Either fine","Varies")

# ---------------------------------------------------------------------------
# 3. How others should leave edits in my files (Choice)
# ---------------------------------------------------------------------------
Add-WorkingStyleField `
    -DisplayName "How others should leave edits in my files" `
    -InternalName "EditsReceiveStyle" `
    -Type "Choice" `
    -Choices @("Suggestions only","Direct edits welcome","Comments only","Track changes","Either fine","Varies")

# ---------------------------------------------------------------------------
# 4. Time I need between info and decision (Choice)
# ---------------------------------------------------------------------------
Add-WorkingStyleField `
    -DisplayName "Time I need between info and decision" `
    -InternalName "DecisionTimingSelf" `
    -Type "Choice" `
    -Choices @("Right now","Same day","1-2 days","3-5 days","A week+","As long as needed")

# ---------------------------------------------------------------------------
# 5. Time I'll wait for others' decisions (Choice)
# ---------------------------------------------------------------------------
Add-WorkingStyleField `
    -DisplayName "Time I'll wait for others' decisions" `
    -InternalName "DecisionTimingOthers" `
    -Type "Choice" `
    -Choices @("Same day OK","1-2 days","3-5 days","A week+","Varies","Unknown")

# ---------------------------------------------------------------------------
# 6. How I want decisions framed for me (Choice)
# ---------------------------------------------------------------------------
Add-WorkingStyleField `
    -DisplayName "How I want decisions framed for me" `
    -InternalName "DecisionFormat" `
    -Type "Choice" `
    -Choices @("Single recommendation","2-3 options with pros and cons","Just data","Open discussion","Varies")

# ---------------------------------------------------------------------------
# 7. Working day start (Text, e.g. "9 AM CT")
# ---------------------------------------------------------------------------
Add-WorkingStyleField `
    -DisplayName "Working day start (preferred timezone)" `
    -InternalName "WorkingHoursStart" `
    -Type "Text"

# ---------------------------------------------------------------------------
# 8. Working day end (Text, e.g. "5 PM CT")
# ---------------------------------------------------------------------------
Add-WorkingStyleField `
    -DisplayName "Working day end (preferred timezone)" `
    -InternalName "WorkingHoursEnd" `
    -Type "Text"

# ---------------------------------------------------------------------------
# 9. How I prefer to do deep work (Note)
# ---------------------------------------------------------------------------
Add-WorkingStyleField `
    -DisplayName "How I prefer to do deep work" `
    -InternalName "DeepWorkStyle" `
    -Type "Note"

# ---------------------------------------------------------------------------
# 10. When to include me in others' work (Choice)
# ---------------------------------------------------------------------------
Add-WorkingStyleField `
    -DisplayName "When to include me in others' work" `
    -InternalName "InclusionPreference" `
    -Type "Choice" `
    -Choices @("When asked","At decision points","Continuously","Only outcomes","Varies")

# ---------------------------------------------------------------------------
# 11. Status update cadence I prefer (Choice)
# ---------------------------------------------------------------------------
Add-WorkingStyleField `
    -DisplayName "Status update cadence I prefer" `
    -InternalName "StatusUpdateCadence" `
    -Type "Choice" `
    -Choices @("Daily standup","Weekly written","Bi-weekly","Monthly","Only when blocked","Real-time channel")

# ---------------------------------------------------------------------------
# 12. How I process new info best (Choice)
# ---------------------------------------------------------------------------
Add-WorkingStyleField `
    -DisplayName "How I process new info best" `
    -InternalName "ProcessingStyle" `
    -Type "Choice" `
    -Choices @("Talk it out","Write it down","Think alone first","Combination")

# ---------------------------------------------------------------------------
# 13. Type of thinker I am (Choice, allow fill-in; multi-select via comma)
#     See header note: legacy module multi-Choice is unreliable, so this is
#     a single-Choice + FillInChoice. Users enter multiple values comma-separated.
# ---------------------------------------------------------------------------
Add-WorkingStyleField `
    -DisplayName "Type of thinker I am (comma-separate if more than one)" `
    -InternalName "ThinkerType" `
    -Type "Choice" `
    -Choices @("Big picture","Detail-oriented","Creative","Pragmatic","Synthesizer","Process or sequential","Other") `
    -AllowFillIn $true

# ---------------------------------------------------------------------------
# 14. How easily I follow rabbit trails (Choice)
# ---------------------------------------------------------------------------
Add-WorkingStyleField `
    -DisplayName "How easily I follow rabbit trails" `
    -InternalName "RabbitTrails" `
    -Type "Choice" `
    -Choices @("Yes - easily","Sometimes","Rarely","No - laser focused")

# ---------------------------------------------------------------------------
# 15. How I prefer to RECEIVE corrective feedback (Choice)
# ---------------------------------------------------------------------------
Add-WorkingStyleField `
    -DisplayName "How I prefer to RECEIVE corrective feedback" `
    -InternalName "ReceiveFeedback" `
    -Type "Choice" `
    -Choices @("Direct in the moment","Direct in private","Written first","Softened with context","Through a peer")

# ---------------------------------------------------------------------------
# 16. How I GIVE corrective feedback (Choice)
# ---------------------------------------------------------------------------
Add-WorkingStyleField `
    -DisplayName "How I GIVE corrective feedback" `
    -InternalName "GiveFeedback" `
    -Type "Choice" `
    -Choices @("Direct in the moment","Direct in private","Written first","Softened with context","Through a peer")

# ---------------------------------------------------------------------------
# 17. How I prefer to RECEIVE recognition (Choice)
# ---------------------------------------------------------------------------
Add-WorkingStyleField `
    -DisplayName "How I prefer to RECEIVE recognition" `
    -InternalName "ReceiveRecognition" `
    -Type "Choice" `
    -Choices @("Public Slack/Teams","Private 1:1","Email or written","From leadership","Among peers","Don't need it")

# ---------------------------------------------------------------------------
# 18. How I GIVE recognition (Choice)
# ---------------------------------------------------------------------------
Add-WorkingStyleField `
    -DisplayName "How I GIVE recognition" `
    -InternalName "GiveRecognition" `
    -Type "Choice" `
    -Choices @("Public Slack/Teams","Private 1:1","Email or written","From leadership","Among peers","Don't typically")

# ---------------------------------------------------------------------------
# 19. My default move when conflict arises (Choice)
# ---------------------------------------------------------------------------
Add-WorkingStyleField `
    -DisplayName "My default move when conflict arises" `
    -InternalName "ConflictDefault" `
    -Type "Choice" `
    -Choices @("Direct conversation soon","Sleep on it then talk","Write down first","Bring in third party","Wait for them","Varies by person")

# ---------------------------------------------------------------------------
# 20. Any additional comments on working style (Note)
# ---------------------------------------------------------------------------
Add-WorkingStyleField `
    -DisplayName "Any additional comments on working style" `
    -InternalName "WorkingStyleComments" `
    -Type "Note"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "==================== SUMMARY ====================" -ForegroundColor Cyan
Write-Host ""
Write-Host "PASS 1 (rename deprecated):"
Write-Host "  Renamed ($($renamed.Count)): $($renamed -join ', ')" -ForegroundColor Green
Write-Host "  Skipped ($($rskipped.Count)): $($rskipped -join ', ')" -ForegroundColor Yellow
if ($rfailed.Count -gt 0) {
    Write-Host "  Failed  ($($rfailed.Count)):" -ForegroundColor Red
    $rfailed | Format-Table -AutoSize
} else {
    Write-Host "  Failed  (0): none" -ForegroundColor Green
}
Write-Host ""
Write-Host "PASS 2 (add new fields):"
Write-Host "  Added   ($($added.Count)): $($added -join ', ')" -ForegroundColor Green
Write-Host "  Skipped ($($skipped.Count)): $($skipped -join ', ')" -ForegroundColor Yellow
if ($failed.Count -gt 0) {
    Write-Host "  Failed  ($($failed.Count)):" -ForegroundColor Red
    $failed | Format-Table -AutoSize
} else {
    Write-Host "  Failed  (0): none" -ForegroundColor Green
}
Write-Host "================================================="
