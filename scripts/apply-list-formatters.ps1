# Apply SharePoint JSON column and view formatters to the MANTLE lists:
# Stakeholders, Meetings, Acronyms.
#
# Goal: make the lists themselves the user-facing browsers (replaces the
# need for separate Team Directory / Meeting Catalog / Acronym Glossary
# rollup pages).
#
# Assumes: Connect-PnPOnline -UseWebLogin already run against the MANTLE site.
# Target site: https://nasa.sharepoint.com/teams/PCTransitionSandbox
#
# Cmdlet versions: legacy SharePointPnPPowerShellOnline (PS 5.1).
#   Uses: Set-PnPField -Values @{ CustomFormatter = <jsonString> }
#
# ASCII-only literals. JSON built as PowerShell here-strings so the inner
# double-quotes can stay as natural JSON quotes; the here-string is then
# passed verbatim to Set-PnPField.
#
# Idempotent: re-running re-applies the same JSON (overwrites prior value).
# Each formatter wrapped in try/catch so one missing field does not abort
# the rest. Per-list summary printed at the end.
#
# Brand palette (Barrios):
#   navy   #182039
#   blue   #0693E3
#   gold   #E8B86A
#   plus support tones for "lighter" / "darker" / gray pills.

# ---------------------------------------------------------------------------
# Counters

$results = @{
    Stakeholders = @{ Applied = 0; Skipped = 0; Failed = 0 }
    Meetings     = @{ Applied = 0; Skipped = 0; Failed = 0 }
    Acronyms     = @{ Applied = 0; Skipped = 0; Failed = 0 }
}

# ---------------------------------------------------------------------------
# Helper: apply one formatter

function Apply-Formatter {
    param(
        [string]$ListName,
        [string]$FieldName,
        [string]$Json,
        [string]$Description
    )

    Write-Host ("  -> {0} :: {1}  ({2})" -f $ListName, $FieldName, $Description)

    try {
        # Confirm field exists before attempting set; some optional
        # columns may not have been provisioned in every environment.
        $field = Get-PnPField -List $ListName -Identity $FieldName -ErrorAction Stop
        if (-not $field) {
            Write-Host ("     SKIP: field '{0}' not found on list '{1}'" -f $FieldName, $ListName) -ForegroundColor Yellow
            $results[$ListName].Skipped++
            return
        }

        Set-PnPField -List $ListName -Identity $FieldName -Values @{ CustomFormatter = $Json } -ErrorAction Stop | Out-Null
        Write-Host "     OK" -ForegroundColor Green
        $results[$ListName].Applied++
    }
    catch {
        if ($_.Exception.Message -match "does not exist|cannot be found|not found") {
            Write-Host ("     SKIP: {0}" -f $_.Exception.Message) -ForegroundColor Yellow
            $results[$ListName].Skipped++
        }
        else {
            Write-Host ("     FAIL: {0}" -f $_.Exception.Message) -ForegroundColor Red
            $results[$ListName].Failed++
        }
    }
}

# ---------------------------------------------------------------------------
# JSON formatters
#
# Schema URL kept at the 2019/04 namespace which the legacy
# SharePointPnPPowerShellOnline module accepts without complaint and which
# every modern SharePoint Online tenant honors. The 2025-02 schema is fine
# in the browser, but older renderers in the legacy module sometimes log
# a schema-fetch warning -- 2019/04 is the safe lowest common denominator.

# ====================== STAKEHOLDERS ====================================

# Influence: High / Medium / Low pill
$jsonInfluence = @'
{
  "$schema": "https://developer.microsoft.com/json-schemas/sp/v2/column-formatting.schema.json",
  "elmType": "div",
  "txtContent": "@currentField",
  "style": {
    "display": "inline-block",
    "padding": "3px 12px",
    "border-radius": "12px",
    "font-size": "12px",
    "font-weight": "600",
    "color": "=if(@currentField == 'High', '#FFFFFF', if(@currentField == 'Medium', '#182039', '#615E5E'))",
    "background-color": "=if(@currentField == 'High', '#182039', if(@currentField == 'Medium', '#E8B86A', '#EDEEF1'))",
    "border": "=if(@currentField == 'Low', '1px solid #E4E4E4', 'none')"
  }
}
'@

