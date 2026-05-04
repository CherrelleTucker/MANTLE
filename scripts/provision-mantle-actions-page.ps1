# Provision the "MANTLE Actions" SharePoint page.
# Assumes: Connect-PnPOnline -UseWebLogin already run against the MANTLE site.
# Target site: https://nasa.sharepoint.com/teams/PCTransitionSandbox
#
# Cmdlet versions:
#   Targets the legacy SharePointPnPPowerShellOnline module (PS 5.1).
#   Uses: Add-PnPClientSidePage, Add-PnPClientSidePageSection,
#         Add-PnPClientSideText, Set-PnPClientSidePage, Get-PnPClientSidePage.
#   In newer PnP.PowerShell modules these were renamed to
#   Add-PnPPage, Add-PnPPageSection, Add-PnPPageTextPart, Set-PnPPage, Get-PnPPage.
#   If a cmdlet is missing, see the alias note next to each call.

$pageName  = "MANTLE Actions"
$pageTitle = "MANTLE Actions"
# SharePoint converts spaces in the page name to a hyphen in the URL:
$pageUrlRelative = "/teams/PCTransitionSandbox/SitePages/MANTLE-Actions.aspx"

$siteUrl = "https://nasa.sharepoint.com/teams/PCTransitionSandbox"

$created  = $false
$updated  = $false
$navAdded = $false
$failures = @()

# ---------------------------------------------------------------------------
# 1. Create or update the page
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "=== Page: $pageName ===" -ForegroundColor Cyan

$pageExists = $false
try {
    # Get-PnPClientSidePage (legacy) / Get-PnPPage (newer)
    $existing = Get-PnPClientSidePage -Identity $pageName -ErrorAction Stop
    if ($null -ne $existing) {
        $pageExists = $true
        Write-Host "Page '$pageName' already exists. Will rewrite its content." -ForegroundColor Yellow
    }
} catch {
    $pageExists = $false
}

try {
    if (-not $pageExists) {
        # Add-PnPClientSidePage (legacy) / Add-PnPPage (newer)
        # Legacy module: -Title is NOT a parameter on Add-PnPClientSidePage.
        # Title is set separately via Set-PnPClientSidePage right after.
        Add-PnPClientSidePage -Name $pageName -LayoutType Article | Out-Null
        try {
            Set-PnPClientSidePage -Identity $pageName -Title $pageTitle -ErrorAction Stop | Out-Null
        } catch {
            Write-Host "  (Could not set page title - may need manual edit: $($_.Exception.Message))" -ForegroundColor DarkGray
        }
        Write-Host "Page created." -ForegroundColor Green
        $created = $true
    } else {
        # Best-effort wipe of existing controls so we can rewrite cleanly.
        # Some legacy module versions don't expose Remove-PnPClientSideComponent;
        # we tolerate failure and just append fresh sections.
        try {
            $page = Get-PnPClientSidePage -Identity $pageName
            foreach ($ctrl in @($page.Controls)) {
                try {
                    Remove-PnPClientSideComponent -Page $pageName -InstanceId $ctrl.InstanceId -Force -ErrorAction Stop | Out-Null
                } catch {
                    # ignore: cmdlet may not exist or control may be undeletable
                }
            }
        } catch {
            Write-Host "Could not clear existing controls; new sections will be appended below them." -ForegroundColor Yellow
        }
        $updated = $true
    }
} catch {
    Write-Host "FAILED to create/open page: $($_.Exception.Message)" -ForegroundColor Red
    $failures += "Create/open page: $($_.Exception.Message)"
    Write-Host "Aborting before section build." -ForegroundColor Red
    return
}

