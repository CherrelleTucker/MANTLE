# Stakeholders import diagnostic

Run this in PowerShell (with `Connect-PnPOnline -UseWebLogin` already done) to dump every imported row's stored values per field. Helps diagnose whether the bad import wrote wrong values, blanked them out (choice-rejection), or duplicated values across columns.

## Quick row-by-row dump

```powershell
$items = Get-PnPListItem -List "Stakeholders" -Fields "Title","PreferredChannel","SecondaryChannel","EditsLeaveStyle2","EditsReceiveStyle2","DecisionTimingSelf2","DecisionTimingOthers2","DecisionFormat","WorkingHoursStart","WorkingHoursEnd","MeetingTimePreference","DeepWorkStyle2","InclusionPreference2","StatusUpdateCadence","ProcessingStyle","ThinkerType2","RabbitTrails","Overthinker","ReceiveFeedback2","GiveFeedback2","ReceiveRecognition2","GiveRecognition2","ConflictDefault","WorkingStyleComments"

foreach ($it in $items) {
    $title = $it.FieldValues["Title"]
    if ([string]::IsNullOrWhiteSpace($title)) { continue }
    Write-Host ""
    Write-Host "=== $title ===" -ForegroundColor Cyan
    foreach ($field in @("PreferredChannel","SecondaryChannel","EditsLeaveStyle2","EditsReceiveStyle2","DecisionTimingSelf2","DecisionTimingOthers2","DecisionFormat","WorkingHoursStart","WorkingHoursEnd","MeetingTimePreference","DeepWorkStyle2","InclusionPreference2","StatusUpdateCadence","ProcessingStyle","ThinkerType2","RabbitTrails","Overthinker","ReceiveFeedback2","GiveFeedback2","ReceiveRecognition2","GiveRecognition2","ConflictDefault","WorkingStyleComments")) {
        $val = $it.FieldValues[$field]
        if ($val -is [array]) { $val = ($val -join " | ") }
        if ([string]::IsNullOrWhiteSpace($val)) { $val = "(blank)" }
        if ($val.Length -gt 80) { $val = $val.Substring(0, 77) + "..." }
        Write-Host ("  {0,-22} : {1}" -f $field, $val) -ForegroundColor Gray
    }
}
```

## Row count check

```powershell
(Get-PnPListItem -List "Stakeholders").Count
```

Was 6 before the import. If it's ~24 now, the import inserted ~18 new rows (matrix people whose names didn't match any existing Contact Name).
