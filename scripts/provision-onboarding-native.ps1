# Provision the "Onboarding" SharePoint page using a HYBRID approach:
# native section/web-part scaffolding + sanitizer-safe HTML inside Text web
# parts. Pivot away from the prior Markdown-to-HTML pipeline -- this version
# matches the new native-composition mockup (design/onboarding-offboarding-
# native-mockup.html) by composing colored-td cards, hero bands, and button
# rows that survive the Text web part sanitizer.
#
# WHY HYBRID:
#   * Native Hero web part renders as "[object Object]" with the legacy
#     module's JSON shape -- substituted with a Text web part containing a
#     colored-td hero band.
#   * Native Quick Links web part crashes the page on init even when added
#     empty ("Cannot read properties of undefined (reading
#     'hasInitialLoadingState')") -- substituted with a Text web part
#     containing nested-table buttons.
#   * Native People and List web parts ARE attempted (best-effort) and
#     substituted with HTML cards if the legacy module rejects them.
#
# SANITIZER-SAFE HTML PATTERNS (only these survive published view):
#   * Hero band   -> single-cell colored-td <table>, h2 + p inside the td.
#   * Buttons     -> nested colored-td <table>, plain <a> inside (only the
#                    "color" inline style on <a> survives).
#   * Card stripe -> 2-cell <table>: a 4px-wide colored td next to a paper
#                    td. Sibling td technique because border-left on td is
#                    stripped by the sanitizer.
#
# NEVER use:
#   <h1> (rewritten to <h2>, color stripped); standalone styled headings
#   outside a colored td; border-left/border shorthand on td; style= on <a>
#   beyond color; class= attributes; <div> outside table-wrapper context;
#   theme tokens like var(--themePrimary).
#
# ENVIRONMENT
#   Site:    https://nasa.sharepoint.com/teams/PCTransitionSandbox
#            (Group-connected, Teams-backed -- OneColumnFullWidth is REJECTED)
#   Module:  legacy SharePointPnPPowerShellOnline on Windows PowerShell 5.1
#   Auth:    Connect-PnPOnline -UseWebLogin already run.
#
# SECTION TEMPLATES on Group sites (verified usable with legacy module):
#   OneColumn, TwoColumn, ThreeColumn. OneColumnFullWidth is REJECTED.
#   OneColumnVerticalSection (the "vertical section" / right rail) is
#   UNRELIABLE on Group-connected sites with the legacy PnP module -- the
#   template name was added late and many tenant configurations reject it
#   silently or noisily. We do NOT attempt it. Instead, we put the four
#   trust-signal "right rail" cards into the right column of a TwoColumn
#   section that runs alongside the main content sections, repeated as the
#   layout flows. This is a best-effort approximation; the true side-by-side
#   rail can be added by the owner via Edit page > convert sections to
#   "Vertical section" if their tenant exposes it.
#
# Cmdlets used (legacy SharePointPnPPowerShellOnline):
#   Add-PnPClientSidePage, Get-PnPClientSidePage, Set-PnPClientSidePage,
#   Remove-PnPClientSidePage, Add-PnPClientSidePageSection,
#   Add-PnPClientSideText, Add-PnPClientSideWebPart,
#   Add-PnPNavigationNode, Get-PnPNavigationNode, Get-PnPListItem,
#   Get-PnPList.

# ===========================================================================
# Configuration
# ===========================================================================
$siteUrl  = "https://nasa.sharepoint.com/teams/PCTransitionSandbox"
$siteRoot = "/teams/PCTransitionSandbox"

$pageName  = "Onboarding"
$pageTitle = "Onboarding"

# List form / view URLs the buttons point at.
$traineeProfilesNewFormUrl = "$siteUrl/Lists/Trainee%20Profiles/NewForm.aspx"
$traineeProfilesListUrl    = "$siteUrl/Lists/Trainee%20Profiles/AllItems.aspx"
$stakeholdersListUrl       = "$siteUrl/Lists/Stakeholders/AllItems.aspx"
$meetingsListUrl           = "$siteUrl/Lists/Meetings/AllItems.aspx"
$decisionsListUrl          = "$siteUrl/Lists/Decisions/AllItems.aspx"
$acronymsListUrl           = "$siteUrl/Lists/Acronyms/AllItems.aspx"
$toolsListUrl              = "$siteUrl/Lists/Tools/AllItems.aspx"
$equivalencyMapUrl         = "$siteUrl/Lists/Equivalency%20Map/AllItems.aspx"
$placeholderUrl            = "#"

# ===========================================================================
# Palette (literal hex everywhere)
# ===========================================================================
# Navy primary:  #182039
# Gold accent:   #E8B86A
# Muted blue:    #4961A3
# Charcoal text: #333333
# Paper bg:      #F5F7FA
# White:         #FFFFFF

$failures      = @()
$substitutions = @()
# Blocks the script CANNOT add via PowerShell (Column 2/3 of multi-column
# sections fail in the legacy PnP module). Captured here, written to a
# Markdown paste-list file at the end of the run for one-time manual setup.
$manualBlocks  = @()