# ---------------------------------------------------------------------------
# 2. Helper: add a one-column section with one or more text controls
# ---------------------------------------------------------------------------
function Add-MantleSection {
    param(
        [int]$SectionIndex,
        [string[]]$TextBlocks
    )
    try {
        # Add-PnPClientSidePageSection (legacy) / Add-PnPPageSection (newer)
        Add-PnPClientSidePageSection -Page $pageName -SectionTemplate OneColumn | Out-Null
    } catch {
        Write-Host "FAILED to add section $SectionIndex : $($_.Exception.Message)" -ForegroundColor Red
        $script:failures += "Section $SectionIndex add: $($_.Exception.Message)"
        return
    }
    foreach ($block in $TextBlocks) {
        try {
            # Add-PnPClientSideText (legacy) / Add-PnPPageTextPart (newer)
            Add-PnPClientSideText -Page $pageName -Section $SectionIndex -Column 1 -Text $block | Out-Null
        } catch {
            Write-Host "FAILED to add text in section $SectionIndex : $($_.Exception.Message)" -ForegroundColor Red
            $script:failures += "Section $SectionIndex text: $($_.Exception.Message)"
        }
    }
}

# ---------------------------------------------------------------------------
# 3. Build sections
# ---------------------------------------------------------------------------
# Note on rendering: SharePoint client-side text parts accept HTML.
# Backtick / triple-backtick markdown does NOT render. We use <h2>, <p>,
# <pre style='...'> for code-style blocks, <ul>/<li> for bullets, and <a> for links.
# Emojis in -Text values render fine in modern SharePoint; if they ever
# look like boxes, swap them for the bracket fallbacks shown in comments.

# --- Section 1: Page intro ---
$introHtml = @"
<h2>MANTLE Actions</h2>
<p>This page is the entry point for administrative actions on the MANTLE platform. It is intended for the Project Coordinator (PC) acting as the platform owner / HR-grade admin, not for incoming or outgoing trainees.</p>
<p>Each action below is something that today requires running a PowerShell script from a terminal, because Power Automate is not yet enabled on this tenant. Each entry tells you what the action does, when to use it, and the exact command to copy and paste. Once Power Automate is enabled, each one becomes a one-click button on this page.</p>
<p><strong>Prerequisite for every action:</strong> a PowerShell session connected to this site via <code>Connect-PnPOnline -Url $siteUrl -UseWebLogin</code>.</p>
"@
Add-MantleSection -SectionIndex 1 -TextBlocks @($introHtml)

# --- Section 2: Generate My Cookbook ---
# Emoji fallback: [COOKBOOK]
$cookbookHtml = @"
<h2>&#128214; Generate My Cookbook</h2>
<p><strong>What it does:</strong> Assembles a Word-style cookbook document for the current PC by pulling Trainee Profile, assigned Programs, Meetings, Stakeholders, Decisions, Acronyms, Tools, and Equivalency Map data from the MANTLE Lists.</p>
<p><strong>When to use it:</strong> On demand when you want a polished snapshot of your role for handoff, for a supervisor review, or to share with a replacement.</p>
<p><strong>How to run today (PowerShell):</strong></p>
<pre style='font-family:Consolas,monospace;background:#f3f2f1;padding:8px;border:1px solid #d2d0ce;'>. "C:\Users\cjtucke3\Documents\Personal\Career\MANTLE\scripts\generate-cookbook.ps1"</pre>
<p><em>Future state:</em> When Power Automate is enabled, this becomes a one-click button on this page. See <code>design/pa-replacement-cookbook.md</code> for the flow design.</p>
"@
Add-MantleSection -SectionIndex 2 -TextBlocks @($cookbookHtml)

# --- Section 3: Process Welcome Responses ---
# Emoji fallback: [INBOX]
$welcomeHtml = @"
<h2>&#128229; Process Welcome Responses</h2>
<p><strong>What it does:</strong> Reads new submissions from the MANTLE Welcome Form, resolves the submitter to a row in the PCs list (auto-creating one if missing), creates or updates a Trainee Profile, and seeds the standard 30-60-90 starter tasks.</p>
<p><strong>When to use it:</strong> Run after any new PC submits the Welcome Form. Safe to re-run; it only acts on responses it has not yet processed.</p>
<p><strong>How to run today (PowerShell):</strong></p>
<pre style='font-family:Consolas,monospace;background:#f3f2f1;padding:8px;border:1px solid #d2d0ce;'>. "C:\Users\cjtucke3\Documents\Personal\Career\MANTLE\scripts\process-welcome-responses.ps1"</pre>
<p><em>Future state:</em> When Power Automate is enabled, this becomes a one-click button on this page. See <code>design/pa-replacement-welcome-intake.md</code> for the flow design.</p>
"@
Add-MantleSection -SectionIndex 3 -TextBlocks @($welcomeHtml)