# Cadence: subtle gradient pills (Stakeholders cadence values)
$jsonStakeholderCadence = @'
{
  "$schema": "https://developer.microsoft.com/json-schemas/sp/v2/column-formatting.schema.json",
  "elmType": "div",
  "txtContent": "@currentField",
  "style": {
    "display": "inline-block",
    "padding": "3px 10px",
    "border-radius": "10px",
    "font-size": "12px",
    "font-weight": "500",
    "color": "#182039",
    "background": "=if(@currentField == 'Weekly', 'linear-gradient(135deg, #E8B86A33, #E8B86A66)', if(@currentField == 'Biweekly', 'linear-gradient(135deg, #0693E322, #0693E355)', if(@currentField == 'Monthly', 'linear-gradient(135deg, #0693E311, #0693E333)', if(@currentField == 'Quarterly', 'linear-gradient(135deg, #18203911, #18203922)', '#F5F7FA'))))",
    "border": "1px solid #E4E4E4"
  }
}
'@

# LastContact: red text if more than 30 days ago
$jsonLastContact = @'
{
  "$schema": "https://developer.microsoft.com/json-schemas/sp/v2/column-formatting.schema.json",
  "elmType": "div",
  "txtContent": "=if(@currentField == '', '(never)', toLocaleDateString(@currentField))",
  "style": {
    "font-weight": "=if(@currentField == '', '400', if((Number(@now) - Number(@currentField)) / (1000*60*60*24) > 30, '600', '400'))",
    "color": "=if(@currentField == '', '#615E5E', if((Number(@now) - Number(@currentField)) / (1000*60*60*24) > 30, '#B00020', '#182039'))"
  }
}
'@

# Sensitive: show "Restricted" red badge when true, blank when false
$jsonSensitive = @'
{
  "$schema": "https://developer.microsoft.com/json-schemas/sp/v2/column-formatting.schema.json",
  "elmType": "div",
  "txtContent": "=if(@currentField == true, 'Restricted', '')",
  "style": {
    "display": "=if(@currentField == true, 'inline-block', 'none')",
    "padding": "2px 10px",
    "border-radius": "10px",
    "font-size": "11px",
    "font-weight": "700",
    "letter-spacing": "0.5px",
    "color": "#FFFFFF",
    "background-color": "#B00020"
  }
}
'@

# Generic small inline pill -- reused for PreferredChannel, EditingPreference,
# WorkingHours. Neutral palette so any free-text value renders consistently.
$jsonInlinePill = @'
{
  "$schema": "https://developer.microsoft.com/json-schemas/sp/v2/column-formatting.schema.json",
  "elmType": "div",
  "txtContent": "@currentField",
  "style": {
    "display": "=if(@currentField == '', 'none', 'inline-block')",
    "padding": "2px 9px",
    "border-radius": "9px",
    "font-size": "11px",
    "font-weight": "500",
    "color": "#182039",
    "background-color": "#F5F7FA",
    "border": "1px solid #E4E4E4"
  }
}
'@

# ----- Working Styles Matrix formatters (added) -----
#
# Palette tints used below (extending the Barrios base palette):
#   navy        #182039
#   blue        #0693E3
#   gold        #E8B86A
#   lighter blue#7FC9F2  (already used by Meetings cadence)
#   teal        #2BB3A3  (invented -- needed a non-blue cool accent for
#                         "third party" / pragmatic options that should
#                         not collide with blue)
#   purple      #7B5EA7  (invented -- ThinkerType "Synthesizer" needed a
#                         color distinct from navy/blue/gold/teal)
#   urgent red  #B00020  (already used by Sensitive / LastContact)
#   muted gray  #EDEEF1
#   neutral bg  #F5F7FA / border #E4E4E4 (matches $jsonInlinePill)