# ===========================================================================
# 1. Delete-and-recreate the page (mirrors provision-home-native.ps1)
# ===========================================================================
Write-Host ""
Write-Host "=== Page: $pageName (hybrid native + sanitizer-safe HTML) ===" -ForegroundColor Cyan

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
            Write-Host "  Will attempt overwrite via -Name (may fail on corrupt sections)." -ForegroundColor DarkGray
        }
    }
    # Capture the page OBJECT returned by Add-PnPClientSidePage. Threading the
    # in-memory page object through every subsequent -Page parameter is the
    # canonical Microsoft Learn pattern for legacy PnP modules and is what
    # avoids the "Index was out of range" bug when adding a web part to
    # Column 2 of a TwoColumn section. Passing the page NAME (string) forces
    # the cmdlet to re-resolve from server state, which does not yet include
    # the just-added second column, and the cmdlet then throws on
    # page.Sections[X].Columns[1].
    $page = Add-PnPClientSidePage -Name $pageName -LayoutType Article
    try {
        Set-PnPClientSidePage -Identity $pageName -Title $pageTitle -ErrorAction Stop | Out-Null
    } catch {
        Write-Host "  (Could not set page title: $($_.Exception.Message))" -ForegroundColor DarkGray
    }
    # Re-fetch by name so we have a clean object backed by the persisted page.
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
# Refresh-Page: re-fetch the in-memory page object from the server.
# Call this after every section add so the next Add-PnPClientSideText
# / Add-PnPClientSideWebPart sees the new section's column collection.
# Returns the new page object (the caller should reassign $page = Refresh-Page).
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
# Both Add-Section and Add-TextPart take the page OBJECT (not the page name
# string). Passing the in-memory object through every -Page parameter is what
# defeats the "Index was out of range" Column-2 bug in the legacy module.
#
# Add-Section returns a hashtable: @{ Ok = <bool>; Page = <refreshed page obj> }
# so the caller can both re-bind $page (mandatory after every successful
# section add) and skip subsequent column writes when Ok is $false (defensive
# guard against cascading failures).
# ===========================================================================
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
        # CRITICAL: re-fetch the page object so its Sections collection
        # contains the new section's Columns. Without this re-fetch, the
        # very next Add-PnPClientSideText -Section $Index -Column 2 will
        # throw "Index was out of range" on TwoColumn / ThreeColumn templates.
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

# Add-ManualBlock: capture content the script CAN'T write (Column 2 of
# TwoColumn / Column 2-3 of ThreeColumn sections all fail in the legacy
# module). The owner pastes these via Edit page after the one-time script
# run. Blocks are emitted as a Markdown file at the end of the run.
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
# Layout plan (each section is independent; the right-rail trust cards are
# distributed across TwoColumn sections so they appear alongside main
# content, approximating the mockup's vertical right rail):
#
#   S1  OneColumn  -- Scope banner (full width, muted blue)
#   S2  OneColumn  -- Hero band (full width, navy)
#   S3  TwoColumn  -- L: Intro paragraph         | R: TR1 "Who can see your input"
#   S4  TwoColumn  -- L: Checklist picker (3 btn)| R: TR2 "Need help?"
#   S5  TwoColumn  -- L: 90-day Step 1 (Day 1)   | R: image placeholder
#   S6  TwoColumn  -- L: 90-day Step 2 (Week 1)  | R: image placeholder
#   S7  TwoColumn  -- L: 90-day Step 3 (Month 1) | R: image placeholder
#   S8  TwoColumn  -- L: 90-day Step 4 (Month 3) | R: image placeholder
#   S9  ThreeColumn -- People / Process / Tools reference cards
#   S10 TwoColumn  -- L: Mentors placeholder     | R: TR3 "Reminder" (gold)
#   S11 TwoColumn  -- L: Onboarding checklist    | R: TR4 "Your progress"
#   S12 OneColumn  -- Page footer (gold internal-only band)
# ===========================================================================

# --- S1: Scope banner (OneColumn, muted blue) --------------------------------
$res = Add-Section -Page $page -Index 1 -Template OneColumn -Label "Scope banner"
$page = $res.Page
$scopeBannerHtml = @"
<table style='width:100%;border-collapse:separate;border-spacing:0;margin:0 0 8px 0;'>
<tr><td style='background:#4961A3;padding:14px 20px;border-radius:8px;'>
<p style='color:#FFFFFF;margin:0;font-size:14px;'>You are being onboarded as a <strong>Project Coordinator</strong>. Edit the contract scope at the top of the Trainee Profile form.</p>
</td></tr></table>
"@
if ($res.Ok) { Add-TextPart -Page $page -Section 1 -Column 1 -Html $scopeBannerHtml -Label "S1 scope banner" }

# --- S2: Hero band (OneColumn, navy) -----------------------------------------
$res = Add-Section -Page $page -Index 2 -Template OneColumn -Label "Hero band"
$page = $res.Page
$heroBandHtml = @"
<table style='width:100%;border-collapse:separate;border-spacing:0;'>
<tr><td style='background:#182039;padding:40px;border-radius:8px;'>
<h2 style='color:#FFFFFF;margin:0 0 12px 0;font-size:28px;'>Onboarding</h2>
<p style='color:#FFFFFF;margin:0;font-size:16px;'>Five minutes to get from "I just got my badge" to "I know where to find what I need."</p>
</td></tr></table>
"@
if ($res.Ok) { Add-TextPart -Page $page -Section 2 -Column 1 -Html $heroBandHtml -Label "S2 hero band" }

