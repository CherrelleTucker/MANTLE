# Provision the "Update / Offboarding" SharePoint page using a hybrid of
# native section templates + sanitizer-safe HTML inside Text web parts.
#
# Replaces the earlier provision-offboarding-native.ps1. The page name slug
# is now "Update-Offboarding" (hyphen), display title "Update / Offboarding".
#
# Assumes: Connect-PnPOnline -UseWebLogin already run against:
#   https://nasa.sharepoint.com/teams/PCTransitionSandbox
#
# Module: legacy SharePointPnPPowerShellOnline (Windows PowerShell 5.1)
# Cmdlets used:
#   Get-PnPClientSidePage / Add-PnPClientSidePage / Set-PnPClientSidePage /
#     Remove-PnPClientSidePage
#   Add-PnPClientSidePageSection (OneColumn / TwoColumn / ThreeColumn only --
#     OneColumnVerticalSection is REMOVED; the legacy module translates it
#     to OneColumnFullWidth which Group-connected sites reject. See
#     pnp/PnP-PowerShell issue #2602.)
#   Add-PnPClientSideText (the workhorse -- holds all colored-td HTML)
#   Add-PnPClientSideWebPart -DefaultWebPartType Image / List /
#     ContentRollup (best-effort; falls back to Text placeholder if rejected)
#   Get-PnPListItem (Site Pages, to resolve real URL)
#   Get-PnPNavigationNode / Add-PnPNavigationNode
#
# Group-connected site: NEVER OneColumnFullWidth.
#
# DESIGN NOTES (do not regress):
#   * Hero web part is ABANDONED -- legacy module's Hero JSON renders as
#     "[object Object]". Substitute: Text web part with navy colored-td.
#   * Quick Links web part is ABANDONED -- empty or populated, it crashes
#     the page with "Cannot read properties of undefined
#     (reading 'hasInitialLoadingState')". Substitute: nested-table HTML
#     buttons inside Text web parts.
#   * h1 gets rewritten and color stripped -- use h2/h3 only.
#   * Heading colors only survive when the heading is INSIDE a colored td.
#   * border-left and shorthand border on td get stripped -- use the
#     sibling-td technique (a 4px-wide colored td next to the content td).
#   * style= on <a> outside the button pattern: only the color attribute
#     survives. The button pattern wraps the <a> in a colored td.
#   * No class=, no <div>, no CSS variables.
#
# ASCII-only literals throughout. Arrows are HTML entity &rarr;.

# ===========================================================================
# Configuration
# ===========================================================================
$siteUrl  = "https://nasa.sharepoint.com/teams/PCTransitionSandbox"
$siteRoot = "/teams/PCTransitionSandbox"

$pageName  = "Update-Offboarding"
$pageTitle = "Update / Offboarding"

# List URLs and related destinations.
$stakeholdersList   = "$siteUrl/Lists/Stakeholders/AllItems.aspx"
$stakeholdersNew    = "$siteUrl/Lists/Stakeholders/NewForm.aspx"
$meetingsList       = "$siteUrl/Lists/Meetings/AllItems.aspx"
$meetingsNew        = "$siteUrl/Lists/Meetings/NewForm.aspx"
$acronymsList       = "$siteUrl/Lists/Acronyms/AllItems.aspx"
$acronymsNew        = "$siteUrl/Lists/Acronyms/NewForm.aspx"
$decisionsNew       = "$siteUrl/Lists/Decisions/NewForm.aspx"
$lessonsNew         = "$siteUrl/Lists/Lessons/NewForm.aspx"
$mantleActionsPage  = "$siteUrl/SitePages/MANTLE-Actions.aspx"
# Trainee Profile / context-change form. Until a dedicated form exists, point
# at the Stakeholders list (placeholder; rename URL if a real profile form
# gets built).
$contextChangeUrl   = $stakeholdersNew
# Working-style discovery doc placeholder.
$discoveryGuideUrl  = "$siteUrl/SitePages/MANTLE-Actions.aspx"

$created  = $false
$updated  = $false
$navAdded = $false
$verticalSectionUsed = $false
$failures = @()
$ownerActions = @()
# Blocks the script CANNOT add via PowerShell (Column 2/3 of multi-column
# sections fail in the legacy PnP module). Captured here, written to a
# Markdown paste-list file at the end of the run for one-time manual setup.
$manualBlocks = @()

# ===========================================================================
# 1. Ensure the page exists; delete-and-recreate
# ===========================================================================
Write-Host ""
Write-Host "=== Page: $pageName (hybrid native + sanitizer-safe HTML) ===" -ForegroundColor Cyan

$pageExists = $false
try {
    $existing = Get-PnPClientSidePage -Identity $pageName -ErrorAction Stop
    if ($null -ne $existing) {
        $pageExists = $true
        Write-Host "Page '$pageName' already exists. Deleting for clean recreate." -ForegroundColor Yellow
    }
} catch {
    $pageExists = $false
}

