# Populate the Training Resources URL field on the Tools list.
#
# Matches each tool by Title. Updates the TrainingResources field with the
# official getting-started / help URL for that tool. Skips tools where the
# title is not in the mapping (e.g., NASA-internal systems you'll fill in
# manually).
#
# Edit the $map hashtable below to change any URLs to your preferred ones,
# or to add NASA-internal systems (NISM, NSITE MO Viewer, NASA-GPT, etc.).
#
# Idempotent: safe to re-run. Re-applies the same URLs.
#
# Module: legacy SharePointPnPPowerShellOnline.
# Assumes: Connect-PnPOnline -UseWebLogin already done.

param(
    [string]$ListName = "Tools",
    [switch]$OverwriteExisting = $false  # if false, skip rows that already have a URL
)

$map = @{
    # ------- Google Workspace -------
    "Gmail"                       = "https://support.google.com/mail"
    "Google Apps Script"          = "https://developers.google.com/apps-script/overview"
    "Google Calendar"             = "https://support.google.com/calendar"
    "Google Chat"                 = "https://support.google.com/chat"
    "Google Docs"                 = "https://support.google.com/docs"
    "Google Drive"                = "https://support.google.com/drive"
    "Google Forms"                = "https://support.google.com/docs/topic/9055404"
    "Google Groups"               = "https://support.google.com/groups"
    "Google Keep"                 = "https://support.google.com/keep"
    "Google Meet"                 = "https://support.google.com/meet"
    "Google Sheets"               = "https://support.google.com/docs/topic/9054603"
    "Google Sites"                = "https://support.google.com/sites"
    "Google Slides"               = "https://support.google.com/docs/topic/9052835"
    "Google SSO"                  = "https://support.google.com/a/answer/60224"
    "Google Tasks"                = "https://support.google.com/tasks"
    "Google Workspace Admin"      = "https://support.google.com/a"
    "Looker Studio"               = "https://support.google.com/looker-studio"

    # ------- Microsoft 365 (Office apps + collaboration) -------
    "Microsoft Bookings"          = "https://support.microsoft.com/en-us/office/microsoft-bookings"
    "Microsoft Copilot Chat"      = "https://copilot.microsoft.com/"
    "Microsoft Excel"             = "https://support.microsoft.com/en-us/excel"
    "Microsoft Forms"             = "https://support.microsoft.com/en-us/forms"
    "Microsoft Lists"             = "https://support.microsoft.com/en-us/lists"
    "Microsoft Loop"              = "https://support.microsoft.com/en-us/loop"
    "Microsoft OneDrive"          = "https://support.microsoft.com/en-us/onedrive"
    "Microsoft OneNote"           = "https://support.microsoft.com/en-us/onenote"
    "Microsoft Outlook"           = "https://support.microsoft.com/en-us/outlook"
    "Microsoft Planner"           = "https://support.microsoft.com/en-us/planner"
    "Microsoft PowerPoint"        = "https://support.microsoft.com/en-us/powerpoint"
    "Microsoft SharePoint"        = "https://support.microsoft.com/en-us/sharepoint"
    "Microsoft Stream"            = "https://support.microsoft.com/en-us/stream"
    "Microsoft Teams"             = "https://support.microsoft.com/en-us/teams"
    "Microsoft To Do"             = "https://support.microsoft.com/en-us/todo"
    "Microsoft Whiteboard"        = "https://support.microsoft.com/en-us/whiteboard"
    "Microsoft Word"              = "https://support.microsoft.com/en-us/word"
    "Outlook Calendar"            = "https://support.microsoft.com/en-us/office/calendar-help-cca22ca8-91b2-4a37-9b4c-5757c3bfdd24"
    "Microsoft 365 Groups"        = "https://learn.microsoft.com/en-us/microsoft-365/admin/create-groups/office-365-groups"
    "M365 Admin Center"           = "https://learn.microsoft.com/en-us/microsoft-365/admin/"

    # ------- Microsoft Power Platform -------
    "Power Apps"                  = "https://learn.microsoft.com/en-us/power-apps/"
    "Power Automate"              = "https://learn.microsoft.com/en-us/power-automate/"
    "Power BI"                    = "https://learn.microsoft.com/en-us/power-bi/"
    "AppSheet"                    = "https://www.appsheet.com/Home/StartLearning"

    # ------- Microsoft Identity / Azure -------
    "Entra ID"                    = "https://learn.microsoft.com/en-us/entra/identity/"
    "Azure DevOps Boards"         = "https://learn.microsoft.com/en-us/azure/devops/boards/"

    # ------- Project / Task management -------
    "Asana"                       = "https://asana.com/guide"
    "Jira"                        = "https://www.atlassian.com/software/jira/guides"
    "Trello"                      = "https://support.atlassian.com/trello/"
    "Monday.com"                  = "https://support.monday.com/hc/en-us"
    "Smartsheet"                  = "https://help.smartsheet.com/"
    "Notion"                      = "https://www.notion.so/help"

    # ------- Communication -------
    "Slack"                       = "https://slack.com/help"
    "Discord"                     = "https://support.discord.com/"
    "Mattermost"                  = "https://docs.mattermost.com/"
    "Zoom"                        = "https://support.zoom.us/"
    "WebEx"                       = "https://help.webex.com/en-us/"

    # ------- Dev / Source -------
    "GitHub"                      = "https://docs.github.com/en/get-started"

    # ------- Finance / HR -------
    "Costpoint Deltek"            = "https://www.deltek.com/en/customer-care/training"

    # ------- NASA-internal -------
    # Add URLs below as you find them. Leave commented to skip.
    # "NASA SharePoint"           = "<paste URL here>"
    # "NASA-GPT"                  = "<paste URL here>"
    # "NISM"                      = "<paste URL here>"
    # "NSITE MO Viewer"           = "<paste URL here>"
    # "IdMAX"                     = "<paste URL here>"
}