# --- S3: Intro paragraph + TR1 trust-rail card -------------------------------
$res = Add-Section -Page $page -Index 3 -Template TwoColumn -Label "Intro + TR1"
$page = $res.Page
$introHtml = @"
<p style='color:#333333;font-size:15px;margin:0 0 8px 0;'>This page is the five-minute orientation that gets you from <em>I just got my badge</em> to <em>I know where to find what I need</em>. Walk through each section in order. By the end you will have a profile, a starter 30-60-90 plan, and a map of who does what for the contract you have been assigned to.</p>
"@
if ($res.Ok) { Add-TextPart -Page $page -Section 3 -Column 1 -Html $introHtml -Label "S3 intro paragraph" }

$tr1Html = @"
<table style='width:100%;border-collapse:separate;border-spacing:0;margin:0;'>
<tr>
<td style='background:#4961A3;width:4px;border-radius:4px 0 0 4px;padding:0;'>&nbsp;</td>
<td style='background:#FFFFFF;padding:18px;border-radius:0 4px 4px 0;'>
<h3 style='color:#182039;margin:0 0 10px 0;font-size:14px;'>WHO CAN SEE YOUR INPUT</h3>
<p style='margin:0 0 8px 0;color:#333333;font-size:13px;'>Data you save on this page is visible to:</p>
<table style='border-collapse:separate;border-spacing:0 4px;margin:0;'>
<tr><td style='background:#F5F7FA;padding:4px 8px;border-radius:3px;color:#333333;font-size:12px;'>You</td></tr>
<tr><td style='background:#F5F7FA;padding:4px 8px;border-radius:3px;color:#333333;font-size:12px;'>Your Barrios manager</td></tr>
<tr><td style='background:#F5F7FA;padding:4px 8px;border-radius:3px;color:#333333;font-size:12px;'>KITCHEN administrators</td></tr>
</table>
<p style='margin:10px 0 0 0;color:#333333;font-size:12px;'>Stakeholder records you create are visible to other PCs <strong>only if</strong> you tag them with shared scope.</p>
</td></tr></table>
"@
if ($res.Ok) { Add-ManualBlock -SectionIndex 3 -Column 2 -Label "TR1: Who can see your input" -Html $tr1Html -Type "Text" -Instruction "Add a Text web part to the right column. Click the Text web part > pencil icon > '...' menu > 'Edit source'. Paste the HTML below and save." }

# --- S4: Checklist picker (3 gold buttons) + TR2 Need help? -------------------
$res = Add-Section -Page $page -Index 4 -Template TwoColumn -Label "Checklist picker + TR2"
$page = $res.Page
$checklistPickerHtml = @"
<h2 style='color:#182039;margin:0 0 12px 0;font-size:22px;'>Pick a checklist to start</h2>
<table style='width:100%;border-collapse:separate;border-spacing:8px 0;'>
<tr>
<td style='vertical-align:top;'>
<table style='border-collapse:separate;border-spacing:0;margin:0;width:100%;'>
<tr><td style='background:#E8B86A;padding:14px 22px;border-radius:6px;text-align:center;'>
<a href='$traineeProfilesNewFormUrl' style='color:#182039;text-decoration:none;font-weight:bold;font-size:15px;'>Day 1 Checklist &rarr;</a>
</td></tr></table>
</td>
<td style='vertical-align:top;'>
<table style='border-collapse:separate;border-spacing:0;margin:0;width:100%;'>
<tr><td style='background:#E8B86A;padding:14px 22px;border-radius:6px;text-align:center;'>
<a href='$traineeProfilesNewFormUrl' style='color:#182039;text-decoration:none;font-weight:bold;font-size:15px;'>Week 1 Checklist &rarr;</a>
</td></tr></table>
</td>
<td style='vertical-align:top;'>
<table style='border-collapse:separate;border-spacing:0;margin:0;width:100%;'>
<tr><td style='background:#E8B86A;padding:14px 22px;border-radius:6px;text-align:center;'>
<a href='$traineeProfilesNewFormUrl' style='color:#182039;text-decoration:none;font-weight:bold;font-size:15px;'>30-Day Checklist &rarr;</a>
</td></tr></table>
</td>
</tr></table>
"@
if ($res.Ok) { Add-TextPart -Page $page -Section 4 -Column 1 -Html $checklistPickerHtml -Label "S4 checklist picker" }