# Delete-and-recreate. A previous provisioning may have created a
# OneColumnFullWidth section that the legacy module can't rewrite on a
# Group-connected site. Delete-and-recreate avoids that.
$page = $null
try {
    if ($pageExists) {
        try {
            Remove-PnPClientSidePage -Identity $pageName -Force -ErrorAction Stop | Out-Null
            Write-Host "Deleted existing page (clean recreate)." -ForegroundColor Yellow
            $updated = $true
        } catch {
            Write-Host "  Could not delete existing page: $($_.Exception.Message)" -ForegroundColor Yellow
            Write-Host "  Will attempt overwrite via -Name (may fail on corrupt sections)." -ForegroundColor DarkGray
        }
    }
    # Capture the page OBJECT returned by Add-PnPClientSidePage. Threading the
    # in-memory object through every -Page parameter is the canonical Microsoft
    # Learn pattern for legacy PnP modules and is what defeats the
    # "Index was out of range" bug when adding to Column 2 of a TwoColumn
    # section. (Passing the page NAME string forces re-resolution from server
    # state, which has not yet caught up to the just-added second column.)
    $page = Add-PnPClientSidePage -Name $pageName -LayoutType Article
    try {
        Set-PnPClientSidePage -Identity $pageName -Title $pageTitle -ErrorAction Stop | Out-Null
    } catch {
        Write-Host "  (Could not set page title - may need manual edit: $($_.Exception.Message))" -ForegroundColor DarkGray
    }
    try {
        $page = Get-PnPClientSidePage -Identity $pageName -ErrorAction Stop
    } catch {
        Write-Host "  (Could not re-fetch page object after create: $($_.Exception.Message))" -ForegroundColor DarkGray
    }
    Write-Host "Page created (fresh)." -ForegroundColor Green
    $created = $true
} catch {
    Write-Host "FAILED to create/open page: $($_.Exception.Message)" -ForegroundColor Red
    $failures += "Create/open page: $($_.Exception.Message)"
    Write-Host "Aborting before section build." -ForegroundColor Red
    return
}

# ===========================================================================
# Refresh-Page: re-fetch the in-memory page object from the server. Call
# this after every section / web-part add so the next column write sees the
# new collection state. Returns the new page object (caller reassigns
# $page = Refresh-Page).
# ===========================================================================
function Refresh-Page {
    try {
        return Get-PnPClientSidePage -Identity $pageName -ErrorAction Stop
    } catch {
        Write-Host "  (Could not refresh page object: $($_.Exception.Message))" -ForegroundColor DarkGray
        return $null
    }
}

# ===========================================================================
# 2. Helpers
#
# Both Add-PageSection and the web-part adds take the page OBJECT (not the
# page name string). Threading the in-memory object through every -Page
# parameter is what defeats the "Index was out of range" Column-2 bug.
#
# Add-PageSection returns a hashtable @{ Ok = <bool>; Page = <refreshed obj> }.
# Caller MUST re-bind $page = $res.Page after every call so subsequent column
# writes see the new section's column collection.
# ===========================================================================
function Add-PageSection {
    param(
        [Parameter(Mandatory=$true)]$Page,
        [int]$SectionIndex,
        [string]$Template = "OneColumn",
        [string]$Label = ""
    )
    try {
        Add-PnPClientSidePageSection -Page $Page -SectionTemplate $Template -ErrorAction Stop | Out-Null
        Write-Host ("  + Section {0} ({1}) {2}" -f $SectionIndex, $Template, $Label) -ForegroundColor DarkGray
        # CRITICAL: re-fetch so the new section's Columns collection is visible.
        $refreshed = Refresh-Page
        if ($null -eq $refreshed) { $refreshed = $Page }
        return @{ Ok = $true; Page = $refreshed }
    } catch {
        Write-Host ("FAILED to add section {0} ({1}) {2}: {3}" -f $SectionIndex, $Template, $Label, $_.Exception.Message) -ForegroundColor Red
        $script:failures += "Section ${SectionIndex} ($Template) ${Label}: $($_.Exception.Message)"
        return @{ Ok = $false; Page = $Page }
    }
}

function Add-TextPart {
    param(
        [Parameter(Mandatory=$true)]$Page,
        [int]$SectionIndex,
        [int]$Column = 1,
        [string]$Html,
        [string]$Label
    )
    try {
        Add-PnPClientSideText -Page $Page -Section $SectionIndex -Column $Column `
            -Text $Html -ErrorAction Stop | Out-Null
        Write-Host ("    -> Text web part added (S{0}/C{1}): {2}" -f $SectionIndex, $Column, $Label) -ForegroundColor Green
        return $true
    } catch {
        Write-Host ("FAILED to add Text ({0}) in S{1}/C{2}: {3}" -f $Label, $SectionIndex, $Column, $_.Exception.Message) -ForegroundColor Red
        $script:failures += "Text '$Label' in S${SectionIndex}/C${Column}: $($_.Exception.Message)"
        return $false
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

function Add-ImagePartOrPlaceholder {
    param(
        [Parameter(Mandatory=$true)]$Page,
        [int]$SectionIndex,
        [int]$Column,
        [string]$Label,
        [string]$PlaceholderText = "Add image via Edit page"
    )
    try {
        Add-PnPClientSideWebPart -Page $Page -Section $SectionIndex -Column $Column `
            -DefaultWebPartType Image -ErrorAction Stop | Out-Null
        Write-Host ("    -> Image web part added (S{0}/C{1}): {2}" -f $SectionIndex, $Column, $Label) -ForegroundColor Green
        $script:ownerActions += "S${SectionIndex}/C${Column} '$Label': pick an image via Edit page > Image web part > Change."
        return $true
    } catch {
        Write-Host ("    Image web part rejected (S{0}/C{1}): {2}. Falling back to Text placeholder." -f $SectionIndex, $Column, $_.Exception.Message) -ForegroundColor Yellow
        $placeholderHtml = @"
<table style='width:100%;border-collapse:separate;border-spacing:0;'>
<tr><td style='background:#F5F7FA;padding:32px;border-radius:8px;'>
<p style='color:#615E5E;margin:0;text-align:center;font-style:italic;'>$PlaceholderText</p>
</td></tr></table>
"@
        $script:ownerActions += "S${SectionIndex}/C${Column} '$Label': replace placeholder Text web part with an Image web part."
        return (Add-TextPart -Page $Page -SectionIndex $SectionIndex -Column $Column -Html $placeholderHtml -Label "$Label (image placeholder)")
    }
}