# DecisionTimingSelf / DecisionTimingOthers -- urgency gradient.
# Right now=red, Same day=blue, 1-2 days=navy, 3-5 days=gold,
# Week+ / As long as needed=muted.
$jsonDecisionTiming = @'
{
  "$schema": "https://developer.microsoft.com/json-schemas/sp/v2/column-formatting.schema.json",
  "elmType": "div",
  "txtContent": "@currentField",
  "style": {
    "display": "=if(@currentField == '', 'none', 'inline-block')",
    "padding": "3px 12px",
    "border-radius": "12px",
    "font-size": "12px",
    "font-weight": "600",
    "color": "=if(@currentField == '3-5 days', '#182039', if(@currentField == 'Week+' || @currentField == 'As long as needed', '#615E5E', '#FFFFFF'))",
    "background-color": "=if(@currentField == 'Right now', '#B00020', if(@currentField == 'Same day', '#0693E3', if(@currentField == '1-2 days', '#182039', if(@currentField == '3-5 days', '#E8B86A', '#EDEEF1'))))"
  }
}
'@

# DecisionFormat -- Single recommendation=navy, Options=blue, Data=gold,
# Discussion=muted, Varies=neutral border.
$jsonDecisionFormat = @'
{
  "$schema": "https://developer.microsoft.com/json-schemas/sp/v2/column-formatting.schema.json",
  "elmType": "div",
  "txtContent": "@currentField",
  "style": {
    "display": "=if(@currentField == '', 'none', 'inline-block')",
    "padding": "3px 12px",
    "border-radius": "12px",
    "font-size": "12px",
    "font-weight": "600",
    "color": "=if(@currentField == 'Data', '#182039', if(@currentField == 'Discussion' || @currentField == 'Varies', '#615E5E', '#FFFFFF'))",
    "background-color": "=if(@currentField == 'Single recommendation', '#182039', if(@currentField == 'Options', '#0693E3', if(@currentField == 'Data', '#E8B86A', if(@currentField == 'Discussion', '#EDEEF1', '#F5F7FA'))))",
    "border": "=if(@currentField == 'Varies', '1px solid #E4E4E4', 'none')"
  }
}
'@

# InclusionPreference -- soft palette, ascending involvement.
$jsonInclusion = @'
{
  "$schema": "https://developer.microsoft.com/json-schemas/sp/v2/column-formatting.schema.json",
  "elmType": "div",
  "txtContent": "@currentField",
  "style": {
    "display": "=if(@currentField == '', 'none', 'inline-block')",
    "padding": "3px 12px",
    "border-radius": "12px",
    "font-size": "12px",
    "font-weight": "600",
    "color": "=if(@currentField == 'At decision points', '#182039', if(@currentField == 'Only outcomes' || @currentField == 'Varies', '#615E5E', '#FFFFFF'))",
    "background-color": "=if(@currentField == 'When asked', '#7FC9F2', if(@currentField == 'At decision points', '#E8B86A', if(@currentField == 'Continuously', '#0693E3', if(@currentField == 'Only outcomes', '#EDEEF1', '#F5F7FA'))))",
    "border": "=if(@currentField == 'Varies', '1px solid #E4E4E4', 'none')"
  }
}
'@

# StatusUpdateCadence -- Daily standup=blue, Weekly=navy, Bi-weekly=lighter blue,
# Monthly=gold, Only when blocked=neutral, Real-time channel=urgent red.
$jsonStatusCadence = @'
{
  "$schema": "https://developer.microsoft.com/json-schemas/sp/v2/column-formatting.schema.json",
  "elmType": "div",
  "txtContent": "@currentField",
  "style": {
    "display": "=if(@currentField == '', 'none', 'inline-block')",
    "padding": "3px 12px",
    "border-radius": "12px",
    "font-size": "12px",
    "font-weight": "600",
    "color": "=if(@currentField == 'Monthly' || @currentField == 'Bi-weekly', '#182039', if(@currentField == 'Only when blocked', '#615E5E', '#FFFFFF'))",
    "background-color": "=if(@currentField == 'Daily standup', '#0693E3', if(@currentField == 'Weekly', '#182039', if(@currentField == 'Bi-weekly', '#7FC9F2', if(@currentField == 'Monthly', '#E8B86A', if(@currentField == 'Real-time channel', '#B00020', '#EDEEF1')))))"
  }
}
'@