# ===========================================================================
# Run
# ===========================================================================
try {
    $list = Get-PnPList -Identity $ListName -ErrorAction Stop
} catch {
    Write-Host "ERROR: list '$ListName' not found." -ForegroundColor Red
    return
}

$items = Get-PnPListItem -List $ListName -Fields "ID","Title","TrainingResources"

$updated = 0
$skippedNotMapped = 0
$skippedAlreadyHas = 0
$failed = @()

foreach ($it in $items) {
    $title = ($it.FieldValues.Title -as [string])
    if ([string]::IsNullOrWhiteSpace($title)) { continue }

    if (-not $map.ContainsKey($title)) {
        $skippedNotMapped++
        Write-Host "  [skip-no-mapping] $title" -ForegroundColor DarkGray
        continue
    }

    $existing = $it.FieldValues.TrainingResources
    $existingUrl = if ($existing) { $existing.Url } else { $null }
    if (-not $OverwriteExisting -and -not [string]::IsNullOrWhiteSpace($existingUrl)) {
        $skippedAlreadyHas++
        Write-Host "  [skip-already-has] $title : $existingUrl" -ForegroundColor Yellow
        continue
    }

    $url = $map[$title]
    try {
        # SharePoint URL (Hyperlink) field expects an object with Url + Description.
        Set-PnPListItem -List $ListName -Identity $it.Id -Values @{
            TrainingResources = "$url, $title"
        } -ErrorAction Stop | Out-Null
        Write-Host "  [updated] $title -> $url" -ForegroundColor Green
        $updated++
    } catch {
        Write-Host "  [FAIL] $title : $($_.Exception.Message)" -ForegroundColor Red
        $failed += [PSCustomObject]@{ Title = $title; Error = $_.Exception.Message }
    }
}

Write-Host ""
Write-Host "==================== SUMMARY ====================" -ForegroundColor Cyan
Write-Host "Updated           : $updated" -ForegroundColor Green
Write-Host "Skipped (no map)  : $skippedNotMapped" -ForegroundColor DarkGray
Write-Host "Skipped (already) : $skippedAlreadyHas" -ForegroundColor Yellow
if ($failed.Count -gt 0) {
    Write-Host "Failed            : $($failed.Count)" -ForegroundColor Red
    $failed | ForEach-Object { Write-Host "  $($_.Title) : $($_.Error)" -ForegroundColor Red }
} else {
    Write-Host "Failed            : 0" -ForegroundColor Green
}
Write-Host "================================================="
Write-Host ""
Write-Host "Tools NOT mapped (you'll fill these manually or add to the script):" -ForegroundColor Cyan
$items | ForEach-Object {
    $t = $_.FieldValues.Title
    if ($t -and -not $map.ContainsKey($t)) { Write-Host "  - $t" -ForegroundColor Gray }
}