$tr2Html = @"
<table style='width:100%;border-collapse:separate;border-spacing:0;margin:0;'>
<tr>
<td style='background:#4961A3;width:4px;border-radius:4px 0 0 4px;padding:0;'>&nbsp;</td>
<td style='background:#FFFFFF;padding:18px;border-radius:0 4px 4px 0;'>
<h3 style='color:#182039;margin:0 0 10px 0;font-size:14px;'>NEED HELP?</h3>
<p style='margin:0 0 8px 0;color:#333333;font-size:13px;'><strong>Stuck on a checklist item?</strong></p>
<p style='margin:0 0 8px 0;color:#333333;font-size:13px;'>Reach your assigned mentor or post in the #pc-onboarding channel.</p>
<p style='margin:0;'><a href='$placeholderUrl' style='color:#4961A3;font-weight:bold;'>Open #pc-onboarding &rarr;</a></p>
</td></tr></table>
"@
if ($res.Ok) { Add-ManualBlock -SectionIndex 4 -Column 2 -Label "TR2: Need help?" -Html $tr2Html -Type "Text" -Instruction "Add a Text web part to the right column. Edit source. Paste HTML." }

# --- 90-day arc helper: builds the left-column step card ---------------------
function New-StepCardHtml {
    param(
        [int]$Number,
        [string]$Eyebrow,
        [string]$Heading,
        [string]$Body
    )
    return @"
<table style='width:100%;border-collapse:separate;border-spacing:0;margin:0 0 8px 0;'>
<tr>
<td style='background:#4961A3;width:4px;border-radius:4px 0 0 4px;padding:0;'>&nbsp;</td>
<td style='background:#FFFFFF;padding:20px;border-radius:0 6px 6px 0;'>
<table style='border-collapse:separate;border-spacing:0;margin:0 0 8px 0;'>
<tr>
<td style='background:#182039;width:32px;height:32px;border-radius:16px;text-align:center;padding:0;'>
<span style='color:#FFFFFF;font-weight:bold;font-size:14px;'>$Number</span>
</td>
<td style='padding:0 0 0 12px;'>
<span style='color:#4961A3;font-size:11px;font-weight:bold;'>$Eyebrow</span>
</td>
</tr></table>
<h3 style='color:#182039;margin:0 0 6px 0;font-size:18px;'>$Heading</h3>
<p style='margin:0;color:#333333;font-size:14px;'>$Body</p>
</td></tr></table>
"@
}

function New-ImagePlaceholderHtml {
    param([string]$Caption)
    return @"
<table style='width:100%;border-collapse:separate;border-spacing:0;margin:0;'>
<tr><td style='background:#F5F7FA;padding:48px 20px;border-radius:6px;text-align:center;'>
<p style='margin:0;color:#615E5E;font-size:13px;'>$Caption</p>
<p style='margin:8px 0 0 0;color:#615E5E;font-size:12px;'>Add an image via Edit page &rarr; click placeholder &rarr; pick image.</p>
</td></tr></table>
"@
}

# --- S5: 90-day Step 1 (Day 1 - Land) ----------------------------------------
$res = Add-Section -Page $page -Index 5 -Template TwoColumn -Label "90-day Step 1 Day 1"
$page = $res.Page
if ($res.Ok) {
    Add-TextPart -Page $page -Section 5 -Column 1 -Label "S5 step1 text" `
        -Html (New-StepCardHtml -Number 1 -Eyebrow "DAY 1 &mdash; LAND" `
            -Heading "Get your accounts and meet your manager" `
            -Body "Confirm your laptop, badge, and SharePoint access work. Sit down with your Barrios manager for a 30-minute intro to the contract you have been placed on.")
    Add-ManualBlock -SectionIndex 5 -Column 2 -Label "Step 1 image" -Type "Image" -Instruction "Add an Image web part to the right column. Suggested image: first day at desk."
}

# --- S6: 90-day Step 2 (Week 1 - Listen) -------------------------------------
$res = Add-Section -Page $page -Index 6 -Template TwoColumn -Label "90-day Step 2 Week 1"
$page = $res.Page
if ($res.Ok) {
    Add-TextPart -Page $page -Section 6 -Column 1 -Label "S6 step2 text" `
        -Html (New-StepCardHtml -Number 2 -Eyebrow "WEEK 1 &mdash; LISTEN" `
            -Heading "Sit in on every recurring meeting once" `
            -Body "Do not speak &mdash; just listen. Note who runs each meeting, what gets decided there, and what is expected of the PC role. Come back here to record what you observed.")
    Add-ManualBlock -SectionIndex 6 -Column 2 -Label "Step 2 image" -Type "Image" -Instruction "Add an Image web part to the right column. Suggested image: meeting room."
}

# --- S7: 90-day Step 3 (Month 1 - Map) ---------------------------------------
$res = Add-Section -Page $page -Index 7 -Template TwoColumn -Label "90-day Step 3 Month 1"
$page = $res.Page
if ($res.Ok) {
    Add-TextPart -Page $page -Section 7 -Column 1 -Label "S7 step3 text" `
        -Html (New-StepCardHtml -Number 3 -Eyebrow "MONTH 1 &mdash; MAP" `
            -Heading "Build your stakeholder map" `
            -Body "Capture who matters, who owns what, and how each person prefers to work. Aim for 8-10 stakeholders with full working-style profiles.")
    Add-ManualBlock -SectionIndex 7 -Column 2 -Label "Step 3 image" -Type "Image" -Instruction "Add an Image web part to the right column. Suggested image: relationship diagram."
}

# --- S8: 90-day Step 4 (Month 3 - Own) ---------------------------------------
$res = Add-Section -Page $page -Index 8 -Template TwoColumn -Label "90-day Step 4 Month 3"
$page = $res.Page
if ($res.Ok) {
    Add-TextPart -Page $page -Section 8 -Column 1 -Label "S8 step4 text" `
        -Html (New-StepCardHtml -Number 4 -Eyebrow "MONTH 3 &mdash; OWN" `
            -Heading "Take ownership of one process end-to-end" `
            -Body "Pick something the team does weekly &mdash; a status report, a coordination meeting, a deliverable hand-off &mdash; and own it without hand-holding. This is your transition from learning to contributing.")
    Add-ManualBlock -SectionIndex 8 -Column 2 -Label "Step 4 image" -Type "Image" -Instruction "Add an Image web part to the right column. Suggested image: completing a deliverable."
}