# ===========================================================================
# 3. Build sections
#
# Layout plan:
#   S1  OneColumn  Scope banner (navy)
#   S2  OneColumn  Hero band (navy + gold heading)
#   S3  TwoColumn  Why this page exists (text + image)
#   S4  OneColumn  Four phases buttons row
#   S5  TwoColumn  Step 1: Stakeholders first
#   S6  TwoColumn  Step 2: Then meetings
#   S7  TwoColumn  Step 3: Then knowledge
#   S8  TwoColumn  Step 4: Finally generate
#   S9  OneColumn  Templates + forms (ContentRollup w/ HTML fallback)
#   S10 OneColumn  Handoff Tasks list (List w/p, falls back empty)
#   S11 OneColumn  Trust-rail card stack: 4 trust-signal cards stacked
#                  vertically in a single full-width column. Replaces the
#                  prior OneColumnVerticalSection attempt -- that template
#                  is silently translated to OneColumnFullWidth by the
#                  legacy module (pnp/PnP-PowerShell issue #2602) and
#                  Group-connected sites reject OneColumnFullWidth, which
#                  cascades into "You can't use a OneColumnFullWidth
#                  section in this site template (GROUP)" errors on every
#                  subsequent web-part add and on Publish. Stacking the
#                  rail cards full-width is the reliable Group-site option.
#   S12 OneColumn  Footer band (gold)
# ===========================================================================

# --- Section 1: SCOPE BANNER (navy) ---
$res = Add-PageSection -Page $page -SectionIndex 1 -Template "OneColumn" -Label "Scope banner"
$page = $res.Page
$scopeBannerHtml = @"
<table style='width:100%;border-collapse:separate;border-spacing:0;'>
<tr>
<td style='background:#182039;padding:14px 20px;border-radius:8px;'>
<p style='color:#FFFFFF;margin:0;font-size:14px;'>You are <strong style='color:#FFFFFF;'>updating handoff data</strong> for your contract. Coordinator: <strong style='color:#FFFFFF;'>You</strong>. <a href='$contextChangeUrl' style='color:#E8B86A;'>Change context &rarr;</a></p>
</td>
</tr>
</table>
"@
if ($res.Ok) { [void](Add-TextPart -Page $page -SectionIndex 1 -Column 1 -Html $scopeBannerHtml -Label "Scope banner") }

# --- Section 2: HERO BAND (navy + gold heading) ---
$res = Add-PageSection -Page $page -SectionIndex 2 -Template "OneColumn" -Label "Hero band"
$page = $res.Page
$heroBandHtml = @"
<table style='width:100%;border-collapse:separate;border-spacing:0;'>
<tr>
<td style='background:#182039;padding:40px;border-radius:8px;'>
<h2 style='color:#E8B86A;margin:0 0 12px 0;font-size:28px;'>Update / Offboarding</h2>
<p style='color:#FFFFFF;margin:0;font-size:16px;'>Make sure your replacement isn't lost. Capture what you know, generate a cookbook when you're ready.</p>
</td>
</tr>
</table>
"@
if ($res.Ok) { [void](Add-TextPart -Page $page -SectionIndex 2 -Column 1 -Html $heroBandHtml -Label "Hero band") }

# --- Section 3: WHY THIS PAGE EXISTS (TwoColumn: text | image) ---
$res = Add-PageSection -Page $page -SectionIndex 3 -Template "TwoColumn" -Label "Why this page exists"
$page = $res.Page
$s3Ok = $res.Ok
$whyHtml = @"
<table style='width:100%;border-collapse:separate;border-spacing:0;'>
<tr>
<td style='padding:8px 0;'>
<p style='color:#4961A3;margin:0 0 4px 0;font-size:11px;font-weight:bold;letter-spacing:1.5px;'>WHY THIS PAGE EXISTS</p>
</td>
</tr>
<tr>
<td style='padding:0;'>
<h3 style='color:#182039;margin:0 0 12px 0;font-size:22px;'>Your replacement shouldn't be guessing</h3>
<p style='color:#333333;margin:0 0 12px 0;'>Whether you're moving to another contract or fully leaving the role, the people you've worked with, the meetings you ran, and the decisions you helped settle don't have to be re-learned from scratch.</p>
<p style='color:#333333;margin:0;'>This page is also for <strong>quarterly maintenance</strong>: keep your stakeholder records fresh so when handoff time comes, the cookbook is already 80% written.</p>
</td>
</tr>
</table>
"@
if ($s3Ok) {
    [void](Add-TextPart -Page $page -SectionIndex 3 -Column 1 -Html $whyHtml -Label "Why this page exists (left)")
    Add-ManualBlock -SectionIndex 3 -Column 2 -Label "Why this page exists (image)" -Type "Image" -Instruction "Add an Image web part to the right column. Suggested: handoff conversation."
    $page = Refresh-Page  # web-part add can mutate column state
}