# ProcessingStyle -- four-way distinct palette.
$jsonProcessingStyle = @'
{
  "$schema": "https://developer.microsoft.com/json-schemas/sp/v2/column-formatting.schema.json",
  "elmType": "div",
  "txtContent": "@currentField",
  "style": {
    "display": "=if(@currentField == '', 'none', 'inline-block')",
    "padding": "3px 12px",
    "border-radius": "12px",
    "font-size": "12px",
    "font-weight": "600",
    "color": "=if(@currentField == 'Write it down', '#182039', '#FFFFFF')",
    "background-color": "=if(@currentField == 'Talk it out', '#0693E3', if(@currentField == 'Write it down', '#E8B86A', if(@currentField == 'Think alone first', '#182039', if(@currentField == 'Combination', '#2BB3A3', '#EDEEF1'))))"
  }
}
'@

# ThinkerType -- Big picture=navy, Detail-oriented=blue, Creative=gold,
# Pragmatic=teal, Synthesizer=purple, Process=neutral.
$jsonThinkerType = @'
{
  "$schema": "https://developer.microsoft.com/json-schemas/sp/v2/column-formatting.schema.json",
  "elmType": "div",
  "txtContent": "@currentField",
  "style": {
    "display": "=if(@currentField == '', 'none', 'inline-block')",
    "padding": "3px 12px",
    "border-radius": "12px",
    "font-size": "12px",
    "font-weight": "600",
    "color": "=if(@currentField == 'Creative', '#182039', if(@currentField == 'Process', '#615E5E', '#FFFFFF'))",
    "background-color": "=if(@currentField == 'Big picture', '#182039', if(@currentField == 'Detail-oriented', '#0693E3', if(@currentField == 'Creative', '#E8B86A', if(@currentField == 'Pragmatic', '#2BB3A3', if(@currentField == 'Synthesizer', '#7B5EA7', '#EDEEF1')))))"
  }
}
'@

# RabbitTrails -- Yes - easily=red, Sometimes=gold, Rarely=blue,
# No - laser focused=navy.
$jsonRabbitTrails = @'
{
  "$schema": "https://developer.microsoft.com/json-schemas/sp/v2/column-formatting.schema.json",
  "elmType": "div",
  "txtContent": "@currentField",
  "style": {
    "display": "=if(@currentField == '', 'none', 'inline-block')",
    "padding": "3px 12px",
    "border-radius": "12px",
    "font-size": "12px",
    "font-weight": "600",
    "color": "=if(@currentField == 'Sometimes', '#182039', '#FFFFFF')",
    "background-color": "=if(@currentField == 'Yes - easily', '#B00020', if(@currentField == 'Sometimes', '#E8B86A', if(@currentField == 'Rarely', '#0693E3', if(@currentField == 'No - laser focused', '#182039', '#EDEEF1'))))"
  }
}
'@

# Feedback (give & receive use the SAME palette to emphasize symmetry).
# Direct in moment=red, Direct in private=navy, Written first=blue,
# Softened with context=gold, Through a peer=teal.
$jsonFeedback = @'
{
  "$schema": "https://developer.microsoft.com/json-schemas/sp/v2/column-formatting.schema.json",
  "elmType": "div",
  "txtContent": "@currentField",
  "style": {
    "display": "=if(@currentField == '', 'none', 'inline-block')",
    "padding": "3px 12px",
    "border-radius": "12px",
    "font-size": "12px",
    "font-weight": "600",
    "color": "=if(@currentField == 'Softened with context', '#182039', '#FFFFFF')",
    "background-color": "=if(@currentField == 'Direct in moment', '#B00020', if(@currentField == 'Direct in private', '#182039', if(@currentField == 'Written first', '#0693E3', if(@currentField == 'Softened with context', '#E8B86A', if(@currentField == 'Through a peer', '#2BB3A3', '#EDEEF1')))))"
  }
}
'@