# --- Section 4: Stale Stakeholder Check ---
# Emoji fallback: [CLOCK]
$staleHtml = @"
<h2>&#9200; Stale Stakeholder Check</h2>
<p><strong>What it does:</strong> Scans the Stakeholders list for entries whose <em>Last contact</em> date is older than the cadence implies (for example, a Weekly contact with no touch in 30+ days). Prints a report; optionally writes a flag column.</p>
<p><strong>When to use it:</strong> Weekly, as part of your own cadence review, or before a supervisor 1:1 to surface relationships that need attention.</p>
<p><strong>How to run today (PowerShell):</strong></p>
<pre style='font-family:Consolas,monospace;background:#f3f2f1;padding:8px;border:1px solid #d2d0ce;'>. "C:\Users\cjtucke3\Documents\Personal\Career\MANTLE\scripts\check-stale-stakeholders.ps1"</pre>
<p><em>Future state:</em> When Power Automate is enabled, this becomes a scheduled flow that emails you the report weekly. See <code>design/pa-replacement-stale-stakeholders.md</code> for the flow design.</p>
"@
Add-MantleSection -SectionIndex 4 -TextBlocks @($staleHtml)

# --- Section 5: Quick Links ---
# Emoji fallback: [ROCKET]
# Note: Quick Links web part exists in modern SharePoint, but the legacy
# Add-PnPClientSideWebPart cmdlet binding for it is brittle across PnP versions
# and requires a JSON properties blob to populate links. Bulleted HTML with
# anchors is portable, readable, and easy to maintain in source control.
$quickLinksHtml = @"
<h2>&#128640; Quick links</h2>
<ul>
  <li><a href="$siteUrl/Lists/MANTLE%20Welcome%20Form/NewForm.aspx">Welcome Form</a> &mdash; intake for incoming and outgoing PCs</li>
  <li><a href="$siteUrl/Lists/Trainee%20Profiles/AllItems.aspx">Trainee Profiles</a> &mdash; per-PC personalization (Tier 3)</li>
  <li><a href="$siteUrl/Lists/30609090%20Tasks/AllItems.aspx">30-60-90 Tasks</a> &mdash; onboarding and ongoing task plan</li>
  <li><a href="$siteUrl/Lists/Equivalency%20Map/AllItems.aspx">Equivalency Map</a> &mdash; cross-tool translations (Slack to Teams, etc.)</li>
  <li><a href="$siteUrl/Lists/Stakeholders/AllItems.aspx">Stakeholders</a> &mdash; influence-and-interest contact map</li>
  <li><a href="$siteUrl/Lists/Meetings/AllItems.aspx">Meetings</a> &mdash; recurring meeting catalog</li>
  <li><a href="$siteUrl/Lists/Acronyms/AllItems.aspx">Acronyms</a> &mdash; searchable glossary</li>
</ul>
<p><em>Note:</em> If a link 404s, the underlying List URL slug differs from the display name. Open the List from the site contents and copy the actual URL into this page.</p>
"@
Add-MantleSection -SectionIndex 5 -TextBlocks @($quickLinksHtml)

# --- Section 6: Admin notes ---
# Emoji fallback: [TOOLS]
$adminHtml = @"
<h2>&#128736; Admin notes</h2>
<p>These actions today require a PowerShell terminal connected to the MANTLE site. They are designed to become one-click buttons when Power Automate is enabled on this tenant. Until then, the scripts are the source of truth: each one is small, idempotent, and safe to re-run.</p>
<p>For the migration plans &mdash; what each script does, which Power Automate connectors will replace it, and the flow design &mdash; see the <code>design/</code> folder in the MANTLE repository (<code>C:\Users\cjtucke3\Documents\Personal\Career\MANTLE\design\</code>). Filenames follow the pattern <code>pa-replacement-&lt;name&gt;.md</code>.</p>
<p>If a script fails, the most common cause is a stale PnP connection. Re-run <code>Connect-PnPOnline -Url $siteUrl -UseWebLogin</code> and retry.</p>
"@
Add-MantleSection -SectionIndex 6 -TextBlocks @($adminHtml)