# --- S9: ThreeColumn reference (People / Process / Tools) --------------------
# Card-with-stripe pattern: gold underline below the heading inside a paper bg.
$res = Add-Section -Page $page -Index 9 -Template ThreeColumn -Label "Reference 3-col"
$page = $res.Page
$s9Ok = $res.Ok

$peopleColHtml = @"
<table style='width:100%;border-collapse:separate;border-spacing:0;margin:0;'>
<tr><td style='background:#F5F7FA;padding:18px;border-radius:6px;'>
<h3 style='color:#182039;margin:0 0 8px 0;font-size:16px;'>People</h3>
<table style='width:100%;border-collapse:separate;border-spacing:0;margin:0 0 12px 0;'>
<tr><td style='background:#E8B86A;height:2px;padding:0;font-size:0;line-height:0;'>&nbsp;</td></tr></table>
<p style='margin:6px 0;font-size:13px;'><a href='$stakeholdersListUrl' style='color:#4961A3;'>Stakeholders directory</a></p>
<p style='margin:6px 0;font-size:13px;'><a href='$placeholderUrl' style='color:#4961A3;'>Org chart</a></p>
<p style='margin:6px 0;font-size:13px;'><a href='$placeholderUrl' style='color:#4961A3;'>Mentors program</a></p>
<p style='margin:6px 0;font-size:13px;'><a href='$placeholderUrl' style='color:#4961A3;'>PC alumni</a></p>
</td></tr></table>
"@
if ($s9Ok) { Add-TextPart -Page $page -Section 9 -Column 1 -Html $peopleColHtml -Label "S9 People col" }

$processColHtml = @"
<table style='width:100%;border-collapse:separate;border-spacing:0;margin:0;'>
<tr><td style='background:#F5F7FA;padding:18px;border-radius:6px;'>
<h3 style='color:#182039;margin:0 0 8px 0;font-size:16px;'>Process</h3>
<table style='width:100%;border-collapse:separate;border-spacing:0;margin:0 0 12px 0;'>
<tr><td style='background:#E8B86A;height:2px;padding:0;font-size:0;line-height:0;'>&nbsp;</td></tr></table>
<p style='margin:6px 0;font-size:13px;'><a href='$meetingsListUrl' style='color:#4961A3;'>Recurring meetings</a></p>
<p style='margin:6px 0;font-size:13px;'><a href='$decisionsListUrl' style='color:#4961A3;'>Decisions log</a></p>
<p style='margin:6px 0;font-size:13px;'><a href='$acronymsListUrl' style='color:#4961A3;'>Acronyms</a></p>
<p style='margin:6px 0;font-size:13px;'><a href='$placeholderUrl' style='color:#4961A3;'>Standard templates</a></p>
</td></tr></table>
"@
if ($s9Ok) { Add-ManualBlock -SectionIndex 9 -Column 2 -Label "Process column (links)" -Html $processColHtml -Type "Text" -Instruction "Add a Text web part to the middle column. Edit source. Paste HTML." }

$toolsColHtml = @"
<table style='width:100%;border-collapse:separate;border-spacing:0;margin:0;'>
<tr><td style='background:#F5F7FA;padding:18px;border-radius:6px;'>
<h3 style='color:#182039;margin:0 0 8px 0;font-size:16px;'>Tools</h3>
<table style='width:100%;border-collapse:separate;border-spacing:0;margin:0 0 12px 0;'>
<tr><td style='background:#E8B86A;height:2px;padding:0;font-size:0;line-height:0;'>&nbsp;</td></tr></table>
<p style='margin:6px 0;font-size:13px;'><a href='$toolsListUrl' style='color:#4961A3;'>Tool inventory</a></p>
<p style='margin:6px 0;font-size:13px;'><a href='$equivalencyMapUrl' style='color:#4961A3;'>Equivalency map</a></p>
<p style='margin:6px 0;font-size:13px;'><a href='$placeholderUrl' style='color:#4961A3;'>Access requests</a></p>
<p style='margin:6px 0;font-size:13px;'><a href='$placeholderUrl' style='color:#4961A3;'>Training paths</a></p>
</td></tr></table>
"@
if ($s9Ok) { Add-ManualBlock -SectionIndex 9 -Column 3 -Label "Tools column (links)" -Html $toolsColHtml -Type "Text" -Instruction "Add a Text web part to the right column. Edit source. Paste HTML." }

