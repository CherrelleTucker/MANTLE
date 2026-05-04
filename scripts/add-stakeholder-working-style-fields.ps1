# Add working-style fields to existing 'Stakeholders' list.
# Assumes: Connect-PnPOnline -UseWebLogin already run against the target site.
# Module: SharePointPnPPowerShellOnline (legacy).
# Does NOT recreate the list. Each field is wrapped in try/catch so existing
# fields are skipped with a friendly message.

$listName = "Stakeholders"

$added   = @()
$skipped = @()
$failed  = @()

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
            # the underlying field object after the field is created.
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

# Verify list exists before attempting any field adds.
try {
    $list = Get-PnPList -Identity $listName -ErrorAction Stop
    Write-Host "Target list found: $listName" -ForegroundColor Cyan
} catch {
    Write-Host "ERROR: list '$listName' not found on this site. Aborting." -ForegroundColor Red
    return
}

# ---------------------------------------------------------------------------
# 1. Preferred channel (Choice, allow fill-in)
# ---------------------------------------------------------------------------
Add-WorkingStyleField `
    -DisplayName "Preferred channel" `
    -InternalName "PreferredChannel" `
    -Type "Choice" `
    -Choices @("Email","Teams chat","In person","Phone call","Slack","Walk-over","Whatever's easiest","Varies by topic") `
    -AllowFillIn $true

# ---------------------------------------------------------------------------
# 2. Editing preference (Choice)
# ---------------------------------------------------------------------------
Add-WorkingStyleField `
    -DisplayName "Editing preference" `
    -InternalName "EditingPreference" `
    -Type "Choice" `
    -Choices @("Suggestions only","Direct edits welcome","Comments only","Either fine","Track changes","Unknown")

# ---------------------------------------------------------------------------
# 3. Notice preference (Choice)
# ---------------------------------------------------------------------------
Add-WorkingStyleField `
    -DisplayName "Notice preference" `
    -InternalName "NoticePreference" `
    -Type "Choice" `
    -Choices @("Same day OK","1-2 days","3-5 days","Week+","Unknown")

# ---------------------------------------------------------------------------
# 4. Document style (Note)
# ---------------------------------------------------------------------------
Add-WorkingStyleField `
    -DisplayName "Document style" `
    -InternalName "DocumentStyle" `
    -Type "Note"

# ---------------------------------------------------------------------------
# 5. Decision style (Note)
# ---------------------------------------------------------------------------
Add-WorkingStyleField `
    -DisplayName "Decision style" `
    -InternalName "DecisionStyle" `
    -Type "Note"

# ---------------------------------------------------------------------------
# 6. Working hours / time zone (Text)
# ---------------------------------------------------------------------------
Add-WorkingStyleField `
    -DisplayName "Working hours / time zone" `
    -InternalName "WorkingHours" `
    -Type "Text"

# ---------------------------------------------------------------------------
# 7. Quirks / things to know (Note)
# ---------------------------------------------------------------------------
Add-WorkingStyleField `
    -DisplayName "Quirks / things to know" `
    -InternalName "Quirks" `
    -Type "Note"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "==================== SUMMARY ====================" -ForegroundColor Cyan
Write-Host "Added   ($($added.Count)): $($added -join ', ')" -ForegroundColor Green
Write-Host "Skipped ($($skipped.Count)): $($skipped -join ', ')" -ForegroundColor Yellow
if ($failed.Count -gt 0) {
    Write-Host "Failed  ($($failed.Count)):" -ForegroundColor Red
    $failed | Format-Table -AutoSize
} else {
    Write-Host "Failed  (0): none" -ForegroundColor Green
}
Write-Host "================================================="