# Recognition (give & receive share palette).
# Public Slack/Teams=blue, Private 1:1=navy, Email or written=gold,
# From leadership=purple, Among peers=teal, Don't need it=muted.
$jsonRecognition = @'
{
  "$schema": "https://developer.microsoft.com/json-schemas/sp/v2/column-formatting.schema.json",
  "elmType": "div",
  "txtContent": "@currentField",
  "style": {
    "display": "=if(@currentField == '', 'none', 'inline-block')",
    "padding": "3px 12px",
    "border-radius": "12px",
    "font-size": "12px",
    "font-weight": "600",
    "color": "=if(@currentField == 'Email or written', '#182039', if(@currentField == \"Don't need it\", '#615E5E', '#FFFFFF'))",
    "background-color": "=if(@currentField == 'Public Slack/Teams', '#0693E3', if(@currentField == 'Private 1:1', '#182039', if(@currentField == 'Email or written', '#E8B86A', if(@currentField == 'From leadership', '#7B5EA7', if(@currentField == 'Among peers', '#2BB3A3', '#EDEEF1')))))"
  }
}
'@

# ConflictDefault -- Direct conversation soon=navy, Sleep on it=blue,
# Write down first=gold, Bring in third party=teal, Wait for them=muted,
# Varies=neutral border.
$jsonConflictDefault = @'
{
  "$schema": "https://developer.microsoft.com/json-schemas/sp/v2/column-formatting.schema.json",
  "elmType": "div",
  "txtContent": "@currentField",
  "style": {
    "display": "=if(@currentField == '', 'none', 'inline-block')",
    "padding": "3px 12px",
    "border-radius": "12px",
    "font-size": "12px",
    "font-weight": "600",
    "color": "=if(@currentField == 'Write down first', '#182039', if(@currentField == 'Wait for them' || @currentField == 'Varies', '#615E5E', '#FFFFFF'))",
    "background-color": "=if(@currentField == 'Direct conversation soon', '#182039', if(@currentField == 'Sleep on it', '#0693E3', if(@currentField == 'Write down first', '#E8B86A', if(@currentField == 'Bring in third party', '#2BB3A3', if(@currentField == 'Wait for them', '#EDEEF1', '#F5F7FA')))))",
    "border": "=if(@currentField == 'Varies', '1px solid #E4E4E4', 'none')"
  }
}
'@

# ====================== MEETINGS ========================================

# Cadence: Daily=blue, Weekly=navy, Monthly=gold, Quarterly=lighter blue, Ad hoc=gray
$jsonMeetingCadence = @'
{
  "$schema": "https://developer.microsoft.com/json-schemas/sp/v2/column-formatting.schema.json",
  "elmType": "div",
  "txtContent": "@currentField",
  "style": {
    "display": "inline-block",
    "padding": "3px 12px",
    "border-radius": "12px",
    "font-size": "12px",
    "font-weight": "600",
    "color": "=if(@currentField == 'Monthly', '#182039', if(@currentField == 'Ad hoc', '#615E5E', '#FFFFFF'))",
    "background-color": "=if(@currentField == 'Daily', '#0693E3', if(@currentField == 'Weekly', '#182039', if(@currentField == 'Monthly', '#E8B86A', if(@currentField == 'Quarterly', '#7FC9F2', '#EDEEF1'))))"
  }
}
'@