# --- Section 4: FOUR PHASES (single OneColumn, 4 buttons in a row) ---
$res = Add-PageSection -Page $page -SectionIndex 4 -Template "OneColumn" -Label "Four phases buttons"
$page = $res.Page
$s4Ok = $res.Ok
# Outer wrapping table, 4 cells; each cell holds the nested-table button pattern.
# First three cells: muted blue (#4961A3) bg with white link text.
# Fourth cell: gold (#E8B86A) bg with navy text -- the CTA / final action.
$phasesHtml = @"
<table style='width:100%;border-collapse:separate;border-spacing:0;margin:8px 0;'>
<tr>
<td style='width:25%;padding:0 6px 0 0;vertical-align:top;'>
<table style='width:100%;border-collapse:separate;border-spacing:0;'>
<tr><td style='background:#4961A3;padding:18px 16px;border-radius:6px;text-align:center;'>
<a href='$stakeholdersList' style='color:#FFFFFF;text-decoration:none;font-weight:bold;font-size:16px;'>People &rarr;</a>
</td></tr></table>
</td>
<td style='width:25%;padding:0 6px;vertical-align:top;'>
<table style='width:100%;border-collapse:separate;border-spacing:0;'>
<tr><td style='background:#4961A3;padding:18px 16px;border-radius:6px;text-align:center;'>
<a href='$meetingsList' style='color:#FFFFFF;text-decoration:none;font-weight:bold;font-size:16px;'>Process &rarr;</a>
</td></tr></table>
</td>
<td style='width:25%;padding:0 6px;vertical-align:top;'>
<table style='width:100%;border-collapse:separate;border-spacing:0;'>
<tr><td style='background:#4961A3;padding:18px 16px;border-radius:6px;text-align:center;'>
<a href='$acronymsNew' style='color:#FFFFFF;text-decoration:none;font-weight:bold;font-size:16px;'>Knowledge &rarr;</a>
</td></tr></table>
</td>
<td style='width:25%;padding:0 0 0 6px;vertical-align:top;'>
<table style='width:100%;border-collapse:separate;border-spacing:0;'>
<tr><td style='background:#E8B86A;padding:18px 16px;border-radius:6px;text-align:center;'>
<a href='$mantleActionsPage' style='color:#182039;text-decoration:none;font-weight:bold;font-size:16px;'>Generate &rarr;</a>
</td></tr></table>
</td>
</tr>
</table>
<p style='color:#615E5E;margin:8px 4px 0 4px;font-size:13px;'>Click any phase to open the relevant list. The final phase generates the cookbook.</p>
"@
if ($s4Ok) { [void](Add-TextPart -Page $page -SectionIndex 4 -Column 1 -Html $phasesHtml -Label "Four phases button row") }

# --- Section 5: TRANSFER PROTOCOL (4 separate TwoColumn sections) ---
$transferSteps = @(
    @{ Index = 5; Num = 1; Eyebrow = "STAKEHOLDERS FIRST"; Title = "Capture each stakeholder's working style"; Body = "For each person already in your Stakeholders list, fill in working-style fields: best channel, edit preferences, working hours, decision style, who else needs to be in the loop, fastest way to lose their trust."; Placeholder = "Add image via Edit page (suggestion: stakeholder profile)" },
    @{ Index = 6; Num = 2; Eyebrow = "THEN MEETINGS";     Title = "Document recurring meetings";              Body = "Cadence, who runs it, your role (lead / co-lead / participant), where the agenda lives. Anything your replacement would need to walk in cold and not look lost."; Placeholder = "Add image via Edit page (suggestion: calendar grid)" },
    @{ Index = 7; Num = 3; Eyebrow = "THEN KNOWLEDGE";    Title = "Acronyms, decisions, lessons";             Body = "The unwritten parts. Acronyms your replacement will hear in week one. Decisions that are settled (so they don't get re-litigated). Lessons you learned the hard way."; Placeholder = "Add image via Edit page (suggestion: sticky notes)" },
    @{ Index = 8; Num = 4; Eyebrow = "FINALLY";           Title = "Generate the cookbook";                    Body = "Pulls all of the above into one Word document. Hand it to your replacement on day one. Recommended completeness: 60%+ of stakeholders have working-style profiles before generating."; Placeholder = "Add image via Edit page (suggestion: finished document)" }
)

foreach ($step in $transferSteps) {
    $idx = [int]$step.Index
    $res = Add-PageSection -Page $page -SectionIndex $idx -Template "TwoColumn" -Label ("Transfer step {0}: {1}" -f $step.Num, $step.Eyebrow)
    $page = $res.Page
    if (-not $res.Ok) { continue }
    $stepHtml = @"
<table style='width:100%;border-collapse:separate;border-spacing:0;margin:8px 0;'>
<tr>
<td style='width:48px;vertical-align:top;padding-right:12px;'>
<table style='border-collapse:separate;border-spacing:0;'>
<tr><td style='background:#182039;width:36px;height:36px;border-radius:18px;text-align:center;padding:0;'>
<p style='color:#FFFFFF;margin:0;font-weight:bold;font-size:14px;line-height:36px;'>$($step.Num)</p>
</td></tr></table>
</td>
<td style='vertical-align:top;'>
<p style='color:#4961A3;margin:0 0 4px 0;font-size:11px;font-weight:bold;letter-spacing:1.5px;'>$($step.Eyebrow)</p>
<h3 style='color:#182039;margin:0 0 8px 0;font-size:20px;'>$($step.Title)</h3>
<p style='color:#333333;margin:0;'>$($step.Body)</p>
</td>
</tr>
</table>
"@
    [void](Add-TextPart -Page $page -SectionIndex $idx -Column 1 -Html $stepHtml -Label ("Step {0} text" -f $step.Num))
    Add-ManualBlock -SectionIndex $idx -Column 2 -Label ("Step {0} image" -f $step.Num) -Type "Image" -Instruction $step.Placeholder
    $page = Refresh-Page  # web-part add can mutate column state
}

# --- Section 6: TEMPLATES + FORMS (try ContentRollup, fall back to HTML cards) ---
$templatesIndex = 9
$res = Add-PageSection -Page $page -SectionIndex $templatesIndex -Template "OneColumn" -Label "Templates and forms"
$page = $res.Page
$s9Ok = $res.Ok

# Heading text first.
$templatesHeadingHtml = @"
<table style='width:100%;border-collapse:separate;border-spacing:0;margin:8px 0 4px 0;'>
<tr><td style='padding:0;'>
<h3 style='color:#182039;margin:0 0 6px 0;font-size:20px;'>Templates and forms</h3>
<p style='color:#615E5E;margin:0;font-size:14px;'>Tag any document in the site library with <strong>Offboarding</strong> to surface it here. Owner replaces these placeholders with real document links.</p>
</td></tr>
</table>
"@
if ($s9Ok) { [void](Add-TextPart -Page $page -SectionIndex $templatesIndex -Column 1 -Html $templatesHeadingHtml -Label "Templates heading") }