# --- S10: Mentors (try native People; fall back to HTML cards) + TR3 warn ----
$res = Add-Section -Page $page -Index 10 -Template TwoColumn -Label "Mentors + TR3"
$page = $res.Page
$s10Ok = $res.Ok

$mentorsAdded = $false
if ($s10Ok) {
    try {
        Add-PnPClientSideWebPart -Page $page -Section 10 -Column 1 `
            -DefaultWebPartType People -ErrorAction Stop | Out-Null
        Write-Host "Added native People web part (S10C1)." -ForegroundColor Green
        $mentorsAdded = $true
        # Web-part add can also mutate column state -- refresh.
        $page = Refresh-Page
    } catch {
        Write-Host "Native People web part failed (S10C1): $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "  Falling back to HTML person cards." -ForegroundColor DarkGray
        $script:substitutions += "People web part replaced with HTML person cards (S10C1)"
    }
}

if ($s10Ok -and -not $mentorsAdded) {
    $mentorsHtml = @"
<h2 style='color:#182039;margin:0 0 8px 0;font-size:22px;'>Your mentors</h2>
<p style='color:#333333;font-size:14px;margin:0 0 16px 0;'>Reach out within your first two weeks. Each mentor has done this role for at least 18 months and remembers what it felt like to start.</p>
<table style='width:100%;border-collapse:separate;border-spacing:8px 0;'>
<tr>
<td style='vertical-align:top;width:25%;'>
<table style='width:100%;border-collapse:separate;border-spacing:0;margin:0;'>
<tr>
<td style='background:#182039;width:4px;border-radius:4px 0 0 4px;padding:0;'>&nbsp;</td>
<td style='background:#F5F7FA;padding:14px;border-radius:0 4px 4px 0;text-align:center;'>
<p style='margin:0 0 4px 0;color:#182039;font-weight:bold;font-size:14px;'>Jamie Morales</p>
<p style='margin:0;color:#615E5E;font-size:12px;'>Senior PC &middot; ECS V</p>
</td></tr></table>
</td>
<td style='vertical-align:top;width:25%;'>
<table style='width:100%;border-collapse:separate;border-spacing:0;margin:0;'>
<tr>
<td style='background:#182039;width:4px;border-radius:4px 0 0 4px;padding:0;'>&nbsp;</td>
<td style='background:#F5F7FA;padding:14px;border-radius:0 4px 4px 0;text-align:center;'>
<p style='margin:0 0 4px 0;color:#182039;font-weight:bold;font-size:14px;'>Devon Rao</p>
<p style='margin:0;color:#615E5E;font-size:12px;'>PC Lead &middot; IMPACT</p>
</td></tr></table>
</td>
<td style='vertical-align:top;width:25%;'>
<table style='width:100%;border-collapse:separate;border-spacing:0;margin:0;'>
<tr>
<td style='background:#182039;width:4px;border-radius:4px 0 0 4px;padding:0;'>&nbsp;</td>
<td style='background:#F5F7FA;padding:14px;border-radius:0 4px 4px 0;text-align:center;'>
<p style='margin:0 0 4px 0;color:#182039;font-weight:bold;font-size:14px;'>Sara Kim</p>
<p style='margin:0;color:#615E5E;font-size:12px;'>Former PC, now PM</p>
</td></tr></table>
</td>
<td style='vertical-align:top;width:25%;'>
<table style='width:100%;border-collapse:separate;border-spacing:0;margin:0;'>
<tr>
<td style='background:#182039;width:4px;border-radius:4px 0 0 4px;padding:0;'>&nbsp;</td>
<td style='background:#F5F7FA;padding:14px;border-radius:0 4px 4px 0;text-align:center;'>
<p style='margin:0 0 4px 0;color:#182039;font-weight:bold;font-size:14px;'>Terrell Choi</p>
<p style='margin:0;color:#615E5E;font-size:12px;'>PC &middot; MCSO</p>
</td></tr></table>
</td>
</tr></table>
"@
    Add-TextPart -Page $page -Section 10 -Column 1 -Html $mentorsHtml -Label "S10 mentors HTML fallback"
}

$tr3Html = @"
<table style='width:100%;border-collapse:separate;border-spacing:0;margin:0;'>
<tr>
<td style='background:#E8B86A;width:4px;border-radius:4px 0 0 4px;padding:0;'>&nbsp;</td>
<td style='background:#FFFFFF;padding:18px;border-radius:0 4px 4px 0;'>
<h3 style='color:#182039;margin:0 0 10px 0;font-size:14px;'>REMINDER</h3>
<p style='margin:0;color:#333333;font-size:13px;'>Onboarding data is internal-only. Do not share these pages or list exports outside Barrios or your contract team.</p>
</td></tr></table>
"@
if ($s10Ok) { Add-ManualBlock -SectionIndex 10 -Column 2 -Label "TR3: Reminder (gold stripe)" -Html $tr3Html -Type "Text" -Instruction "Add a Text web part to the right column. Edit source. Paste HTML." }

# --- S11: Onboarding checklist list (try native List; fall back) + TR4 -------
$res = Add-Section -Page $page -Index 11 -Template TwoColumn -Label "Checklist list + TR4"
$page = $res.Page
$s11Ok = $res.Ok

$listAdded = $false
$traineeProfilesList = $null
if ($s11Ok) {
    try {
        $traineeProfilesList = Get-PnPList -Identity "Trainee Profiles" -ErrorAction Stop
    } catch {
        $traineeProfilesList = $null
    }
}

if ($s11Ok -and $null -ne $traineeProfilesList) {
    try {
        $listProps = @{ selectedListId = $traineeProfilesList.Id.ToString() } | ConvertTo-Json -Depth 3 -Compress
        Add-PnPClientSideWebPart -Page $page -Section 11 -Column 1 `
            -DefaultWebPartType List `
            -WebPartProperties $listProps -ErrorAction Stop | Out-Null
        Write-Host "Added native List web part bound to Trainee Profiles (S11C1)." -ForegroundColor Green
        $listAdded = $true
        $page = Refresh-Page
    } catch {
        Write-Host "List w/ selectedListId failed: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "  Trying empty List web part (owner picks list via GUI)." -ForegroundColor DarkGray
        try {
            Add-PnPClientSideWebPart -Page $page -Section 11 -Column 1 `
                -DefaultWebPartType List -ErrorAction Stop | Out-Null
            Write-Host "Added empty List web part (S11C1) -- owner must pick a list." -ForegroundColor Green
            $listAdded = $true
            $page = Refresh-Page
            $script:substitutions += "List web part added empty; owner must pick 'Trainee Profiles' via Edit page (S11C1)"
        } catch {
            Write-Host "Empty List web part also failed: $($_.Exception.Message)" -ForegroundColor Yellow
            $script:substitutions += "List web part replaced with HTML link card (S11C1)"
        }
    }
} elseif ($s11Ok) {
    Write-Host "Trainee Profiles list not found; skipping native List web part." -ForegroundColor Yellow
    $script:substitutions += "List web part replaced with HTML link card -- 'Trainee Profiles' list missing (S11C1)"
}