# MeetingType: Internal=navy, External=gold, Reporting=blue, Informational=gray
$jsonMeetingType = @'
{
  "$schema": "https://developer.microsoft.com/json-schemas/sp/v2/column-formatting.schema.json",
  "elmType": "div",
  "txtContent": "@currentField",
  "style": {
    "display": "inline-block",
    "padding": "3px 12px",
    "border-radius": "12px",
    "font-size": "12px",
    "font-weight": "600",
    "color": "=if(@currentField == 'External', '#182039', if(@currentField == 'Informational', '#615E5E', '#FFFFFF'))",
    "background-color": "=if(@currentField == 'Internal', '#182039', if(@currentField == 'External', '#E8B86A', if(@currentField == 'Reporting', '#0693E3', '#EDEEF1')))"
  }
}
'@

# PCRole: Lead=navy, Co-lead=blue, Participant=light gray, Observer=gray, Optional=lighter gray
$jsonPCRole = @'
{
  "$schema": "https://developer.microsoft.com/json-schemas/sp/v2/column-formatting.schema.json",
  "elmType": "div",
  "txtContent": "@currentField",
  "style": {
    "display": "inline-block",
    "padding": "3px 12px",
    "border-radius": "12px",
    "font-size": "12px",
    "font-weight": "600",
    "color": "=if(@currentField == 'Lead' || @currentField == 'Co-lead', '#FFFFFF', '#182039')",
    "background-color": "=if(@currentField == 'Lead', '#182039', if(@currentField == 'Co-lead', '#0693E3', if(@currentField == 'Participant', '#EDEEF1', if(@currentField == 'Observer', '#D6D8DD', '#F5F7FA'))))",
    "border": "=if(@currentField == 'Optional', '1px dashed #B5B8BF', 'none')"
  }
}
'@

# ====================== ACRONYMS ========================================

# AcronymContext: Agency=navy, Center=blue, Program=gold, Project=darker gold, Industry=gray
$jsonAcronymContext = @'
{
  "$schema": "https://developer.microsoft.com/json-schemas/sp/v2/column-formatting.schema.json",
  "elmType": "div",
  "txtContent": "@currentField",
  "style": {
    "display": "inline-block",
    "padding": "3px 12px",
    "border-radius": "12px",
    "font-size": "12px",
    "font-weight": "600",
    "color": "=if(@currentField == 'Program' || @currentField == 'Project', '#182039', if(@currentField == 'Industry', '#615E5E', '#FFFFFF'))",
    "background-color": "=if(@currentField == 'Agency', '#182039', if(@currentField == 'Center', '#0693E3', if(@currentField == 'Program', '#E8B86A', if(@currentField == 'Project', '#C99548', '#EDEEF1'))))"
  }
}
'@

# ---------------------------------------------------------------------------
# Apply all formatters

Write-Host ""
Write-Host "==> Stakeholders list" -ForegroundColor Cyan
Apply-Formatter -ListName "Stakeholders" -FieldName "Influence"           -Json $jsonInfluence           -Description "High/Medium/Low pill"
Apply-Formatter -ListName "Stakeholders" -FieldName "Cadence"             -Json $jsonStakeholderCadence  -Description "cadence gradient pill"
Apply-Formatter -ListName "Stakeholders" -FieldName "LastContact"         -Json $jsonLastContact         -Description "red if > 30d stale"
Apply-Formatter -ListName "Stakeholders" -FieldName "Sensitive"           -Json $jsonSensitive           -Description "Restricted badge"
Apply-Formatter -ListName "Stakeholders" -FieldName "PreferredChannel"    -Json $jsonInlinePill          -Description "inline pill"
Apply-Formatter -ListName "Stakeholders" -FieldName "EditingPreference"   -Json $jsonInlinePill          -Description "inline pill"
Apply-Formatter -ListName "Stakeholders" -FieldName "WorkingHours"        -Json $jsonInlinePill          -Description "inline pill"

