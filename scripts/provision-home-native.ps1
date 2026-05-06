# Provision the KITCHEN Home page using the one-time-bootstrap pattern:
# native section templates wherever possible, sanitizer-safe HTML for the
# critical path-picker tiles (so they always render without manual setup),
# and a Markdown paste-list emitted for the Column 2/3 content the legacy
# PnP module cannot write reliably.
#
# After running this ONCE, the owner walks through the paste-list file
# (~4 blocks, ~5 minutes) in the SharePoint GUI to finish the page. All
# future edits happen in the SharePoint GUI; this script is intended to be
# discarded after the bootstrap.
#
# Assumes: Connect-PnPOnline -UseWebLogin already run against the KITCHEN site:
#   Connect-PnPOnline -Url https://nasa.sharepoint.com/teams/PCTransitionSandbox -UseWebLogin
#
# Module: legacy SharePointPnPPowerShellOnline (Windows PowerShell 5.1)
#
# DESIGN NOTES (do not regress):
#   * Hero web part is ABANDONED (legacy module renders it as [object Object]).
#     Substitute: navy colored-td hero band via a Text web part.
#   * Quick Links web part is ABANDONED (crashes the page on init).
#     Substitute: nested-table HTML buttons inside Text web parts.
#   * The S2 path-picker tiles (Onboarding | Update/Offboarding) are baked
#     into a SINGLE OneColumn section as an HTML 2-cell table. This is the
#     pattern proven to work; both tiles render without manual setup. We do
#     NOT use a TwoColumn section here because Column 2 of TwoColumn fails
#     in the legacy module ("Index was out of range") and we do not want
#     the most important navigation element on the site to be a manual step.
#   * Other multi-column sections DO use native TwoColumn / ThreeColumn,
#     and Column 2/3 content goes into the paste list.
#   * h1 gets rewritten and color stripped -- use h2/h3 only.
#   * Heading colors only survive when the heading is INSIDE a colored td.
#   * border-left on td is stripped -- use the sibling-td technique.
#   * style= on <a> outside the button pattern: only color survives.
#   * No class=, no <div>, no CSS variables.
#
# ASCII-only literals throughout. Arrows are HTML entity &rarr;.

# ===========================================================================
# Configuration
# ===========================================================================
$siteUrl  = "https://nasa.sharepoint.com/teams/PCTransitionSandbox"
$siteRoot = "/teams/PCTransitionSandbox"

$pageName  = "KITCHEN Home"
$pageTitle = "KITCHEN Home"

# Server-relative URLs for the path-picker tiles + secondary destinations.
$onboardingUrl       = "$siteRoot/SitePages/Onboarding.aspx"
$updateOffboardUrl   = "$siteRoot/SitePages/Update-Offboarding.aspx"
$stakeholdersListUrl = "$siteUrl/Lists/Stakeholders/AllItems.aspx"
$meetingsListUrl     = "$siteUrl/Lists/Meetings/AllItems.aspx"
$acronymsListUrl     = "$siteUrl/Lists/Acronyms/AllItems.aspx"
$decisionsListUrl    = "$siteUrl/Lists/Decisions%20Log/AllItems.aspx"
$toolsListUrl        = "$siteUrl/Lists/Tools/AllItems.aspx"
$equivalencyMapUrl   = "$siteUrl/Lists/Equivalency%20Map%20Real/AllItems.aspx"
$mantleActionsUrl    = "$siteUrl/SitePages/MANTLE-Actions.aspx"

# Palette (Barrios)
# Navy:    #182039
# Gold:    #E8B86A
# Blue:    #4961A3
# Ink:     #333333
# Paper:   #F5F7FA
# White:   #FFFFFF

$failures      = @()
$substitutions = @()
# Blocks the script CANNOT add (Column 2/3 of multi-column sections fail in
# the legacy module). Captured here, written to a Markdown paste-list at the
# end of the run for one-time manual setup.
$manualBlocks  = @()

# ===========================================================================
# 1. Delete-and-recreate the page
# ===========================================================================
Write-Host ""
Write-Host "=== Page: $pageName (one-time bootstrap) ===" -ForegroundColor Cyan

$pageExists = $false
try {
    $existing = Get-PnPClientSidePage -Identity $pageName -ErrorAction Stop
    if ($null -ne $existing) {
        $pageExists = $true
        Write-Host "Page '$pageName' already exists. Wiping for clean recreate." -ForegroundColor Yellow
    }
} catch {
    $pageExists = $false
}