if ($s11Ok -and -not $listAdded) {
    $listFallbackHtml = @"
<h2 style='color:#182039;margin:0 0 8px 0;font-size:22px;'>Your onboarding checklist</h2>
<p style='color:#333333;font-size:14px;margin:0 0 16px 0;'>Items below live in the Trainee Profiles list. Open the list to sort, filter, and mark complete.</p>
<table style='border-collapse:separate;border-spacing:0;margin:8px 0;'>
<tr><td style='background:#E8B86A;padding:14px 22px;border-radius:6px;'>
<a href='$traineeProfilesListUrl' style='color:#182039;text-decoration:none;font-weight:bold;font-size:15px;'>Open Trainee Profiles &rarr;</a>
</td></tr></table>
"@
    Add-TextPart -Page $page -Section 11 -Column 1 -Html $listFallbackHtml -Label "S11 list HTML fallback"
}

$tr4Html = @"
<table style='width:100%;border-collapse:separate;border-spacing:0;margin:0;'>
<tr>
<td style='background:#4961A3;width:4px;border-radius:4px 0 0 4px;padding:0;'>&nbsp;</td>
<td style='background:#FFFFFF;padding:18px;border-radius:0 4px 4px 0;'>
<h3 style='color:#182039;margin:0 0 10px 0;font-size:14px;'>YOUR PROGRESS</h3>
<p style='margin:0 0 6px 0;color:#333333;font-size:13px;'>Trainee profile <strong>[done]</strong></p>
<p style='margin:0 0 6px 0;color:#333333;font-size:13px;'>Day 1 checklist <strong>[done]</strong></p>
<p style='margin:0 0 6px 0;color:#333333;font-size:13px;'>Week 1 checklist <strong>[in progress]</strong></p>
<p style='margin:0 0 6px 0;color:#333333;font-size:13px;'>Stakeholder map <strong>[not started]</strong></p>
<p style='margin:0;color:#333333;font-size:13px;'>Working-style intake <strong>[not started]</strong></p>
</td></tr></table>
"@
if ($s11Ok) { Add-ManualBlock -SectionIndex 11 -Column 2 -Label "TR4: Your progress" -Html $tr4Html -Type "Text" -Instruction "Add a Text web part to the right column. Edit source. Paste HTML." }

# --- S12: Page footer (gold internal-only band) ------------------------------
$res = Add-Section -Page $page -Index 12 -Template OneColumn -Label "Footer"
$page = $res.Page
$footerHtml = @"
<table style='width:100%;border-collapse:separate;border-spacing:0;margin:8px 0 0 0;'>
<tr><td style='background:#E8B86A;padding:16px 20px;border-radius:6px;'>
<p style='margin:0;color:#182039;font-size:13px;'><strong>Internal use only.</strong> This page contains contract-sensitive context. Do not share externally, post to social media, or include in public reports.</p>
</td></tr></table>
"@
if ($res.Ok) { Add-TextPart -Page $page -Section 12 -Column 1 -Html $footerHtml -Label "S12 footer" }

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