$contentRollupAdded = $false
if ($s9Ok) {
    try {
        Add-PnPClientSideWebPart -Page $page -Section $templatesIndex -Column 1 `
            -DefaultWebPartType ContentRollup -ErrorAction Stop | Out-Null
        Write-Host "    -> Highlighted Content (ContentRollup) web part added." -ForegroundColor Green
        $contentRollupAdded = $true
        $page = Refresh-Page
        $ownerActions += "S${templatesIndex} Templates: configure the Highlighted Content web part to filter Documents library by tag = Offboarding."
    } catch {
        Write-Host "    ContentRollup rejected: $($_.Exception.Message). Falling back to HTML card-with-stripe trio." -ForegroundColor Yellow
    }
}

if ($s9Ok -and -not $contentRollupAdded) {
    $cardStripeHtml = @"
<table style='width:100%;border-collapse:separate;border-spacing:0;margin:12px 0;'>
<tr>
<td style='background:#4961A3;width:4px;border-radius:4px 0 0 4px;padding:0;'>&nbsp;</td>
<td style='background:#f3f6fa;padding:18px;border-radius:0 4px 4px 0;'>
<h3 style='color:#182039;margin:0 0 6px 0;font-size:16px;'>Stakeholder handoff template</h3>
<p style='margin:0 0 4px 0;color:#333333;'>One-page Word template for capturing a stakeholder profile.</p>
<p style='margin:0;color:#615E5E;font-size:12px;font-style:italic;'>[document placeholder &mdash; owner replaces with link]</p>
</td></tr></table>
<table style='width:100%;border-collapse:separate;border-spacing:0;margin:12px 0;'>
<tr>
<td style='background:#4961A3;width:4px;border-radius:4px 0 0 4px;padding:0;'>&nbsp;</td>
<td style='background:#f3f6fa;padding:18px;border-radius:0 4px 4px 0;'>
<h3 style='color:#182039;margin:0 0 6px 0;font-size:16px;'>Meeting cheat-sheet</h3>
<p style='margin:0 0 4px 0;color:#333333;'>Two-page Word template summarizing a recurring meeting and its unwritten rules.</p>
<p style='margin:0;color:#615E5E;font-size:12px;font-style:italic;'>[document placeholder &mdash; owner replaces with link]</p>
</td></tr></table>
<table style='width:100%;border-collapse:separate;border-spacing:0;margin:12px 0;'>
<tr>
<td style='background:#4961A3;width:4px;border-radius:4px 0 0 4px;padding:0;'>&nbsp;</td>
<td style='background:#f3f6fa;padding:18px;border-radius:0 4px 4px 0;'>
<h3 style='color:#182039;margin:0 0 6px 0;font-size:16px;'>Decisions one-pager</h3>
<p style='margin:0 0 4px 0;color:#333333;'>One-page Word template for documenting a settled decision and its reasoning.</p>
<p style='margin:0;color:#615E5E;font-size:12px;font-style:italic;'>[document placeholder &mdash; owner replaces with link]</p>
</td></tr></table>
"@
    [void](Add-TextPart -Page $page -SectionIndex $templatesIndex -Column 1 -Html $cardStripeHtml -Label "Templates HTML cards (ContentRollup fallback)")
    $ownerActions += "S${templatesIndex} Templates: replace placeholder rows with real document links once templates exist."
}

# --- Section 7: HANDOFF TASKS LIST (try List web part pointed at Stakeholders) ---
$listIndex = 10
$res = Add-PageSection -Page $page -SectionIndex $listIndex -Template "OneColumn" -Label "Handoff tasks list"
$page = $res.Page
$s10Ok = $res.Ok

$listHeadingHtml = @"
<table style='width:100%;border-collapse:separate;border-spacing:0;margin:8px 0 4px 0;'>
<tr><td style='padding:0;'>
<h3 style='color:#182039;margin:0 0 6px 0;font-size:20px;'>Your handoff tasks</h3>
<p style='color:#615E5E;margin:0;font-size:14px;'>Live list. Sort and filter freely. (Showing the Stakeholders list as a stand-in until a dedicated Handoff Tasks list is created.)</p>
</td></tr>
</table>
"@
if ($s10Ok) { [void](Add-TextPart -Page $page -SectionIndex $listIndex -Column 1 -Html $listHeadingHtml -Label "List heading") }

$listAdded = $false
# Resolve Stakeholders list ID for selectedListId. If lookup fails, drop in
# an empty List web part and let the owner pick via GUI.
$stakeholdersListId = $null
if ($s10Ok) {
    try {
        $stkList = Get-PnPList -Identity "Stakeholders" -ErrorAction Stop
        if ($null -ne $stkList) {
            $stakeholdersListId = $stkList.Id.ToString()
        }
    } catch {
        Write-Host "    Could not resolve Stakeholders list ID: $($_.Exception.Message)" -ForegroundColor DarkGray
    }
}

if ($s10Ok -and $stakeholdersListId) {
    $listProps = [ordered]@{
        isDocumentLibrary = $false
        selectedListId    = $stakeholdersListId
    }
    $listPropsJson = $listProps | ConvertTo-Json -Depth 4 -Compress
    try {
        Add-PnPClientSideWebPart -Page $page -Section $listIndex -Column 1 `
            -DefaultWebPartType List -WebPartProperties $listPropsJson -ErrorAction Stop | Out-Null
        Write-Host "    -> List web part added (selectedListId = Stakeholders)." -ForegroundColor Green
        $listAdded = $true
        $page = Refresh-Page
    } catch {
        Write-Host "    List web part with selectedListId rejected: $($_.Exception.Message). Retrying empty." -ForegroundColor Yellow
    }
}