# Working Styles Matrix fields (added)
Apply-Formatter -ListName "Stakeholders" -FieldName "SecondaryChannel"    -Json $jsonInlinePill          -Description "inline pill (secondary channel)"
Apply-Formatter -ListName "Stakeholders" -FieldName "EditsLeaveStyle"     -Json $jsonInlinePill          -Description "inline pill (edits leave)"
Apply-Formatter -ListName "Stakeholders" -FieldName "EditsReceiveStyle"   -Json $jsonInlinePill          -Description "inline pill (edits receive)"
Apply-Formatter -ListName "Stakeholders" -FieldName "DecisionTimingSelf"  -Json $jsonDecisionTiming      -Description "urgency gradient pill"
Apply-Formatter -ListName "Stakeholders" -FieldName "DecisionTimingOthers" -Json $jsonDecisionTiming     -Description "urgency gradient pill"
Apply-Formatter -ListName "Stakeholders" -FieldName "DecisionFormat"      -Json $jsonDecisionFormat      -Description "decision format pill"
Apply-Formatter -ListName "Stakeholders" -FieldName "InclusionPreference" -Json $jsonInclusion           -Description "inclusion pill"
Apply-Formatter -ListName "Stakeholders" -FieldName "StatusUpdateCadence" -Json $jsonStatusCadence       -Description "status cadence pill"
Apply-Formatter -ListName "Stakeholders" -FieldName "ProcessingStyle"     -Json $jsonProcessingStyle     -Description "processing style pill"
Apply-Formatter -ListName "Stakeholders" -FieldName "ThinkerType"         -Json $jsonThinkerType         -Description "thinker type pill"
Apply-Formatter -ListName "Stakeholders" -FieldName "RabbitTrails"        -Json $jsonRabbitTrails        -Description "rabbit trails pill"
Apply-Formatter -ListName "Stakeholders" -FieldName "ReceiveFeedback"     -Json $jsonFeedback            -Description "feedback pill (receive)"
Apply-Formatter -ListName "Stakeholders" -FieldName "GiveFeedback"        -Json $jsonFeedback            -Description "feedback pill (give, same palette)"
Apply-Formatter -ListName "Stakeholders" -FieldName "ReceiveRecognition"  -Json $jsonRecognition         -Description "recognition pill (receive)"
Apply-Formatter -ListName "Stakeholders" -FieldName "GiveRecognition"     -Json $jsonRecognition         -Description "recognition pill (give, same palette)"
Apply-Formatter -ListName "Stakeholders" -FieldName "ConflictDefault"     -Json $jsonConflictDefault     -Description "conflict default pill"

Write-Host ""
Write-Host "==> Meetings list" -ForegroundColor Cyan
Apply-Formatter -ListName "Meetings"     -FieldName "Cadence"             -Json $jsonMeetingCadence      -Description "Daily/Weekly/Monthly/Quarterly/Ad hoc pill"
Apply-Formatter -ListName "Meetings"     -FieldName "MeetingType"         -Json $jsonMeetingType         -Description "Internal/External/Reporting/Informational pill"
Apply-Formatter -ListName "Meetings"     -FieldName "PCRole"              -Json $jsonPCRole              -Description "Lead/Co-lead/Participant/Observer/Optional pill"

Write-Host ""
Write-Host "==> Acronyms list" -ForegroundColor Cyan
Apply-Formatter -ListName "Acronyms"     -FieldName "AcronymContext"      -Json $jsonAcronymContext      -Description "Agency/Center/Program/Project/Industry pill"

# ---------------------------------------------------------------------------
# Summary

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "Formatter application summary" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
foreach ($listName in @("Stakeholders", "Meetings", "Acronyms")) {
    $r = $results[$listName]
    Write-Host ("  {0,-14}  applied: {1}   skipped: {2}   failed: {3}" -f $listName, $r.Applied, $r.Skipped, $r.Failed)
}
Write-Host ""
Write-Host "Done. Refresh the list in the browser to see the formatters." -ForegroundColor Green
Write-Host "If a formatter looks wrong, edit it directly via the column"
Write-Host "header > Column settings > Format this column > Advanced mode."