# Hide the default SharePoint title banner so the hero band is the visual top.
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
# 6. Quick Launch nav (idempotent). Onboarding is NOT set as home page.
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
# 7. Write the manual-paste Markdown file
#
# This script intentionally cannot complete the page. SharePoint's legacy
# PnP module fails to write into Column 2 / 3 of multi-column sections, so
# every right-column trust card and image goes into a Markdown paste-list
# the owner walks through ONCE in the SharePoint GUI to finish the page.
# ===========================================================================
$mdRelativeDir = Join-Path (Split-Path -Parent $PSScriptRoot) "design"
if (-not (Test-Path $mdRelativeDir)) {
    try { New-Item -ItemType Directory -Path $mdRelativeDir -Force | Out-Null } catch { }
}
$mdPath = Join-Path $mdRelativeDir "manual-paste-onboarding.md"

$encodedRelative = $actualUrlRelative -replace ' ', '%20'
$publishedUrl    = "https://nasa.sharepoint.com$encodedRelative"

$md = New-Object System.Text.StringBuilder
[void]$md.AppendLine("# Manual paste list -- Onboarding")
[void]$md.AppendLine("")
[void]$md.AppendLine("Generated by ``provision-onboarding-native.ps1`` on $(Get-Date -Format 'yyyy-MM-dd HH:mm').")
[void]$md.AppendLine("")
[void]$md.AppendLine("The provisioning script created the page structure (12 native sections).")
[void]$md.AppendLine("This file lists the **$($manualBlocks.Count) content blocks** the script could not write because")
[void]$md.AppendLine("the legacy PnP PowerShell module cannot reliably populate Column 2 (or Column 3)")
[void]$md.AppendLine("of multi-column sections. Paste them once via the SharePoint GUI and you are done.")
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
[void]$md.AppendLine("Estimated time: 10-15 minutes.")
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
Write-Host "Page         : $pageName" -ForegroundColor Green
Write-Host "URL          : $publishedUrl" -ForegroundColor Cyan
Write-Host ""
Write-Host "Sections built (in order):" -ForegroundColor Cyan
Write-Host "  S1  OneColumn   - Scope banner (muted-blue band)" -ForegroundColor Gray
Write-Host "  S2  OneColumn   - Hero band (navy, 'Onboarding' + tagline)" -ForegroundColor Gray
Write-Host "  S3  TwoColumn   - L: intro paragraph              | R: TR1 'Who can see your input'" -ForegroundColor Gray
Write-Host "  S4  TwoColumn   - L: 3 gold checklist buttons     | R: TR2 'Need help?'" -ForegroundColor Gray
Write-Host "  S5  TwoColumn   - L: Step 1 Day 1 - Land          | R: image placeholder" -ForegroundColor Gray
Write-Host "  S6  TwoColumn   - L: Step 2 Week 1 - Listen       | R: image placeholder" -ForegroundColor Gray
Write-Host "  S7  TwoColumn   - L: Step 3 Month 1 - Map         | R: image placeholder" -ForegroundColor Gray
Write-Host "  S8  TwoColumn   - L: Step 4 Month 3 - Own         | R: image placeholder" -ForegroundColor Gray
Write-Host "  S9  ThreeColumn - People / Process / Tools reference cards" -ForegroundColor Gray
Write-Host "  S10 TwoColumn   - L: Mentors (People web part or HTML cards)" -ForegroundColor Gray
Write-Host "                   R: TR3 'Reminder' (gold stripe)" -ForegroundColor Gray
Write-Host "  S11 TwoColumn   - L: Onboarding checklist (List web part or fallback)" -ForegroundColor Gray
Write-Host "                   R: TR4 'Your progress'" -ForegroundColor Gray
Write-Host "  S12 OneColumn   - Page footer (gold internal-only band)" -ForegroundColor Gray
Write-Host ""

if ($substitutions.Count -gt 0) {
    Write-Host "Substitutions ($($substitutions.Count)):" -ForegroundColor Yellow
    $substitutions | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
} else {
    Write-Host "Substitutions: none (all native web parts succeeded)" -ForegroundColor Green
}
Write-Host ""

if ($failures.Count -gt 0) {
    Write-Host "Failures ($($failures.Count)):" -ForegroundColor Red
    $failures | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    Write-Host ""
    Write-Host "NOTE: any web part the script could not fully configure can be" -ForegroundColor Yellow
    Write-Host "      finished in the SharePoint GUI (Edit page > click web part)." -ForegroundColor Yellow
} else {
    Write-Host "Failures     : none" -ForegroundColor Green
}
Write-Host "================================================="
Write-Host ""
Write-Host "ONE-TIME OWNER ACTION:" -ForegroundColor Cyan
Write-Host "  Open the manual paste list and walk through each block once:" -ForegroundColor White
Write-Host "  $mdPath" -ForegroundColor Yellow
Write-Host ""
Write-Host "  $($manualBlocks.Count) blocks total. Estimated 10-15 minutes." -ForegroundColor Gray
Write-Host "  After paste, click Republish on the page (top right)." -ForegroundColor Gray
Write-Host ""
Write-Host "  This script is intended to be run ONCE. After the manual paste," -ForegroundColor DarkGray
Write-Host "  all further edits should be done in the SharePoint GUI." -ForegroundColor DarkGray