$page = $null
try {
    if ($pageExists) {
        try {
            Remove-PnPClientSidePage -Identity $pageName -Force -ErrorAction Stop | Out-Null
            Write-Host "Deleted existing page (clean recreate)." -ForegroundColor Yellow
        } catch {
            Write-Host "  Could not delete existing page: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
    # Capture and thread the page OBJECT through every -Page parameter.
    $page = Add-PnPClientSidePage -Name $pageName -LayoutType Article
    try {
        Set-PnPClientSidePage -Identity $pageName -Title $pageTitle -ErrorAction Stop | Out-Null
    } catch {
        Write-Host "  (Could not set page title: $($_.Exception.Message))" -ForegroundColor DarkGray
    }
    try {
        $page = Get-PnPClientSidePage -Identity $pageName -ErrorAction Stop
    } catch {
        Write-Host "  (Could not re-fetch page object after create: $($_.Exception.Message))" -ForegroundColor DarkGray
    }
    Write-Host "Page created (fresh)." -ForegroundColor Green
} catch {
    Write-Host "FAILED to create/open page: $($_.Exception.Message)" -ForegroundColor Red
    $failures += "Create/open page: $($_.Exception.Message)"
    return
}

# ===========================================================================
# 2. Helpers
# ===========================================================================
function Refresh-Page {
    try {
        return Get-PnPClientSidePage -Identity $pageName -ErrorAction Stop
    } catch {
        return $null
    }
}

function Add-Section {
    param(
        [Parameter(Mandatory=$true)]$Page,
        [int]$Index,
        [string]$Template,
        [string]$Label
    )
    try {
        Add-PnPClientSidePageSection -Page $Page -SectionTemplate $Template -ErrorAction Stop | Out-Null
        Write-Host "Added section ${Index} ($Template) -- $Label" -ForegroundColor DarkGray
        $refreshed = Refresh-Page
        if ($null -eq $refreshed) { $refreshed = $Page }
        return @{ Ok = $true; Page = $refreshed }
    } catch {
        Write-Host "FAILED to add section ${Index} ($Template, $Label): $($_.Exception.Message)" -ForegroundColor Red
        $script:failures += "Section ${Index} ($Template, $Label): $($_.Exception.Message)"
        return @{ Ok = $false; Page = $Page }
    }
}

function Add-TextPart {
    param(
        [Parameter(Mandatory=$true)]$Page,
        [int]$Section,
        [int]$Column,
        [string]$Html,
        [string]$Label
    )
    try {
        Add-PnPClientSideText -Page $Page -Section $Section -Column $Column `
            -Text $Html -ErrorAction Stop | Out-Null
    } catch {
        Write-Host "FAILED to add Text web part ($Label) at S${Section}C${Column}: $($_.Exception.Message)" -ForegroundColor Red
        $script:failures += "Text ($Label) S${Section}C${Column}: $($_.Exception.Message)"
    }
}

function Add-ManualBlock {
    param(
        [int]$SectionIndex,
        [int]$Column,
        [string]$Label,
        [string]$Html = "",
        [string]$Type = "Text",
        [string]$Instruction = ""
    )
    $script:manualBlocks += [PSCustomObject]@{
        SectionIndex = $SectionIndex
        Column       = $Column
        Label        = $Label
        Html         = $Html
        Type         = $Type
        Instruction  = $Instruction
    }
    Write-Host ("    [manual] S{0}/C{1} {2} ({3} web part) -> queued for paste-list" -f $SectionIndex, $Column, $Label, $Type) -ForegroundColor DarkCyan
}

# ===========================================================================
# 3. Build sections
#
# Layout plan:
#   S1 OneColumn   - Hero band (navy w/ gold eyebrow + welcome heading)
#   S2 OneColumn   - Path picker: 2 big tiles side-by-side via HTML table
#                    (kept as ONE Text web part since both tiles MUST render
#                    without manual setup; TwoColumn would put one tile in
#                    the paste list which is unacceptable for path nav)
#   S3 TwoColumn   - L: What KITCHEN is (text)  | R: Stats panel (paste list)
#   S4 ThreeColumn - L: Working styles card    | C: Cookbooks (paste list)
#                                               | R: Equivalencies (paste list)
#   S5 TwoColumn   - L: Quick links list       | R: Recent activity (paste list)
#   S6 OneColumn   - Footer (gold internal-only band)
# ===========================================================================

# --- S1: HERO BAND ----------------------------------------------------------
$res = Add-Section -Page $page -Index 1 -Template OneColumn -Label "Hero band"
$page = $res.Page
$heroHtml = @"
<table style='width:100%;border-collapse:separate;border-spacing:0;'>
<tr><td style='background:#182039;padding:48px 32px;border-radius:8px;text-align:center;'>
<p style='color:#E8B86A;margin:0 0 12px 0;font-size:11px;font-weight:bold;letter-spacing:2.5px;'>MANUAL &middot; ACRONYMS &middot; NOTES &middot; TRANSITION &middot; LOGISTICS &middot; ENGAGEMENT</p>
<h2 style='color:#FFFFFF;margin:0 0 12px 0;font-size:34px;font-weight:300;'>Welcome to KITCHEN</h2>
<p style='color:#FFFFFF;margin:0;font-size:16px;'>Knowledge collected by every coordinator who has done this role before you. Capture working styles, document meetings, generate cookbooks.</p>
</td></tr></table>
"@
if ($res.Ok) { Add-TextPart -Page $page -Section 1 -Column 1 -Html $heroHtml -Label "S1 hero band" }

# --- S2: PATH PICKER (2 big tiles in HTML table) ----------------------------
# Both tiles must render. HTML table with two td cells.
$res = Add-Section -Page $page -Index 2 -Template OneColumn -Label "Path picker tiles"
$page = $res.Page
$pathPickerHtml = @"
<table style='width:100%;border-collapse:separate;border-spacing:12px 0;margin:8px 0;'>
<tr>
<td style='width:50%;background:#4961A3;padding:32px;border-radius:8px;vertical-align:top;'>
<p style='color:#E8B86A;margin:0 0 8px 0;font-size:11px;font-weight:bold;letter-spacing:1.5px;'>FOR NEW PCs</p>
<h3 style='color:#FFFFFF;margin:0 0 12px 0;font-size:24px;'>I'm joining a new team</h3>
<p style='color:#FFFFFF;margin:0 0 18px 0;font-size:14px;'>Walk through who you are, what tools you use, how you communicate, and what your day-to-day looks like.</p>
<table style='border-collapse:separate;border-spacing:0;'>
<tr><td style='background:#E8B86A;padding:12px 22px;border-radius:6px;'>
<a href='$onboardingUrl' style='color:#182039;text-decoration:none;font-weight:bold;font-size:14px;'>Start Onboarding &rarr;</a>
</td></tr></table>
</td>
<td style='width:50%;background:#182039;padding:32px;border-radius:8px;vertical-align:top;'>
<p style='color:#E8B86A;margin:0 0 8px 0;font-size:11px;font-weight:bold;letter-spacing:1.5px;'>FOR EXISTING PCs</p>
<h3 style='color:#E8B86A;margin:0 0 12px 0;font-size:24px;'>I'm wrapping up my role</h3>
<p style='color:#FFFFFF;margin:0 0 18px 0;font-size:14px;'>Capture what you know so your replacement isn't lost. Generate a cookbook when you're ready.</p>
<table style='border-collapse:separate;border-spacing:0;'>
<tr><td style='background:#E8B86A;padding:12px 22px;border-radius:6px;'>
<a href='$updateOffboardUrl' style='color:#182039;text-decoration:none;font-weight:bold;font-size:14px;'>Start Update/Offboarding &rarr;</a>
</td></tr></table>
</td>
</tr></table>
"@
if ($res.Ok) { Add-TextPart -Page $page -Section 2 -Column 1 -Html $pathPickerHtml -Label "S2 path picker tiles" }

# --- S3: WHAT KITCHEN IS + STATS (TwoColumn) --------------------------------
$res = Add-Section -Page $page -Index 3 -Template TwoColumn -Label "What KITCHEN is + stats"
$page = $res.Page
$whatHtml = @"
<p style='color:#4961A3;margin:0 0 4px 0;font-size:11px;font-weight:bold;letter-spacing:1.5px;'>WHAT KITCHEN IS</p>
<h3 style='color:#182039;margin:0 0 12px 0;font-size:22px;'>A platform for coordinator-to-coordinator knowledge transfer</h3>
<p style='color:#333333;margin:0 0 12px 0;'>PCs leave, contracts shift, and institutional knowledge vanishes. KITCHEN captures the relationships, meetings, decisions, and unwritten rules that make a working team actually work &mdash; and packages it for the next person.</p>
<p style='color:#333333;margin:0;'>Built by coordinators, for coordinators. Maintained by every PC who uses it.</p>
"@
if ($res.Ok) { Add-TextPart -Page $page -Section 3 -Column 1 -Html $whatHtml -Label "S3 what KITCHEN is" }

$statsHtml = @"
<table style='width:100%;border-collapse:separate;border-spacing:0;'>
<tr><td style='background:#F5F7FA;padding:22px;border-radius:8px;'>
<h3 style='color:#182039;margin:0 0 14px 0;font-size:13px;text-transform:uppercase;letter-spacing:1.5px;'>ACROSS ALL CONTRACTS</h3>
<table style='width:100%;border-collapse:separate;border-spacing:0;'>
<tr><td style='padding:8px 0;border-bottom:1px solid #E4E4E4;color:#615E5E;font-size:14px;'>Stakeholders captured</td><td style='padding:8px 0;border-bottom:1px solid #E4E4E4;text-align:right;color:#4961A3;font-weight:bold;font-size:20px;'>47</td></tr>
<tr><td style='padding:8px 0;border-bottom:1px solid #E4E4E4;color:#615E5E;font-size:14px;'>Working styles documented</td><td style='padding:8px 0;border-bottom:1px solid #E4E4E4;text-align:right;color:#4961A3;font-weight:bold;font-size:20px;'>23</td></tr>
<tr><td style='padding:8px 0;border-bottom:1px solid #E4E4E4;color:#615E5E;font-size:14px;'>Meetings catalogued</td><td style='padding:8px 0;border-bottom:1px solid #E4E4E4;text-align:right;color:#4961A3;font-weight:bold;font-size:20px;'>19</td></tr>
<tr><td style='padding:8px 0;border-bottom:1px solid #E4E4E4;color:#615E5E;font-size:14px;'>Decisions logged</td><td style='padding:8px 0;border-bottom:1px solid #E4E4E4;text-align:right;color:#4961A3;font-weight:bold;font-size:20px;'>31</td></tr>
<tr><td style='padding:8px 0;color:#615E5E;font-size:14px;'>Cookbooks generated</td><td style='padding:8px 0;text-align:right;color:#E8B86A;font-weight:bold;font-size:20px;'>8</td></tr>
</table>
<p style='color:#888;margin:12px 0 0 0;font-size:11px;font-style:italic;'>Numbers shown are placeholders. Replace with live values via list rollups when ready.</p>
</td></tr></table>
"@
if ($res.Ok) { Add-ManualBlock -SectionIndex 3 -Column 2 -Label "Stats panel" -Html $statsHtml -Type "Text" -Instruction "Add a Text web part to the right column. Edit source. Paste HTML." }

# --- S4: THREE FEATURE CARDS (ThreeColumn) ---------------------------------
$res = Add-Section -Page $page -Index 4 -Template ThreeColumn -Label "Three feature cards"
$page = $res.Page
$s4Ok = $res.Ok

$workingStyleCardHtml = @"
<table style='width:100%;border-collapse:separate;border-spacing:0;margin:0;'>
<tr>
<td style='background:#182039;width:4px;border-radius:4px 0 0 4px;padding:0;'>&nbsp;</td>
<td style='background:#FFFFFF;padding:20px;border-radius:0 6px 6px 0;'>
<h3 style='color:#182039;margin:0 0 8px 0;font-size:16px;'>Capture working styles</h3>
<p style='color:#615E5E;margin:0 0 12px 0;font-size:13px;'>Per-stakeholder discovery: 21 questions covering communication, decisions, deep work, feedback, conflict &mdash; captured in your first 1:1s.</p>
<p style='margin:0;font-size:13px;'><a href='$stakeholdersListUrl' style='color:#4961A3;text-decoration:none;font-weight:bold;'>Open Stakeholders &rarr;</a></p>
</td></tr></table>
"@
if ($s4Ok) { Add-TextPart -Page $page -Section 4 -Column 1 -Html $workingStyleCardHtml -Label "S4 working styles card" }

$cookbookCardHtml = @"
<table style='width:100%;border-collapse:separate;border-spacing:0;margin:0;'>
<tr>
<td style='background:#E8B86A;width:4px;border-radius:4px 0 0 4px;padding:0;'>&nbsp;</td>
<td style='background:#FFFFFF;padding:20px;border-radius:0 6px 6px 0;'>
<h3 style='color:#182039;margin:0 0 8px 0;font-size:16px;'>Generate cookbooks</h3>
<p style='color:#615E5E;margin:0 0 12px 0;font-size:13px;'>One-click generation pulls everything you have documented into a Word document handoff. Your replacement reads it on day one.</p>
<p style='margin:0;font-size:13px;'><a href='$mantleActionsUrl' style='color:#4961A3;text-decoration:none;font-weight:bold;'>KITCHEN Actions &rarr;</a></p>
</td></tr></table>
"@
if ($s4Ok) { Add-ManualBlock -SectionIndex 4 -Column 2 -Label "Generate cookbooks card" -Html $cookbookCardHtml -Type "Text" -Instruction "Add a Text web part to the middle column. Edit source. Paste HTML." }

$equivalencyCardHtml = @"
<table style='width:100%;border-collapse:separate;border-spacing:0;margin:0;'>
<tr>
<td style='background:#4961A3;width:4px;border-radius:4px 0 0 4px;padding:0;'>&nbsp;</td>
<td style='background:#FFFFFF;padding:20px;border-radius:0 6px 6px 0;'>
<h3 style='color:#182039;margin:0 0 8px 0;font-size:16px;'>Browse equivalencies</h3>
<p style='color:#615E5E;margin:0 0 12px 0;font-size:13px;'>Cross-tool translations: Slack to Teams, Drive to OneDrive, Asana to Planner. Find the local equivalent of what you already know.</p>
<p style='margin:0;font-size:13px;'><a href='$equivalencyMapUrl' style='color:#4961A3;text-decoration:none;font-weight:bold;'>Open Equivalency Map &rarr;</a></p>
</td></tr></table>
"@
if ($s4Ok) { Add-ManualBlock -SectionIndex 4 -Column 3 -Label "Browse equivalencies card" -Html $equivalencyCardHtml -Type "Text" -Instruction "Add a Text web part to the right column. Edit source. Paste HTML." }

# --- S5: QUICK LINKS + RECENT ACTIVITY (TwoColumn) -------------------------
$res = Add-Section -Page $page -Index 5 -Template TwoColumn -Label "Quick links + Recent activity"
$page = $res.Page
$quickLinksHtml = @"
<h3 style='color:#182039;margin:0 0 12px 0;font-size:18px;'>Quick links</h3>
<table style='width:100%;border-collapse:separate;border-spacing:0;'>
<tr><td style='padding:10px 0;border-bottom:1px solid #F0F0F0;'><a href='$stakeholdersListUrl' style='color:#4961A3;text-decoration:none;font-size:14px;'>Stakeholders directory</a></td></tr>
<tr><td style='padding:10px 0;border-bottom:1px solid #F0F0F0;'><a href='$meetingsListUrl' style='color:#4961A3;text-decoration:none;font-size:14px;'>Meetings catalogue</a></td></tr>
<tr><td style='padding:10px 0;border-bottom:1px solid #F0F0F0;'><a href='$acronymsListUrl' style='color:#4961A3;text-decoration:none;font-size:14px;'>Acronym glossary</a></td></tr>
<tr><td style='padding:10px 0;border-bottom:1px solid #F0F0F0;'><a href='$decisionsListUrl' style='color:#4961A3;text-decoration:none;font-size:14px;'>Decisions log</a></td></tr>
<tr><td style='padding:10px 0;border-bottom:1px solid #F0F0F0;'><a href='$toolsListUrl' style='color:#4961A3;text-decoration:none;font-size:14px;'>Tools inventory</a></td></tr>
<tr><td style='padding:10px 0;'><a href='$mantleActionsUrl' style='color:#4961A3;text-decoration:none;font-size:14px;'>KITCHEN Actions (admin)</a></td></tr>
</table>
"@
if ($res.Ok) { Add-TextPart -Page $page -Section 5 -Column 1 -Html $quickLinksHtml -Label "S5 quick links" }

$recentActivityHtml = @"
<h3 style='color:#182039;margin:0 0 12px 0;font-size:18px;'>Recent activity</h3>
<p style='color:#615E5E;margin:0 0 12px 0;font-size:13px;font-style:italic;'>Static placeholder until a live activity rollup is wired up. Replace with a List, Highlighted Content, or Embed web part once available.</p>
<table style='width:100%;border-collapse:separate;border-spacing:0;'>
<tr><td style='padding:0 0 10px 0;'>
<table style='width:100%;border-collapse:separate;border-spacing:0;'>
<tr>
<td style='background:#4961A3;width:3px;padding:0;border-radius:3px 0 0 3px;'>&nbsp;</td>
<td style='background:#F5F7FA;padding:10px 14px;border-radius:0 4px 4px 0;'>
<p style='color:#182039;margin:0 0 2px 0;font-size:13px;font-weight:bold;'>Cherrelle T. updated J. Morales' working style</p>
<p style='color:#888;margin:0;font-size:11px;'>2 hours ago &middot; Stakeholders</p>
</td></tr></table>
</td></tr>
<tr><td style='padding:0 0 10px 0;'>
<table style='width:100%;border-collapse:separate;border-spacing:0;'>
<tr>
<td style='background:#E8B86A;width:3px;padding:0;border-radius:3px 0 0 3px;'>&nbsp;</td>
<td style='background:#F5F7FA;padding:10px 14px;border-radius:0 4px 4px 0;'>
<p style='color:#182039;margin:0 0 2px 0;font-size:13px;font-weight:bold;'>Devon R. generated cookbook for IMPACT</p>
<p style='color:#888;margin:0;font-size:11px;'>yesterday &middot; KITCHEN Actions</p>
</td></tr></table>
</td></tr>
<tr><td style='padding:0 0 10px 0;'>
<table style='width:100%;border-collapse:separate;border-spacing:0;'>
<tr>
<td style='background:#4961A3;width:3px;padding:0;border-radius:3px 0 0 3px;'>&nbsp;</td>
<td style='background:#F5F7FA;padding:10px 14px;border-radius:0 4px 4px 0;'>
<p style='color:#182039;margin:0 0 2px 0;font-size:13px;font-weight:bold;'>Sara K. added 4 acronyms</p>
<p style='color:#888;margin:0;font-size:11px;'>3 days ago &middot; Acronyms</p>
</td></tr></table>
</td></tr>
<tr><td>
<table style='width:100%;border-collapse:separate;border-spacing:0;'>
<tr>
<td style='background:#182039;width:3px;padding:0;border-radius:3px 0 0 3px;'>&nbsp;</td>
<td style='background:#F5F7FA;padding:10px 14px;border-radius:0 4px 4px 0;'>
<p style='color:#182039;margin:0 0 2px 0;font-size:13px;font-weight:bold;'>New decision logged: Q3 cadence change</p>
<p style='color:#888;margin:0;font-size:11px;'>last week &middot; Decisions</p>
</td></tr></table>
</td></tr>
</table>
"@
if ($res.Ok) { Add-ManualBlock -SectionIndex 5 -Column 2 -Label "Recent activity" -Html $recentActivityHtml -Type "Text" -Instruction "Add a Text web part to the right column. Edit source. Paste HTML. (Or replace with a Highlighted Content / News web part when a real activity rollup is available.)" }

# --- S6: FOOTER (gold internal-only band) ----------------------------------
$res = Add-Section -Page $page -Index 6 -Template OneColumn -Label "Footer"
$page = $res.Page
$footerHtml = @"
<table style='width:100%;border-collapse:separate;border-spacing:0;margin:8px 0 0 0;'>
<tr><td style='background:#E8B86A;padding:14px 20px;border-radius:6px;'>
<p style='margin:0;color:#182039;font-size:13px;'><strong>Internal use only.</strong> KITCHEN contains contract-sensitive context. Do not share pages or list exports outside Barrios or your contract team.</p>
</td></tr></table>
"@
if ($res.Ok) { Add-TextPart -Page $page -Section 6 -Column 1 -Html $footerHtml -Label "S6 footer" }

# ===========================================================================
# 4. Publish
# ===========================================================================
Write-Host ""
Write-Host "=== Publishing page ===" -ForegroundColor Cyan
try {
    Set-PnPClientSidePage -Identity $pageName -Title $pageTitle -Publish | Out-Null
    Write-Host "Page published." -ForegroundColor Green
} catch {
    Write-Host "FAILED to publish: $($_.Exception.Message)" -ForegroundColor Red
    $failures += "Publish: $($_.Exception.Message)"
}

try {
    Set-PnPClientSidePage -Identity $pageName -HeaderType None -ErrorAction Stop | Out-Null
    Write-Host "Hid default SharePoint title banner." -ForegroundColor DarkGray
} catch {
    Write-Host "  (Could not hide title banner: $($_.Exception.Message))" -ForegroundColor DarkGray
}

# ===========================================================================
# 5. Resolve actual page URL
# ===========================================================================
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
    Write-Host "Could not query Site Pages: $($_.Exception.Message)" -ForegroundColor Yellow
}
if (-not $actualUrlRelative) {
    $actualUrlRelative = "$siteRoot/SitePages/" + ($pageName.Replace(' ','-')) + ".aspx"
    Write-Host "Falling back to assumed URL: $actualUrlRelative" -ForegroundColor Yellow
} else {
    Write-Host "Resolved page URL: $actualUrlRelative" -ForegroundColor Cyan
}

# ===========================================================================
# 6. Set as site home page
# ===========================================================================
Write-Host ""
Write-Host "=== Set as site home page ===" -ForegroundColor Cyan
try {
    $homePathForCmd = $actualUrlRelative
    if ($homePathForCmd.StartsWith($siteRoot + "/")) {
        $homePathForCmd = $homePathForCmd.Substring(($siteRoot + "/").Length)
    }
    Set-PnPHomePage -RootFolderRelativeUrl $homePathForCmd -ErrorAction Stop | Out-Null
    Write-Host "Set '$pageName' as site home page." -ForegroundColor Green
} catch {
    Write-Host "FAILED to set as home page: $($_.Exception.Message)" -ForegroundColor Yellow
    $failures += "Set home page: $($_.Exception.Message)"
}

# ===========================================================================
# 7. Quick Launch nav (idempotent)
# ===========================================================================
Write-Host ""
Write-Host "=== Quick Launch nav ===" -ForegroundColor Cyan
try {
    $existingNodes = Get-PnPNavigationNode -Location QuickLaunch -ErrorAction Stop
    $already = $existingNodes | Where-Object { $_.Title -eq $pageName }
    if ($already) {
        Write-Host "Quick Launch already has '$pageName'. Skipping." -ForegroundColor Yellow
    } else {
        Add-PnPNavigationNode -Location QuickLaunch -Title $pageName -Url $actualUrlRelative -ErrorAction Stop | Out-Null
        Write-Host "Added '$pageName' to Quick Launch." -ForegroundColor Green
    }
} catch {
    Write-Host "FAILED to update Quick Launch: $($_.Exception.Message)" -ForegroundColor Red
    $failures += "Quick Launch: $($_.Exception.Message)"
}

# ===========================================================================
# 8. Write the manual-paste Markdown file
# ===========================================================================
$mdRelativeDir = Join-Path (Split-Path -Parent $PSScriptRoot) "design"
if (-not (Test-Path $mdRelativeDir)) {
    try { New-Item -ItemType Directory -Path $mdRelativeDir -Force | Out-Null } catch { }
}
$mdPath = Join-Path $mdRelativeDir "manual-paste-home.md"

$encodedRelative = $actualUrlRelative -replace ' ', '%20'
$publishedUrl    = "https://nasa.sharepoint.com$encodedRelative"

$md = New-Object System.Text.StringBuilder
[void]$md.AppendLine("# Manual paste list -- KITCHEN Home")
[void]$md.AppendLine("")
[void]$md.AppendLine("Generated by ``provision-home-native.ps1`` on $(Get-Date -Format 'yyyy-MM-dd HH:mm').")
[void]$md.AppendLine("")
[void]$md.AppendLine("The provisioning script created the page structure (6 native sections).")
[void]$md.AppendLine("This file lists the **$($manualBlocks.Count) content blocks** the script could not write because")
[void]$md.AppendLine("the legacy PnP PowerShell module cannot reliably populate Column 2 / Column 3 of multi-column sections.")
[void]$md.AppendLine("Paste them once via the SharePoint GUI and you are done.")
[void]$md.AppendLine("")
[void]$md.AppendLine("**Page URL:** [$publishedUrl]($publishedUrl)")
[void]$md.AppendLine("")
[void]$md.AppendLine("## Quick instructions")
[void]$md.AppendLine("")
[void]$md.AppendLine("1. Open the page URL above")
[void]$md.AppendLine("2. Click **Edit** (top right)")
[void]$md.AppendLine("3. For each block below: find the named section, hover the empty column, click **+** to add a Text web part")
[void]$md.AppendLine("4. Click the new Text web part > pencil icon > '...' menu > **Edit source** -- paste the HTML, save")
[void]$md.AppendLine("5. When all $($manualBlocks.Count) blocks are placed, click **Republish** (top right)")
[void]$md.AppendLine("")
[void]$md.AppendLine("Estimated time: 5-7 minutes.")
[void]$md.AppendLine("")
[void]$md.AppendLine("---")
[void]$md.AppendLine("")
foreach ($block in $manualBlocks) {
    [void]$md.AppendLine("## Section $($block.SectionIndex), Column $($block.Column) -- $($block.Label)")
    [void]$md.AppendLine("")
    [void]$md.AppendLine("**Web part type:** $($block.Type)")
    [void]$md.AppendLine("")
    if ($block.Instruction) {
        [void]$md.AppendLine($block.Instruction)
        [void]$md.AppendLine("")
    }
    if ($block.Html) {
        [void]$md.AppendLine('```html')
        [void]$md.AppendLine($block.Html.Trim())
        [void]$md.AppendLine('```')
        [void]$md.AppendLine("")
    }
    [void]$md.AppendLine("---")
    [void]$md.AppendLine("")
}
try {
    Set-Content -Path $mdPath -Value $md.ToString() -Encoding UTF8 -ErrorAction Stop
    Write-Host ""
    Write-Host "Manual paste list written to: $mdPath" -ForegroundColor Green
} catch {
    Write-Host "FAILED to write manual paste list: $($_.Exception.Message)" -ForegroundColor Red
    $failures += "Write manual paste file: $($_.Exception.Message)"
}

# ===========================================================================
# 9. Summary
# ===========================================================================
Write-Host ""
Write-Host "==================== SUMMARY ====================" -ForegroundColor Cyan
Write-Host "Page         : $pageName" -ForegroundColor Green
Write-Host "URL          : $publishedUrl" -ForegroundColor Cyan
Write-Host ""
Write-Host "Sections built (in order):" -ForegroundColor Cyan
Write-Host "  S1  OneColumn   - Hero band (navy w/ gold eyebrow)" -ForegroundColor Gray
Write-Host "  S2  OneColumn   - Path picker: 2 big tiles (HTML table, both render)" -ForegroundColor Gray
Write-Host "  S3  TwoColumn   - L: What KITCHEN is             | R: Stats panel (paste-list)" -ForegroundColor Gray
Write-Host "  S4  ThreeColumn - L: Working styles card        | C: Cookbooks (paste-list)" -ForegroundColor Gray
Write-Host "                                                   | R: Equivalencies (paste-list)" -ForegroundColor Gray
Write-Host "  S5  TwoColumn   - L: Quick links list           | R: Recent activity (paste-list)" -ForegroundColor Gray
Write-Host "  S6  OneColumn   - Footer (gold internal-only band)" -ForegroundColor Gray
Write-Host ""

if ($failures.Count -gt 0) {
    Write-Host "Failures ($($failures.Count)):" -ForegroundColor Red
    $failures | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
} else {
    Write-Host "Failures     : none" -ForegroundColor Green
}

Write-Host "================================================="
Write-Host ""
Write-Host "ONE-TIME OWNER ACTION:" -ForegroundColor Cyan
Write-Host "  Open the manual paste list and walk through each block once:" -ForegroundColor White
Write-Host "  $mdPath" -ForegroundColor Yellow
Write-Host ""
Write-Host "  $($manualBlocks.Count) blocks total. Estimated 5-7 minutes." -ForegroundColor Gray
Write-Host "  After paste, click Republish on the page (top right)." -ForegroundColor Gray
Write-Host ""
Write-Host "  This script is intended to be run ONCE. After the manual paste," -ForegroundColor DarkGray
Write-Host "  all further edits should be done in the SharePoint GUI." -ForegroundColor DarkGray