# ---------------------------------------------------------------------------
# 4. Publish the page
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "=== Publishing page ===" -ForegroundColor Cyan
try {
    # Set-PnPClientSidePage (legacy) / Set-PnPPage (newer) supports -Publish
    Set-PnPClientSidePage -Identity $pageName -Title $pageTitle -Publish | Out-Null
    Write-Host "Page published." -ForegroundColor Green
} catch {
    Write-Host "FAILED to publish: $($_.Exception.Message)" -ForegroundColor Red
    $failures += "Publish: $($_.Exception.Message)"
}

# ---------------------------------------------------------------------------
# 5. Discover the actual page URL (don't trust the assumed slug)
# ---------------------------------------------------------------------------
$actualUrlRelative = $null
try {
    $sitePagesItems = Get-PnPListItem -List "Site Pages" -ErrorAction Stop
    foreach ($spi in $sitePagesItems) {
        $title = $spi.FieldValues["Title"]
        $leaf  = $spi.FieldValues["FileLeafRef"]
        if ($title -eq $pageName -or $leaf -eq "$pageName.aspx" -or $leaf -eq ($pageName.Replace(' ','-') + ".aspx")) {
            $actualUrlRelative = $spi.FieldValues["FileRef"]
            break
        }
    }
} catch {
    Write-Host "Could not query Site Pages to discover real URL: $($_.Exception.Message)" -ForegroundColor Yellow
}
if ($actualUrlRelative) {
    Write-Host "Resolved page URL: $actualUrlRelative" -ForegroundColor Cyan
    $pageUrlRelative = $actualUrlRelative
} else {
    Write-Host "Could not resolve actual page URL; falling back to assumed slug ($pageUrlRelative)." -ForegroundColor Yellow
}

# ---------------------------------------------------------------------------
# 6. Add to Quick Launch (left navigation)
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "=== Quick Launch nav ===" -ForegroundColor Cyan
try {
    $existingNodes = Get-PnPNavigationNode -Location QuickLaunch -ErrorAction Stop
    $already = $existingNodes | Where-Object { $_.Title -eq $pageName }
    if ($already) {
        Write-Host "Quick Launch already has '$pageName'. Skipping." -ForegroundColor Yellow
    } else {
        Add-PnPNavigationNode -Location QuickLaunch -Title $pageName -Url $pageUrlRelative -ErrorAction Stop | Out-Null
        Write-Host "Added '$pageName' to Quick Launch." -ForegroundColor Green
        $navAdded = $true
    }
} catch {
    Write-Host "FAILED to update Quick Launch: $($_.Exception.Message)" -ForegroundColor Red
    $failures += "Quick Launch: $($_.Exception.Message)"
}

# ---------------------------------------------------------------------------
# 7. Summary
# ---------------------------------------------------------------------------
# Build the absolute URL by URL-encoding spaces in the relative path
$encodedRelative = $pageUrlRelative -replace ' ', '%20'
$publishedUrl = "https://nasa.sharepoint.com$encodedRelative"

Write-Host ""
Write-Host "==================== SUMMARY ====================" -ForegroundColor Cyan
if ($created)  { Write-Host "Page created : $pageName" -ForegroundColor Green }
if ($updated)  { Write-Host "Page updated : $pageName (rewrote sections)" -ForegroundColor Green }
if ($navAdded) { Write-Host "Quick Launch : added" -ForegroundColor Green } else { Write-Host "Quick Launch : already present or skipped" -ForegroundColor Yellow }
Write-Host "URL          : $publishedUrl" -ForegroundColor Cyan
if ($failures.Count -gt 0) {
    Write-Host "Failures ($($failures.Count)):" -ForegroundColor Red
    $failures | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
} else {
    Write-Host "Failures     : none" -ForegroundColor Green
}
Write-Host "================================================="