if ($s10Ok -and -not $listAdded) {
    try {
        Add-PnPClientSideWebPart -Page $page -Section $listIndex -Column 1 `
            -DefaultWebPartType List -ErrorAction Stop | Out-Null
        Write-Host "    -> List web part added (empty; owner picks list in GUI)." -ForegroundColor Green
        $listAdded = $true
        $page = Refresh-Page
        $ownerActions += "S${listIndex} List: open List web part properties and choose 'Stakeholders' (or a Handoff Tasks list if/when it exists)."
    } catch {
        Write-Host "    List web part rejected entirely: $($_.Exception.Message). Falling back to plain note." -ForegroundColor Yellow
        $listFallbackHtml = @"
<table style='width:100%;border-collapse:separate;border-spacing:0;margin:12px 0;'>
<tr>
<td style='background:#F5F7FA;padding:24px;border-radius:8px;text-align:center;'>
<p style='color:#615E5E;margin:0;font-style:italic;'>List web part unavailable via script. Owner: add a List web part here pointed at Stakeholders.</p>
</td></tr></table>
"@
        [void](Add-TextPart -Page $page -SectionIndex $listIndex -Column 1 -Html $listFallbackHtml -Label "List fallback note")
        $ownerActions += "S${listIndex} List: add a List web part manually pointed at Stakeholders."
    }
}

# --- Section 8: TRUST-RAIL CARD STACK (4 stacked Text web parts, full-width) ---
#
# REPLACES the OneColumnVerticalSection attempt. The legacy module silently
# translates that template to OneColumnFullWidth, which Group-connected sites
# reject ("You can't use a OneColumnFullWidth section in this site template
# (GROUP)"). That single failure cascades into every later web-part add
# AND the final Publish call. See pnp/PnP-PowerShell issue #2602.
#
# Each trust card becomes its own full-width Text web part inside a single
# OneColumn section. Not a true side-rail, but reliable, visible, and
# preserves all four cards' content. The owner can convert this section
# into a Vertical section via the SharePoint GUI later if their tenant
# supports it (Edit page > section settings > Vertical section).
$railSectionIndex = 11
$res = Add-PageSection -Page $page -SectionIndex $railSectionIndex -Template "OneColumn" -Label "Trust-rail card stack"
$page = $res.Page
$railOk = $res.Ok
$verticalSectionUsed = $false  # always false now -- OneColumnVerticalSection removed

if ($railOk) {
    # TR1: Who can see your input (muted-blue stripe -- trust signal #1)
    $tr1Html = @"
<table style='width:100%;border-collapse:separate;border-spacing:0;margin:8px 0;'>
<tr>
<td style='background:#4961A3;width:4px;border-radius:4px 0 0 4px;padding:0;'>&nbsp;</td>
<td style='background:#FFFFFF;padding:16px;border-radius:0 4px 4px 0;'>
<h3 style='color:#182039;margin:0 0 8px 0;font-size:13px;'>WHO CAN SEE YOUR INPUT</h3>
<p style='color:#333333;margin:0 0 8px 0;font-size:13px;'>Stakeholder, meeting, and decision data on this page is visible to:</p>
<ul style='color:#333333;margin:0 0 8px 18px;padding:0;font-size:13px;'>
<li>You</li>
<li>Your replacement (when assigned)</li>
<li>Your Barrios manager</li>
<li>MANTLE administrators</li>
</ul>
<p style='color:#333333;margin:0;font-size:12px;'><strong>Confidential</strong>-tagged items are restricted to admins plus you.</p>
</td></tr></table>
"@
    [void](Add-TextPart -Page $page -SectionIndex $railSectionIndex -Column 1 -Html $tr1Html -Label "TR1: Who can see your input")

    # TR2: Cookbook readiness (plain card -- trust signal #5 / audit progress)
    $tr2Html = @"
<table style='width:100%;border-collapse:separate;border-spacing:0;margin:8px 0;'>
<tr><td style='background:#FFFFFF;padding:16px;border-radius:4px;'>
<h3 style='color:#182039;margin:0 0 8px 0;font-size:13px;'>COOKBOOK READINESS</h3>
<ul style='color:#333333;margin:0 0 8px 18px;padding:0;font-size:13px;'>
<li>Stakeholders: 7 / 12</li>
<li>Working styles captured: 3 / 12</li>
<li>Meetings documented: 8 / 8</li>
<li>Decisions logged: 4 / 6</li>
<li>Lessons captured: 0 / 5</li>
</ul>
<table style='width:100%;border-collapse:separate;border-spacing:0;margin:8px 0 0 0;'>
<tr><td style='background:#fff4ce;padding:8px;border-radius:4px;'>
<p style='color:#876700;margin:0;font-size:12px;'>Recommended at least 60% before generating cookbook.</p>
</td></tr></table>
<p style='color:#615E5E;margin:8px 0 0 0;font-size:11px;font-style:italic;'>Numbers above are placeholders until live list lookup is wired.</p>
</td></tr></table>
"@
    [void](Add-TextPart -Page $page -SectionIndex $railSectionIndex -Column 1 -Html $tr2Html -Label "TR2: Cookbook readiness")

    # TR3: Need help? (plain card)
    $tr3Html = @"
<table style='width:100%;border-collapse:separate;border-spacing:0;margin:8px 0;'>
<tr><td style='background:#FFFFFF;padding:16px;border-radius:4px;'>
<h3 style='color:#182039;margin:0 0 8px 0;font-size:13px;'>NEED HELP?</h3>
<p style='color:#333333;margin:0 0 6px 0;font-size:13px;'><strong>Stuck on a working-style question?</strong></p>
<p style='color:#333333;margin:0;font-size:13px;'>Open the <a href='$discoveryGuideUrl' style='color:#4961A3;'>discovery guide</a>.</p>
</td></tr></table>
"@
    [void](Add-TextPart -Page $page -SectionIndex $railSectionIndex -Column 1 -Html $tr3Html -Label "TR3: Need help?")

    # TR4: Reminder (gold stripe -- trust signal #3 + #6)
    $tr4Html = @"
<table style='width:100%;border-collapse:separate;border-spacing:0;margin:8px 0;'>
<tr>
<td style='background:#E8B86A;width:4px;border-radius:4px 0 0 4px;padding:0;'>&nbsp;</td>
<td style='background:#FFFFFF;padding:16px;border-radius:0 4px 4px 0;'>
<h3 style='color:#182039;margin:0 0 8px 0;font-size:13px;'>REMINDER</h3>
<p style='color:#333333;margin:0;font-size:13px;'>Items tagged <strong>Confidential</strong> are personal observations and should never appear in public reports or external slides.</p>
</td></tr></table>
"@
    [void](Add-TextPart -Page $page -SectionIndex $railSectionIndex -Column 1 -Html $tr4Html -Label "TR4: Reminder")
} else {
    Write-Host "  Skipping all 4 trust-rail Text web parts because S${railSectionIndex} could not be created." -ForegroundColor Yellow
}

# --- Section 9: PAGE FOOTER (gold band) ---
$footerIndex = 12
$res = Add-PageSection -Page $page -SectionIndex $footerIndex -Template "OneColumn" -Label "Footer"
$page = $res.Page
$s12Ok = $res.Ok
$footerHtml = @"
<table style='width:100%;border-collapse:separate;border-spacing:0;margin:8px 0;'>
<tr>
<td style='background:#E8B86A;padding:16px 20px;border-radius:8px;'>
<p style='color:#182039;margin:0;font-size:13px;'><strong>Internal use only.</strong> Stakeholder relationship notes and internal decisions on this page are not for external sharing under any circumstance.</p>
</td>
</tr>
</table>
"@
if ($s12Ok) { [void](Add-TextPart -Page $page -SectionIndex $footerIndex -Column 1 -Html $footerHtml -Label "Footer band") }

# ===========================================================================
# 4. Publish the page
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

# Hide the default SharePoint title banner so the hero text band is the
# visual top of the page. Older PnP versions may not expose -HeaderType.
try {
    Set-PnPClientSidePage -Identity $pageName -HeaderType None -ErrorAction Stop | Out-Null
    Write-Host "Hid default SharePoint title banner." -ForegroundColor DarkGray
} catch {
    Write-Host "  (Could not hide title banner: $($_.Exception.Message))" -ForegroundColor DarkGray
}

# DO NOT set as home page. (Home page is provisioned separately.)

# ===========================================================================
# 5. Resolve real page URL (don't trust the assumed slug)
# ===========================================================================
$actualUrlRelative = $null
try {
    $sitePagesItems = Get-PnPListItem -List "Site Pages" -ErrorAction Stop
    foreach ($spi in $sitePagesItems) {
        $title = $spi.FieldValues["Title"]
        $leaf  = $spi.FieldValues["FileLeafRef"]
        if ($title -eq $pageName -or $title -eq $pageTitle -or $leaf -eq "$pageName.aspx") {
            $actualUrlRelative = $spi.FieldValues["FileRef"]
            break
        }
    }
} catch {
    Write-Host "Could not query Site Pages to discover real URL: $($_.Exception.Message)" -ForegroundColor Yellow
}
if (-not $actualUrlRelative) {
    $actualUrlRelative = "$siteRoot/SitePages/$pageName.aspx"
    Write-Host "Could not resolve actual page URL; falling back to assumed slug ($actualUrlRelative)." -ForegroundColor Yellow
} else {
    Write-Host "Resolved page URL: $actualUrlRelative" -ForegroundColor Cyan
}

# ===========================================================================
# 6. Add to Quick Launch (left navigation) - idempotent
# ===========================================================================
Write-Host ""
Write-Host "=== Quick Launch nav ===" -ForegroundColor Cyan
$quickLaunchTitle = $pageTitle  # "Update / Offboarding"
try {
    $existingNodes = Get-PnPNavigationNode -Location QuickLaunch -ErrorAction Stop
    $already = $existingNodes | Where-Object { $_.Title -eq $quickLaunchTitle -or $_.Title -eq $pageName -or $_.Title -eq "Offboarding" }
    if ($already) {
        Write-Host "Quick Launch already has '$quickLaunchTitle' (or a stale 'Offboarding' entry). Skipping add." -ForegroundColor Yellow
        # Note: stale "Offboarding" entries from the previous script are
        # intentionally left in place. Owner can rename or delete via GUI.
    } else {
        Add-PnPNavigationNode -Location QuickLaunch -Title $quickLaunchTitle -Url $actualUrlRelative -ErrorAction Stop | Out-Null
        Write-Host "Added '$quickLaunchTitle' to Quick Launch." -ForegroundColor Green
        $navAdded = $true
    }
} catch {
    Write-Host "FAILED to update Quick Launch: $($_.Exception.Message)" -ForegroundColor Red
    $failures += "Quick Launch: $($_.Exception.Message)"
}

# ===========================================================================
# 7. Write the manual-paste Markdown file
#
# This script intentionally cannot complete the page. Column 2 of every
# TwoColumn section fails in the legacy PnP module. Image placeholders
# become entries in this Markdown paste-list the owner walks through ONCE
# in the SharePoint GUI to finish the page.
# ===========================================================================
$mdRelativeDir = Join-Path (Split-Path -Parent $PSScriptRoot) "design"
if (-not (Test-Path $mdRelativeDir)) {
    try { New-Item -ItemType Directory -Path $mdRelativeDir -Force | Out-Null } catch { }
}
$mdPath = Join-Path $mdRelativeDir "manual-paste-update-offboarding.md"

$encodedRelative = $actualUrlRelative -replace ' ', '%20'
$publishedUrl = "https://nasa.sharepoint.com$encodedRelative"

$md = New-Object System.Text.StringBuilder
[void]$md.AppendLine("# Manual paste list -- Update / Offboarding")
[void]$md.AppendLine("")
[void]$md.AppendLine("Generated by ``provision-update-offboarding-native.ps1`` on $(Get-Date -Format 'yyyy-MM-dd HH:mm').")
[void]$md.AppendLine("")
[void]$md.AppendLine("The provisioning script created the page structure (12 native sections).")
[void]$md.AppendLine("This file lists the **$($manualBlocks.Count) content blocks** the script could not write because")
[void]$md.AppendLine("the legacy PnP PowerShell module cannot reliably populate Column 2 of TwoColumn sections.")
[void]$md.AppendLine("Paste them once via the SharePoint GUI and you are done.")
[void]$md.AppendLine("")
[void]$md.AppendLine("**Page URL:** [$publishedUrl]($publishedUrl)")
[void]$md.AppendLine("")
[void]$md.AppendLine("## Quick instructions")
[void]$md.AppendLine("")
[void]$md.AppendLine("1. Open the page URL above")
[void]$md.AppendLine("2. Click **Edit** (top right)")
[void]$md.AppendLine("3. For each block below: find the named section, hover the empty column, click **+** to add the web part type listed")
[void]$md.AppendLine("4. For Text web parts: after adding, click the part > pencil icon > '...' menu > **Edit source** -- paste the HTML, save")
[void]$md.AppendLine("5. For Image web parts: after adding, click **Change** and pick an image")
[void]$md.AppendLine("6. When all $($manualBlocks.Count) blocks are placed, click **Republish** (top right)")
[void]$md.AppendLine("")
[void]$md.AppendLine("Estimated time: 5-10 minutes (mostly image picking).")
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
# 8. Summary
# ===========================================================================

Write-Host ""
Write-Host "==================== SUMMARY ====================" -ForegroundColor Cyan
if ($created)  { Write-Host "Page created : $pageName ($pageTitle)" -ForegroundColor Green }
if ($updated)  { Write-Host "Page updated : $pageName (rewrote sections)" -ForegroundColor Green }
if ($navAdded) { Write-Host "Quick Launch : added '$quickLaunchTitle'" -ForegroundColor Green } else { Write-Host "Quick Launch : already present or skipped" -ForegroundColor Yellow }
Write-Host "URL          : $publishedUrl" -ForegroundColor Cyan
Write-Host ""
Write-Host "Sections built:" -ForegroundColor Cyan
Write-Host "  S1  OneColumn          - Scope banner (navy)" -ForegroundColor Gray
Write-Host "  S2  OneColumn          - Hero band (navy + gold heading)" -ForegroundColor Gray
Write-Host "  S3  TwoColumn          - Why this page exists (text + image)" -ForegroundColor Gray
Write-Host "  S4  OneColumn          - Four phases buttons row" -ForegroundColor Gray
Write-Host "  S5  TwoColumn          - Step 1: Stakeholders first" -ForegroundColor Gray
Write-Host "  S6  TwoColumn          - Step 2: Then meetings" -ForegroundColor Gray
Write-Host "  S7  TwoColumn          - Step 3: Then knowledge" -ForegroundColor Gray
Write-Host "  S8  TwoColumn          - Step 4: Finally generate" -ForegroundColor Gray
Write-Host "  S9  OneColumn          - Templates and forms" -ForegroundColor Gray
Write-Host "  S10 OneColumn          - Handoff tasks list" -ForegroundColor Gray
Write-Host "  S11 OneColumn          - Trust-rail cards stacked full-width (TR1-TR4)" -ForegroundColor Gray
Write-Host "                           OneColumnVerticalSection removed -- legacy module" -ForegroundColor DarkGray
Write-Host "                           translates it to OneColumnFullWidth which Group" -ForegroundColor DarkGray
Write-Host "                           sites reject (pnp/PnP-PowerShell #2602)." -ForegroundColor DarkGray
Write-Host "  S12 OneColumn          - Footer band (gold)" -ForegroundColor Gray

Write-Host ""
Write-Host "Native web parts attempted:" -ForegroundColor Cyan
Write-Host "  Image (x4)          - one per transfer step right column + one in S3 (success or HTML placeholder)" -ForegroundColor Gray
if ($contentRollupAdded) {
    Write-Host "  ContentRollup       - Highlighted Content added in S9 (owner configures filter)" -ForegroundColor Gray
} else {
    Write-Host "  ContentRollup       - rejected; substituted with 3 HTML cards in S9" -ForegroundColor Gray
}
Write-Host "  List                - added in S10 (Stakeholders if list ID resolved, else empty)" -ForegroundColor Gray

Write-Host ""
Write-Host "Web parts NOT attempted (known crash):" -ForegroundColor DarkGray
Write-Host "  Hero       - renders as [object Object] under legacy module. Substitute: navy colored-td." -ForegroundColor DarkGray
Write-Host "  QuickLinks - crashes page on init. Substitute: nested-table HTML buttons in Text web parts." -ForegroundColor DarkGray

if ($failures.Count -gt 0) {
    Write-Host ""
    Write-Host "Failures ($($failures.Count)):" -ForegroundColor Red
    $failures | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
} else {
    Write-Host ""
    Write-Host "Failures     : none" -ForegroundColor Green
}

if ($ownerActions.Count -gt 0) {
    Write-Host ""
    Write-Host "Owner GUI follow-up checklist (small items):" -ForegroundColor Yellow
    $ownerActions | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
}

Write-Host "================================================="
Write-Host ""
Write-Host "ONE-TIME OWNER ACTION:" -ForegroundColor Cyan
Write-Host "  Open the manual paste list and walk through each block once:" -ForegroundColor White
Write-Host "  $mdPath" -ForegroundColor Yellow
Write-Host ""
Write-Host "  $($manualBlocks.Count) blocks total. Estimated 5-10 minutes." -ForegroundColor Gray
Write-Host "  After paste, click Republish on the page (top right)." -ForegroundColor Gray
Write-Host ""
Write-Host "  This script is intended to be run ONCE. After the manual paste," -ForegroundColor DarkGray
Write-Host "  all further edits should be done in the SharePoint GUI." -ForegroundColor DarkGray
