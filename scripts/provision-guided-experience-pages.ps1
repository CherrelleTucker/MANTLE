# Provision the MANTLE Guided Experience pages: Home, Onboarding, Offboarding.
# Assumes: Connect-PnPOnline -UseWebLogin already run against the MANTLE site.
# Target site: https://nasa.sharepoint.com/teams/PCTransitionSandbox
#
# Cmdlet versions:
#   Targets the legacy SharePointPnPPowerShellOnline module (PS 5.1).
#   Uses: Add-PnPClientSidePage, Add-PnPClientSidePageSection,
#         Add-PnPClientSideText, Set-PnPClientSidePage, Get-PnPClientSidePage,
#         Add-PnPNavigationNode, Get-PnPNavigationNode, Set-PnPHomePage.
#   In newer PnP.PowerShell modules these were renamed to
#   Add-PnPPage, Add-PnPPageSection, Add-PnPPageTextPart, Set-PnPPage, Get-PnPPage.
#
# Design source of truth: design/guided-experience-mockup.html
# This script approximates the mockup using HTML inside Text web parts.
# Native SharePoint Modern Pages cannot render the full mockup (no real chip
# selectors, no live counts, no progress bars driven by data). We fake those
# visually with inline-styled HTML.
#
# ASCII-only: any Unicode (arrows, em-dashes, emojis) is encoded as numeric
# HTML entities (e.g. &#128640; for rocket) or constructed at runtime via
# [char]0xXXXX. No raw Unicode in script literals.

$siteUrl  = "https://nasa.sharepoint.com/teams/PCTransitionSandbox"
$siteRoot = "/teams/PCTransitionSandbox"

# Brand palette (kept in one place so the three pages stay consistent)
$navy      = "#182039"
$navyDark  = "#0F1A2E"
$blue      = "#0693E3"
$gold      = "#E8B86A"
$goldDark  = "#C99A4A"
$bgGrey    = "#F5F7FA"
$cardGrey  = "#FAFBFD"
$textMuted = "#615E5E"
$borderLt  = "#E4E4E4"

# List URLs (assumed; if a list slug differs, fix in SharePoint and re-run)
$urlTraineeProfilesNew = "$siteUrl/Lists/Trainee%20Profiles/NewForm.aspx"
$urlTraineeProfiles    = "$siteUrl/Lists/Trainee%20Profiles/AllItems.aspx"
$urlTools              = "$siteUrl/Lists/Tools/AllItems.aspx"
$urlStakeholders       = "$siteUrl/Lists/Stakeholders/AllItems.aspx"
$urlStakeholdersNew    = "$siteUrl/Lists/Stakeholders/NewForm.aspx"
$urlMeetings           = "$siteUrl/Lists/Meetings/AllItems.aspx"
$urlMeetingsNew        = "$siteUrl/Lists/Meetings/NewForm.aspx"
$urlTasks              = "$siteUrl/Lists/30609090%20Tasks/AllItems.aspx"
$urlAcronyms           = "$siteUrl/Lists/Acronyms/AllItems.aspx"
$urlAcronymsNew        = "$siteUrl/Lists/Acronyms/NewForm.aspx"
$urlDecisions          = "$siteUrl/Lists/Decisions/AllItems.aspx"
$urlDecisionsNew       = "$siteUrl/Lists/Decisions/NewForm.aspx"
$urlLessons            = "$siteUrl/Lists/Lessons/AllItems.aspx"
$urlLessonsNew         = "$siteUrl/Lists/Lessons/NewForm.aspx"
$urlEquivalency        = "$siteUrl/Lists/Equivalency%20Map/AllItems.aspx"
$urlMantleActions      = "$siteUrl/SitePages/MANTLE-Actions.aspx"

$failures = @()

# ===========================================================================
# Helpers
# ===========================================================================

function Ensure-Page {
    param(
        [string]$Name,
        [string]$Title
    )
    $exists = $false
    try {
        $existing = Get-PnPClientSidePage -Identity $Name -ErrorAction Stop
        if ($null -ne $existing) { $exists = $true }
    } catch {
        $exists = $false
    }

    if (-not $exists) {
        Add-PnPClientSidePage -Name $Name -LayoutType Article | Out-Null
        try {
            Set-PnPClientSidePage -Identity $Name -Title $Title -ErrorAction Stop | Out-Null
        } catch {
            Write-Host "  (Could not set page title for $Name : $($_.Exception.Message))" -ForegroundColor DarkGray
        }
        Write-Host "Page '$Name' created." -ForegroundColor Green
        return "created"
    } else {
        Write-Host "Page '$Name' already exists. Wiping controls and rewriting." -ForegroundColor Yellow
        try {
            $page = Get-PnPClientSidePage -Identity $Name
            foreach ($ctrl in @($page.Controls)) {
                try {
                    Remove-PnPClientSideComponent -Page $Name -InstanceId $ctrl.InstanceId -Force -ErrorAction Stop | Out-Null
                } catch {
                    # Cmdlet may not exist or control not removable; tolerate.
                }
            }
        } catch {
            Write-Host "  Could not clear existing controls; new sections will append." -ForegroundColor Yellow
        }
        return "updated"
    }
}

function Add-Section {
    param(
        [string]$PageName,
        [int]$SectionIndex,
        [string[]]$TextBlocks
    )
    try {
        Add-PnPClientSidePageSection -Page $PageName -SectionTemplate OneColumn | Out-Null
    } catch {
        Write-Host "  FAILED to add section $SectionIndex on $PageName : $($_.Exception.Message)" -ForegroundColor Red
        $script:failures += "$PageName section $SectionIndex add: $($_.Exception.Message)"
        return
    }
    foreach ($block in $TextBlocks) {
        try {
            Add-PnPClientSideText -Page $PageName -Section $SectionIndex -Column 1 -Text $block | Out-Null
        } catch {
            Write-Host "  FAILED to add text in section $SectionIndex on $PageName : $($_.Exception.Message)" -ForegroundColor Red
            $script:failures += "$PageName section $SectionIndex text: $($_.Exception.Message)"
        }
    }
}

function Publish-Page {
    param([string]$Name, [string]$Title)
    try {
        Set-PnPClientSidePage -Identity $Name -Title $Title -Publish | Out-Null
        Write-Host "Page '$Name' published." -ForegroundColor Green
    } catch {
        Write-Host "  FAILED to publish $Name : $($_.Exception.Message)" -ForegroundColor Red
        $script:failures += "$Name publish: $($_.Exception.Message)"
    }
    # Hide SharePoint's default page title banner so our custom navy hero
    # is the only header. Wrapped in try/catch — older PnP versions may not
    # expose -HeaderType.
    try {
        Set-PnPClientSidePage -Identity $Name -HeaderType None -ErrorAction Stop | Out-Null
        Write-Host "  Hid default SharePoint title banner on '$Name'." -ForegroundColor DarkGray
    } catch {
        Write-Host "  (Could not hide title banner on '$Name': $($_.Exception.Message))" -ForegroundColor DarkGray
    }
}

function Resolve-PageUrl {
    param([string]$Name)
    try {
        $sitePagesItems = Get-PnPListItem -List "Site Pages" -ErrorAction Stop
        foreach ($spi in $sitePagesItems) {
            $title = $spi.FieldValues["Title"]
            $leaf  = $spi.FieldValues["FileLeafRef"]
            if ($title -eq $Name -or $leaf -eq "$Name.aspx" -or $leaf -eq ($Name.Replace(' ','-') + ".aspx")) {
                return $spi.FieldValues["FileRef"]
            }
        }
    } catch {
        Write-Host "  Could not query Site Pages: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    return $null
}

function Add-NavIfMissing {
    param([string]$Title, [string]$UrlRelative)
    try {
        $existingNodes = Get-PnPNavigationNode -Location QuickLaunch -ErrorAction Stop
        $already = $existingNodes | Where-Object { $_.Title -eq $Title }
        if ($already) {
            Write-Host "  Quick Launch already has '$Title'." -ForegroundColor Yellow
        } else {
            Add-PnPNavigationNode -Location QuickLaunch -Title $Title -Url $UrlRelative -ErrorAction Stop | Out-Null
            Write-Host "  Added '$Title' to Quick Launch." -ForegroundColor Green
        }
    } catch {
        Write-Host "  FAILED to update Quick Launch for '$Title': $($_.Exception.Message)" -ForegroundColor Red
        $script:failures += "Quick Launch '$Title': $($_.Exception.Message)"
    }
}

# ===========================================================================
# PAGE 1: MANTLE Home
# ===========================================================================
Write-Host ""
Write-Host "=== PAGE 1: MANTLE Home ===" -ForegroundColor Cyan

$homeName  = "MANTLE Home"
$homeTitle = "MANTLE Home"

$homeStatus = Ensure-Page -Name $homeName -Title $homeTitle

# --- Section 1: Hero (navy gradient) ---
# Emoji fallback: rocket [ROCKET] = &#128640;  package [BOX] = &#128230;
$homeHeroHtml = @"
<div style='background: linear-gradient(135deg, $navy 0%, $blue 100%); padding: 80px 32px 60px; text-align: center; border-radius: 8px;'>
  <div style='font-size: 12px; letter-spacing: 3px; text-transform: uppercase; color: #FFFFFF; margin-bottom: 8px; text-shadow: 0 1px 2px rgba(0,0,0,0.3); opacity: 0.95;'>NASA Project Coordinator Platform</div>
  <h1 style='font-size: 48px; font-weight: 600; line-height: 1.1; margin: 0 0 10px 0; color: #FFFFFF; text-shadow: 0 2px 4px rgba(0,0,0,0.4);'>Welcome to MANTLE</h1>
  <div style='font-size: 14px; letter-spacing: 1.5px; color: #FFFFFF; margin: 0 0 18px 0; text-shadow: 0 1px 2px rgba(0,0,0,0.35); font-weight: 500;'>MANUAL &nbsp;&middot;&nbsp; ACRONYMS &nbsp;&middot;&nbsp; NOTES &nbsp;&middot;&nbsp; TRANSITION &nbsp;&middot;&nbsp; LOGISTICS &nbsp;&middot;&nbsp; ENGAGEMENT</div>
  <div style='font-size: 18px; color: #FFFFFF; max-width: 720px; margin: 0 auto; font-weight: 400; text-align: center; text-shadow: 0 1px 3px rgba(0,0,0,0.35);'>Knowledge collected by every coordinator who's done this role before you, so you don't have to start cold.</div>
</div>
"@
Add-Section -PageName $homeName -SectionIndex 1 -TextBlocks @($homeHeroHtml)

# --- Section 2: Two big cards (Onboarding navy / Offboarding gold) ---
# Use a TABLE for layout because SharePoint Modern Page CSS strips/overrides
# CSS Grid in Text web parts. Tables are bulletproof across renderers.
$homeCardsHtml = @"
<table border='0' style='width: 100%; max-width: 920px; margin: 0 auto; border-collapse: separate; border-spacing: 12px; border: 0;' cellpadding='0' cellspacing='12'>
  <tr>
    <td style='width: 50%; vertical-align: top; padding: 0; border: 0;'>
      <a href='$siteUrl/SitePages/Onboarding.aspx' style='display:block; background: white; padding: 40px 32px; border-radius: 12px; box-shadow: 0 8px 32px rgba(0,0,0,0.12); text-align: center; text-decoration: none; color: $navy; border: 0; border-top: 4px solid $navy; outline: none;'>
        <div style='font-size: 56px; margin-bottom: 16px;'>&#128640;</div>
        <div style='font-size: 22px; font-weight: 600; margin-bottom: 8px; color: $navy;'>I'm joining a new team</div>
        <div style='font-size: 14px; color: $textMuted; line-height: 1.5;'>Walk me through who you are, what tools you use, how you communicate, and what my day-to-day looks like.</div>
      </a>
    </td>
    <td style='width: 50%; vertical-align: top; padding: 0; border: 0;'>
      <a href='$siteUrl/SitePages/Offboarding.aspx' style='display:block; background: white; padding: 40px 32px; border-radius: 12px; box-shadow: 0 8px 32px rgba(0,0,0,0.12); text-align: center; text-decoration: none; color: $navy; border: 0; border-top: 4px solid $gold; outline: none;'>
        <div style='font-size: 56px; margin-bottom: 16px;'>&#128230;</div>
        <div style='font-size: 22px; font-weight: 600; margin-bottom: 8px; color: $navy;'>I'm wrapping up my role</div>
        <div style='font-size: 14px; color: $textMuted; line-height: 1.5;'>Help me capture what I know so my replacement isn't lost. Generate a cookbook when I'm ready.</div>
      </a>
    </td>
  </tr>
</table>
"@
Add-Section -PageName $homeName -SectionIndex 2 -TextBlocks @($homeCardsHtml)

# --- Section 3: Secondary links row ---
# em-dash &#8212; ; middle-dot &#183;
$homeSecondaryHtml = @"
<div style='max-width: 920px; margin: 0 auto; padding: 24px 16px 40px; text-align: center; font-size: 14px;'>
  <a href='$urlTraineeProfiles' style='color: $navy; text-decoration: none; margin: 0 12px;'>I've been here before</a>
  <span style='color: $textMuted;'>&#183;</span>
  <a href='$urlMantleActions' style='color: $navy; text-decoration: none; margin: 0 12px;'>About MANTLE</a>
  <span style='color: $textMuted;'>&#183;</span>
  <a href='$urlEquivalency' style='color: $navy; text-decoration: none; margin: 0 12px;'>Browse the Equivalency Map</a>
</div>
"@
Add-Section -PageName $homeName -SectionIndex 3 -TextBlocks @($homeSecondaryHtml)

Publish-Page -Name $homeName -Title $homeTitle

# Try to set as site home page
try {
    $homeRelative = Resolve-PageUrl -Name $homeName
    if ($homeRelative) {
        # Set-PnPHomePage expects a server-relative URL like "SitePages/MANTLE-Home.aspx"
        # (without the site root). Trim the site root prefix.
        $homePathForCmd = $homeRelative
        if ($homePathForCmd.StartsWith($siteRoot + "/")) {
            $homePathForCmd = $homePathForCmd.Substring(($siteRoot + "/").Length)
        }
        try {
            Set-PnPHomePage -RootFolderRelativeUrl $homePathForCmd -ErrorAction Stop | Out-Null
            Write-Host "Set '$homeName' as site home page ($homePathForCmd)." -ForegroundColor Green
        } catch {
            Write-Host "  Could not set site home page (may need owner perms): $($_.Exception.Message)" -ForegroundColor Yellow
            $failures += "Set home page: $($_.Exception.Message)"
        }
    } else {
        Write-Host "  Could not resolve '$homeName' URL to set as home page." -ForegroundColor Yellow
    }
} catch {
    Write-Host "  Could not set site home page: $($_.Exception.Message)" -ForegroundColor Yellow
}

# ===========================================================================
# PAGE 2: Onboarding
# ===========================================================================
Write-Host ""
Write-Host "=== PAGE 2: Onboarding ===" -ForegroundColor Cyan

$onbName  = "Onboarding"
$onbTitle = "Onboarding"

$onbStatus = Ensure-Page -Name $onbName -Title $onbTitle

# ---------------------------------------------------------------------------
# LIVE DATA: pull Stakeholders / Meetings / Tools to render real cards/chips.
# Pattern mirrors generate-cookbook.ps1 (Get-PnPListItem + FieldValues).
# All reads are wrapped in try/catch so the page still publishes if a list
# is empty or temporarily unreachable.
# ---------------------------------------------------------------------------
function Get-Initials {
    param([string]$Name)
    if (-not $Name) { return "??" }
    # Force array context — single-element -split collapses to a string in PS,
    # which then makes $parts[0] return a Char instead of a string.
    [array]$parts = ($Name -replace '[^A-Za-z\s\-]', '' -split '\s+') | Where-Object { $_ -ne "" }
    if ($parts.Count -eq 0) { return "??" }
    if ($parts.Count -eq 1) {
        $p = [string]$parts[0]
        if ($p.Length -ge 2) { return $p.Substring(0,2).ToUpper() }
        return $p.ToUpper()
    }
    $first = ([string]$parts[0]).Substring(0,1)
    $last  = ([string]$parts[$parts.Count - 1]).Substring(0,1)
    return ($first + $last).ToUpper()
}

function HtmlEsc {
    param([string]$Text)
    if (-not $Text) { return "" }
    return ($Text -replace '&','&amp;' -replace '<','&lt;' -replace '>','&gt;' -replace '"','&quot;')
}

# Cadence priority for sorting meetings (higher = closer to top)
$cadencePriority = @{
    "Daily"     = 6
    "Weekly"    = 5
    "Bi-weekly" = 4
    "Monthly"   = 3
    "Quarterly" = 2
    "Annual"    = 1
    "Ad hoc"    = 0
}

Write-Host "Loading live data for Onboarding page..." -ForegroundColor DarkGray

# Stakeholders (top 6 by Influence then alpha)
$liveStakeholders = @()
$totalStakeholders = 0
try {
    $allSk = Get-PnPListItem -List "Stakeholders" -ErrorAction Stop
    $totalStakeholders = $allSk.Count
    $influenceRank = @{ "High" = 3; "Medium" = 2; "Low" = 1 }
    $liveStakeholders = $allSk | Sort-Object @{
        Expression = {
            $i = $_.FieldValues["Influence"]
            if ($i -and $influenceRank.ContainsKey($i)) { -$influenceRank[$i] } else { 0 }
        }
    }, @{ Expression = { $_.FieldValues["Title"] } } | Select-Object -First 6
    Write-Host "  Stakeholders: $totalStakeholders total, showing $($liveStakeholders.Count)" -ForegroundColor DarkGray
} catch {
    Write-Host "  Could not read Stakeholders list: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Meetings (top 5 by cadence priority)
$liveMeetings = @()
$totalMeetings = 0
try {
    $allMt = Get-PnPListItem -List "Meetings" -ErrorAction Stop
    $totalMeetings = $allMt.Count
    $liveMeetings = $allMt | Sort-Object @{
        Expression = {
            $c = $_.FieldValues["Cadence"]
            if ($c -and $cadencePriority.ContainsKey($c)) { -$cadencePriority[$c] } else { 0 }
        }
    }, @{ Expression = { $_.FieldValues["Title"] } } | Select-Object -First 5
    Write-Host "  Meetings: $totalMeetings total, showing $($liveMeetings.Count)" -ForegroundColor DarkGray
} catch {
    Write-Host "  Could not read Meetings list: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Tools (up to 15 for chip grid)
$liveTools = @()
$totalTools = 0
try {
    $allTl = Get-PnPListItem -List "Tools" -ErrorAction Stop
    $totalTools = $allTl.Count
    $liveTools = $allTl | Sort-Object @{ Expression = { $_.FieldValues["Title"] } } | Select-Object -First 15
    Write-Host "  Tools: $totalTools total, showing $($liveTools.Count)" -ForegroundColor DarkGray
} catch {
    Write-Host "  Could not read Tools list: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Stakeholders for working-style preview (first 3 — prefer ones with any
# working-style field populated; fallback to first 3 by influence).
$wsStakeholders = @()
try {
    $hasAnyWS = $liveStakeholders | Where-Object {
        $fv = $_.FieldValues
        $fv["PreferredChannel"] -or $fv["EditingPreference"] -or $fv["WorkingHours"] -or `
            $fv["NoticePreference"] -or $fv["DocumentStyle"] -or $fv["DecisionStyle"] -or $fv["Quirks"]
    }
    if ($hasAnyWS -and $hasAnyWS.Count -gt 0) {
        $wsStakeholders = $hasAnyWS | Select-Object -First 3
    } else {
        $wsStakeholders = $liveStakeholders | Select-Object -First 3
    }
} catch {}

# Helper for numbered onboarding sections (navy circle).
# (Returns HTML string; not a SharePoint helper.)
function New-OnbSection {
    param([string]$Num, [string]$Title, [string]$Lead, [string]$Body)
    return @"
<div style='background: white; border-radius: 8px; padding: 28px 32px; box-shadow: 0 1.6px 3.6px rgba(0,0,0,0.06); margin-bottom: 8px;'>
  <div>
    <span style='display: inline-block; width: 28px; height: 28px; background: #E1ECF7; color: $navy; border-radius: 50%; text-align: center; line-height: 28px; font-weight: 600; font-size: 13px; margin-right: 10px;'>$Num</span>
    <h2 style='font-size: 20px; font-weight: 600; display: inline-block; vertical-align: middle; margin: 0; color: $navy;'>$Title</h2>
  </div>
  <div style='font-size: 14px; color: $textMuted; margin: 6px 0 16px 38px;'>$Lead</div>
  <div style='margin-left: 38px;'>$Body</div>
</div>
"@
}

# --- Section 1: Header (navy gradient) ---
$onbHeaderHtml = @"
<div style='background: linear-gradient(135deg, $navy 0%, $blue 100%); color: white; padding: 56px 32px 48px; text-align: center; border-radius: 8px;'>
  <div style='font-size: 11px; letter-spacing: 2.5px; text-transform: uppercase; opacity: 0.85; margin-bottom: 12px;'>Onboarding</div>
  <h1 style='font-size: 36px; font-weight: 300; margin: 0 0 12px 0; color: white;'>Welcome to the team!</h1>
  <div style='font-size: 16px; opacity: 0.95; max-width: 640px; margin: 0 auto;'>Let's set you up. Five minutes through this page and you'll know where to find what you need.</div>
</div>
"@
Add-Section -PageName $onbName -SectionIndex 1 -TextBlocks @($onbHeaderHtml)

# --- Section 2: Step 1 - Tell us about you ---
$onb1 = New-OnbSection -Num "1" -Title "Tell us about you" `
    -Lead "Confirm a few basics so we can personalize what you see." `
    -Body "<p style='font-size: 14px; margin: 0 0 12px 0;'>SharePoint forms can't render the inline name and start-date fields from the mockup. For now, fill out your Trainee Profile to capture the same info.</p><p style='margin: 0;'><a href='$urlTraineeProfilesNew' style='display:inline-block; padding: 10px 22px; background: $navy; color: white; border-radius: 4px; text-decoration: none; font-weight: 600; font-size: 14px;'>Create my Trainee Profile</a></p>"
Add-Section -PageName $onbName -SectionIndex 2 -TextBlocks @($onb1)

# --- Section 3: Step 2 - Tools (LIVE chip grid) ---
# Render up to 15 tools from the Tools list as visual chips. Not interactive
# (SharePoint Text web parts strip JS) — just a quick visual scan of the
# tooling vocabulary the new PC may be coming from / heading toward.
$toolChipsHtml = ""
if ($liveTools.Count -gt 0) {
    $chipParts = @()
    foreach ($t in $liveTools) {
        $tName = HtmlEsc($t.FieldValues["Title"])
        if (-not $tName) { continue }
        $chipParts += "<span style='display:inline-block; padding: 8px 14px; background: $cardGrey; border: 2px solid $borderLt; border-radius: 6px; font-size: 13px; color: $navy; margin: 0 6px 8px 0;'>$tName</span>"
    }
    $toolChipsHtml = "<div style='margin-top: 4px; line-height: 2;'>" + ($chipParts -join "") + "</div>"
    if ($totalTools -gt $liveTools.Count) {
        $remaining = $totalTools - $liveTools.Count
        $toolChipsHtml += "<p style='font-size: 13px; color: $textMuted; margin: 10px 0 0 0; font-style: italic;'>Showing $($liveTools.Count) of $totalTools. <a href='$urlTools' style='color: $navy; font-weight: 600; text-decoration: none;'>Browse all tools &#8594;</a></p>"
    } else {
        $toolChipsHtml += "<p style='font-size: 13px; color: $textMuted; margin: 10px 0 0 0; font-style: italic;'>$totalTools tools catalogued so far. <a href='$urlEquivalency' style='color: $navy; font-weight: 600; text-decoration: none;'>See the Equivalency Map &#8594;</a></p>"
    }
} else {
    $toolChipsHtml = "<p style='font-size: 14px; margin: 0 0 12px 0;'>No tools catalogued yet. <a href='$urlTools' style='color: $navy; font-weight: 600; text-decoration: none;'>Open the Tools list &#8594;</a></p>"
}
$onb2 = New-OnbSection -Num "2" -Title "Tools you might be coming from" `
    -Lead "These are the tools this team has catalogued. The Equivalency Map shows what each one maps to in the new stack." `
    -Body $toolChipsHtml
Add-Section -PageName $onbName -SectionIndex 3 -TextBlocks @($onb2)

# --- Section 4: Step 3 - Here's your team (LIVE stakeholder cards) ---
# 3-column table grid (CSS grid is stripped by SharePoint, tables aren't).
# Avatar = colored circle with initials; card shows name / role / org.
$avatarPalette = @("#0693E3", "#182039", "#E8B86A", "#107c10", "#7E57C2", "#D32F2F")
$skBody = ""
if ($liveStakeholders.Count -gt 0) {
    $cardCells = @()
    $i = 0
    foreach ($s in $liveStakeholders) {
        $name = HtmlEsc($s.FieldValues["Title"])
        $role = HtmlEsc($s.FieldValues["Role"])
        $org  = HtmlEsc($s.FieldValues["OrgOrTeam"])
        $initials = HtmlEsc((Get-Initials $s.FieldValues["Title"]))
        $bg = $avatarPalette[$i % $avatarPalette.Count]
        $i++

        $roleLine = ""
        if ($role -and $org) { $roleLine = "$role &#183; $org" }
        elseif ($role)       { $roleLine = $role }
        elseif ($org)        { $roleLine = $org }
        else                 { $roleLine = "&nbsp;" }

        $cardCells += @"
<td style='width: 33%; vertical-align: top; padding: 6px;'>
  <div style='background: $cardGrey; padding: 16px; border-radius: 6px; min-height: 72px;'>
    <table border='0' cellpadding='0' cellspacing='0' style='border-collapse: collapse; border: 0;'>
      <tr>
        <td style='vertical-align: middle; padding-right: 12px; border: 0;'>
          <div style='width: 40px; height: 40px; border-radius: 50%; background: $bg; color: white; text-align: center; line-height: 40px; font-weight: 600; font-size: 14px;'>$initials</div>
        </td>
        <td style='vertical-align: middle; border: 0;'>
          <div style='font-size: 13px; font-weight: 600; color: $navy;'>$name</div>
          <div style='font-size: 12px; color: $textMuted;'>$roleLine</div>
        </td>
      </tr>
    </table>
  </div>
</td>
"@
    }

    # Pad row out to multiple of 3 (so the table grid renders evenly)
    while (($cardCells.Count % 3) -ne 0) {
        $cardCells += "<td style='width: 33%; padding: 6px; border: 0;'>&nbsp;</td>"
    }

    # Wrap into rows of 3
    $rowsHtml = ""
    for ($r = 0; $r -lt $cardCells.Count; $r += 3) {
        $rowsHtml += "<tr>" + $cardCells[$r] + $cardCells[$r+1] + $cardCells[$r+2] + "</tr>"
    }

    $skBody = "<table border='0' cellpadding='0' cellspacing='0' style='width: 100%; border-collapse: separate; border: 0;'>$rowsHtml</table>"

    $moreCount = $totalStakeholders - $liveStakeholders.Count
    if ($moreCount -gt 0) {
        $skBody += "<p style='font-size: 13px; color: $textMuted; margin: 12px 0 0 0;'>And $moreCount more. <a href='$urlStakeholders' style='color: $navy; font-weight: 600; text-decoration: none;'>View all in Stakeholders &#8594;</a></p>"
    } else {
        $skBody += "<p style='font-size: 13px; color: $textMuted; margin: 12px 0 0 0;'><a href='$urlStakeholders' style='color: $navy; font-weight: 600; text-decoration: none;'>Open Stakeholders &#8594;</a></p>"
    }
} else {
    $skBody = "<p style='font-size: 14px; margin: 0 0 12px 0;'>No stakeholders captured yet. <a href='$urlStakeholdersNew' style='color: $navy; font-weight: 600; text-decoration: none;'>Add your first stakeholder &#8594;</a></p>"
}
$onb3 = New-OnbSection -Num "3" -Title "Here's your team" `
    -Lead "The people you'll be working with most. Names, roles, who to ask what." `
    -Body $skBody
Add-Section -PageName $onbName -SectionIndex 4 -TextBlocks @($onb3)

# --- Section 5: Step 4 - How they communicate (LIVE meetings list) ---
# Each row: cadence pill (left) | meeting name + day/time (middle) | PC role pill (right)
$mtgBody = ""
if ($liveMeetings.Count -gt 0) {
    $mtgRows = ""
    foreach ($m in $liveMeetings) {
        $mName    = HtmlEsc($m.FieldValues["Title"])
        $mCadence = HtmlEsc($m.FieldValues["Cadence"])
        $mWhen    = HtmlEsc($m.FieldValues["DayAndTime"])
        $mRole    = HtmlEsc($m.FieldValues["PCRole"])
        if (-not $mCadence) { $mCadence = "TBD" }
        if (-not $mWhen)    { $mWhen    = "&nbsp;" }
        $roleHtml = ""
        if ($mRole) {
            $roleHtml = "<span style='display:inline-block; font-size: 11px; padding: 3px 10px; border-radius: 12px; background: #E1ECF7; color: $navy; font-weight: 600; text-transform: uppercase; letter-spacing: 0.5px;'>$mRole</span>"
        }
        $mtgRows += @"
<tr>
  <td style='width: 90px; vertical-align: middle; padding: 12px 8px 12px 0; border-bottom: 1px solid $bgGrey;'>
    <span style='display:inline-block; font-size: 11px; background: $cardGrey; color: $textMuted; padding: 4px 10px; border-radius: 4px; text-transform: uppercase; letter-spacing: 0.5px; text-align: center; font-weight: 600;'>$mCadence</span>
  </td>
  <td style='vertical-align: middle; padding: 12px 8px; border-bottom: 1px solid $bgGrey;'>
    <div style='font-size: 13px; font-weight: 600; color: $navy;'>$mName</div>
    <div style='font-size: 12px; color: $textMuted;'>$mWhen</div>
  </td>
  <td style='vertical-align: middle; padding: 12px 0 12px 8px; text-align: right; border-bottom: 1px solid $bgGrey;'>$roleHtml</td>
</tr>
"@
    }
    $mtgBody = "<table border='0' cellpadding='0' cellspacing='0' style='width: 100%; border-collapse: collapse;'>$mtgRows</table>"
    $moreM = $totalMeetings - $liveMeetings.Count
    if ($moreM -gt 0) {
        $mtgBody += "<p style='font-size: 13px; color: $textMuted; margin: 14px 0 0 0;'>Plus $moreM more in your Meetings catalog. <a href='$urlMeetings' style='color: $navy; font-weight: 600; text-decoration: none;'>Open Meetings &#8594;</a></p>"
    } else {
        $mtgBody += "<p style='font-size: 13px; color: $textMuted; margin: 14px 0 0 0;'><a href='$urlMeetings' style='color: $navy; font-weight: 600; text-decoration: none;'>Open Meetings &#8594;</a></p>"
    }
} else {
    $mtgBody = "<p style='font-size: 14px; margin: 0 0 12px 0;'>No recurring meetings catalogued yet. <a href='$urlMeetingsNew' style='color: $navy; font-weight: 600; text-decoration: none;'>Add your first meeting &#8594;</a></p>"
}
$onb4 = New-OnbSection -Num "4" -Title "How they communicate" `
    -Lead "The recurring meetings you'll be in, what's expected of you." `
    -Body $mtgBody
Add-Section -PageName $onbName -SectionIndex 5 -TextBlocks @($onb4)

# --- Section 6: Step 5 - Day-to-day (STATIC 30-60-90 timeline) ---
# Hardcoded sample tasks because real 30-60-90 Tasks are seeded per-PC after
# they create their Trainee Profile. This is the visual preview of "what your
# starter plan looks like."
$timelineHtml = @"
<table border='0' cellpadding='0' cellspacing='0' style='width: 100%; border-collapse: separate; border-spacing: 12px 0; border: 0;'>
  <tr>
    <td style='width: 33%; vertical-align: top; background: $cardGrey; border-radius: 6px; padding: 14px; border-top: 3px solid $navy;'>
      <h4 style='font-size: 12px; text-transform: uppercase; letter-spacing: 1px; color: $textMuted; margin: 0 0 8px 0;'>Days 1-30 &#183; Learn</h4>
      <ul style='list-style: none; padding: 0; margin: 0; font-size: 13px;'>
        <li style='padding: 4px 0; color: $navy;'>&#9675; Meet your Barrios manager</li>
        <li style='padding: 4px 0; color: $navy;'>&#9675; Read the role baseline</li>
        <li style='padding: 4px 0; color: $navy;'>&#9675; Walk the meeting catalog</li>
        <li style='padding: 4px 0; color: $navy;'>&#9675; Browse the acronyms</li>
        <li style='padding: 4px 0; color: $navy;'>&#9675; Add your first 3 stakeholders</li>
      </ul>
    </td>
    <td style='width: 33%; vertical-align: top; background: $cardGrey; border-radius: 6px; padding: 14px; border-top: 3px solid $blue;'>
      <h4 style='font-size: 12px; text-transform: uppercase; letter-spacing: 1px; color: $textMuted; margin: 0 0 8px 0;'>Days 31-60 &#183; Contribute</h4>
      <ul style='list-style: none; padding: 0; margin: 0; font-size: 13px;'>
        <li style='padding: 4px 0; color: $navy;'>&#9675; Take ownership of one deliverable</li>
        <li style='padding: 4px 0; color: $navy;'>&#9675; Propose 1 process improvement</li>
        <li style='padding: 4px 0; color: $navy;'>&#9675; Run your first 30-day retro</li>
        <li style='padding: 4px 0; color: $navy;'>&#9675; Build your stakeholder map</li>
        <li style='padding: 4px 0; color: $navy;'>&#9675; Document one weekly process</li>
      </ul>
    </td>
    <td style='width: 33%; vertical-align: top; background: $cardGrey; border-radius: 6px; padding: 14px; border-top: 3px solid #107c10;'>
      <h4 style='font-size: 12px; text-transform: uppercase; letter-spacing: 1px; color: $textMuted; margin: 0 0 8px 0;'>Days 61-90 &#183; Own</h4>
      <ul style='list-style: none; padding: 0; margin: 0; font-size: 13px;'>
        <li style='padding: 4px 0; color: $navy;'>&#9675; Lead a cross-team coordination</li>
        <li style='padding: 4px 0; color: $navy;'>&#9675; Implement one improvement</li>
        <li style='padding: 4px 0; color: $navy;'>&#9675; Run your 60-day review</li>
        <li style='padding: 4px 0; color: $navy;'>&#9675; Identify your "stupid questions" buddy</li>
        <li style='padding: 4px 0; color: $navy;'>&#9675; Plan next quarter's focus</li>
      </ul>
    </td>
  </tr>
</table>
<p style='font-size: 13px; color: $textMuted; margin: 14px 0 0 0;'>Your real plan gets seeded when you create your Trainee Profile. <a href='$urlTasks' style='color: $navy; font-weight: 600; text-decoration: none;'>Open my 30-60-90 Tasks &#8594;</a></p>
"@
$onb5 = New-OnbSection -Num "5" -Title "What your day-to-day can look like" `
    -Lead "A starter 30-60-90 plan. Skip what doesn't fit; mark done as you go." `
    -Body $timelineHtml
Add-Section -PageName $onbName -SectionIndex 6 -TextBlocks @($onb5)

# --- Section 7: Step 6 - How to work with each person (LIVE working-style preview) ---
# Static discovery-questions box + 3 stakeholder cards showing whatever
# working-style fields they have. Cards with no fields populated render as
# "Not yet captured" placeholders.
$wsCardsHtml = ""
if ($wsStakeholders -and $wsStakeholders.Count -gt 0) {
    $wsCells = @()
    $i2 = 0
    foreach ($s in $wsStakeholders) {
        $name = HtmlEsc($s.FieldValues["Title"])
        $role = HtmlEsc($s.FieldValues["Role"])
        $org  = HtmlEsc($s.FieldValues["OrgOrTeam"])
        $initials = HtmlEsc((Get-Initials $s.FieldValues["Title"]))
        $bg = $avatarPalette[$i2 % $avatarPalette.Count]
        $i2++

        $roleLine = ""
        if ($role -and $org) { $roleLine = "$role &#183; $org" }
        elseif ($role)       { $roleLine = $role }
        elseif ($org)        { $roleLine = $org }
        else                 { $roleLine = "&nbsp;" }

        # Build chips for any working-style fields that have values
        $chipBits = @()
        $pc = $s.FieldValues["PreferredChannel"]
        if ($pc) { $chipBits += "<span style='display:inline-block; font-size: 11px; background: white; border: 1px solid #C8C6C4; border-radius: 12px; padding: 3px 9px; color: $navy; margin: 0 4px 4px 0;'>" + (HtmlEsc $pc) + "</span>" }
        $ep = $s.FieldValues["EditingPreference"]
        if ($ep) { $chipBits += "<span style='display:inline-block; font-size: 11px; background: white; border: 1px solid #C8C6C4; border-radius: 12px; padding: 3px 9px; color: $navy; margin: 0 4px 4px 0;'>" + (HtmlEsc $ep) + "</span>" }
        $wh = $s.FieldValues["WorkingHours"]
        if ($wh) { $chipBits += "<span style='display:inline-block; font-size: 11px; background: white; border: 1px solid #C8C6C4; border-radius: 12px; padding: 3px 9px; color: $navy; margin: 0 4px 4px 0;'>" + (HtmlEsc $wh) + "</span>" }
        $ds = $s.FieldValues["DecisionStyle"]
        if ($ds) { $chipBits += "<span style='display:inline-block; font-size: 11px; background: white; border: 1px solid #C8C6C4; border-radius: 12px; padding: 3px 9px; color: $navy; margin: 0 4px 4px 0;'>" + (HtmlEsc $ds) + "</span>" }

        $quirk = $s.FieldValues["Quirks"]
        $quirkHtml = ""
        if ($quirk) {
            $quirkClean = (HtmlEsc $quirk)
            $quirkHtml = "<div style='font-size: 12px; color: $textMuted; font-style: italic; border-top: 1px dashed $borderLt; padding-top: 8px; margin-top: 8px; line-height: 1.4;'>$quirkClean</div>"
        }

        $chipsHtml = ""
        if ($chipBits.Count -gt 0) {
            $chipsHtml = "<div style='margin-bottom: 4px;'>" + ($chipBits -join "") + "</div>"
        } else {
            $chipsHtml = "<div style='font-size: 12px; color: $textMuted; font-style: italic; padding: 6px 0;'>Not yet captured. <a href='$urlStakeholders' style='color: $navy; font-weight: 600; text-decoration: none;'>Add details &#8594;</a></div>"
        }

        $wsCells += @"
<td style='width: 33%; vertical-align: top; padding: 6px;'>
  <div style='background: $cardGrey; border: 1px solid $borderLt; border-radius: 8px; padding: 16px;'>
    <table border='0' cellpadding='0' cellspacing='0' style='border-collapse: collapse; border: 0; margin-bottom: 12px;'>
      <tr>
        <td style='vertical-align: middle; padding-right: 12px; border: 0;'>
          <div style='width: 40px; height: 40px; border-radius: 50%; background: $bg; color: white; text-align: center; line-height: 40px; font-weight: 600; font-size: 14px;'>$initials</div>
        </td>
        <td style='vertical-align: middle; border: 0;'>
          <div style='font-size: 13px; font-weight: 600; color: $navy;'>$name</div>
          <div style='font-size: 12px; color: $textMuted;'>$roleLine</div>
        </td>
      </tr>
    </table>
    $chipsHtml
    $quirkHtml
  </div>
</td>
"@
    }

    while (($wsCells.Count % 3) -ne 0) {
        $wsCells += "<td style='width: 33%; padding: 6px; border: 0;'>&nbsp;</td>"
    }

    $wsRowsHtml = ""
    for ($r = 0; $r -lt $wsCells.Count; $r += 3) {
        $wsRowsHtml += "<tr>" + $wsCells[$r] + $wsCells[$r+1] + $wsCells[$r+2] + "</tr>"
    }

    $wsCardsHtml = "<table border='0' cellpadding='0' cellspacing='0' style='width: 100%; border-collapse: separate; border: 0;'>$wsRowsHtml</table>"
} else {
    $wsCardsHtml = "<p style='font-size: 13px; color: $textMuted; font-style: italic; margin: 0;'>No stakeholders to preview yet.</p>"
}

$onb6Body = @"
<div style='background: #F0F6FB; border-left: 4px solid $navy; border-radius: 6px; padding: 16px 18px; margin-bottom: 18px;'>
  <h4 style='font-size: 13px; font-weight: 600; color: #0F2541; margin: 0 0 8px 0; text-transform: uppercase; letter-spacing: 0.5px;'>Discovery questions for new stakeholders</h4>
  <ul style='list-style: none; padding: 0; margin: 0;'>
    <li style='font-size: 13px; color: $navy; font-style: italic; padding: 3px 0;'>What's the best channel to reach you for non-urgent things?</li>
    <li style='font-size: 13px; color: $navy; font-style: italic; padding: 3px 0;'>When I'm editing a doc you own, do you want suggestions or direct edits?</li>
    <li style='font-size: 13px; color: $navy; font-style: italic; padding: 3px 0;'>What hours do you protect &#8212; and when's your hard stop?</li>
    <li style='font-size: 13px; color: $navy; font-style: italic; padding: 3px 0;'>Do you decide in real time, or do you need to think on it overnight?</li>
    <li style='font-size: 13px; color: $navy; font-style: italic; padding: 3px 0;'>Who else needs to be in the loop when we make a call together?</li>
    <li style='font-size: 13px; color: $navy; font-style: italic; padding: 3px 0;'>What's the fastest way to lose your trust?</li>
  </ul>
</div>
$wsCardsHtml
<p style='font-size: 13px; color: $textMuted; margin: 14px 0 0 0;'>Open each stakeholder to fill in their working-style fields. <a href='$urlStakeholders' style='color: $navy; font-weight: 600; text-decoration: none;'>Open Stakeholders &#8594;</a></p>
"@

$onb6 = New-OnbSection -Num "6" -Title "How to work with each person" `
    -Lead "Knowing each stakeholder's working preferences saves you months of friction. Here are the discovery questions to ask in your first 30 days &#8212; and what each person you've already met has shared so far." `
    -Body $onb6Body
Add-Section -PageName $onbName -SectionIndex 7 -TextBlocks @($onb6)

# --- Section 8: CTA ---
$onbCtaHtml = @"
<div style='background: white; border-radius: 8px; padding: 36px 32px; text-align: center; box-shadow: 0 1.6px 3.6px rgba(0,0,0,0.06);'>
  <h2 style='display: block; margin: 0 0 12px 0; color: $navy; font-weight: 600;'>Ready?</h2>
  <p style='color: $textMuted; margin: 0 0 16px 0;'>When you save your profile, your 30-60-90 plan gets seeded and you'll see your dashboard.</p>
  <a href='$urlTraineeProfilesNew' style='display: inline-block; padding: 16px 36px; background: $navy; color: white; border-radius: 4px; text-decoration: none; font-size: 16px; font-weight: 600;'>Save my profile and get started</a>
</div>
"@
Add-Section -PageName $onbName -SectionIndex 8 -TextBlocks @($onbCtaHtml)

Publish-Page -Name $onbName -Title $onbTitle

# ===========================================================================
# PAGE 3: Offboarding
# ===========================================================================
Write-Host ""
Write-Host "=== PAGE 3: Offboarding ===" -ForegroundColor Cyan

$offName  = "Offboarding"
$offTitle = "Offboarding"

$offStatus = Ensure-Page -Name $offName -Title $offTitle

# Helper for numbered offboarding sections (gold circle).
function New-OffSection {
    param([string]$Num, [string]$Title, [string]$Lead, [string]$Body)
    return @"
<div style='background: white; border-radius: 8px; padding: 28px 32px; box-shadow: 0 1.6px 3.6px rgba(0,0,0,0.06); margin-bottom: 8px;'>
  <div>
    <span style='display: inline-block; width: 28px; height: 28px; background: #FAF1DC; color: $gold; border-radius: 50%; text-align: center; line-height: 28px; font-weight: 600; font-size: 13px; margin-right: 10px;'>$Num</span>
    <h2 style='font-size: 20px; font-weight: 600; display: inline-block; vertical-align: middle; margin: 0; color: $navy;'>$Title</h2>
  </div>
  <div style='font-size: 14px; color: $textMuted; margin: 6px 0 16px 38px;'>$Lead</div>
  <div style='margin-left: 38px;'>$Body</div>
</div>
"@
}

# --- Section 1: Header (gold gradient) ---
$offHeaderHtml = @"
<div style='background: linear-gradient(135deg, $gold 0%, $goldDark 100%); color: white; padding: 56px 32px 48px; text-align: center; border-radius: 8px;'>
  <div style='font-size: 11px; letter-spacing: 2.5px; text-transform: uppercase; opacity: 0.85; margin-bottom: 12px;'>Offboarding</div>
  <h1 style='font-size: 36px; font-weight: 300; margin: 0 0 12px 0; color: white;'>Let's make sure your replacement isn't lost</h1>
  <div style='font-size: 16px; opacity: 0.95; max-width: 640px; margin: 0 auto;'>Small chunks. You don't have to dump everything today. Generate the final cookbook when you're ready.</div>
</div>
"@
Add-Section -PageName $offName -SectionIndex 1 -TextBlocks @($offHeaderHtml)

# --- Section 2: Progress callout (text-only; real % needs PA + roll-up data) ---
$offProgressHtml = @"
<div style='background: #fff4ce; border-left: 4px solid #ffb900; border-radius: 8px; padding: 22px 28px; box-shadow: 0 1.6px 3.6px rgba(0,0,0,0.06);'>
  <div>
    <span style='display: inline-block; width: 28px; height: 28px; background: #FAF1DC; color: $gold; border-radius: 50%; text-align: center; line-height: 28px; font-weight: 700; font-size: 14px; margin-right: 10px;'>!</span>
    <h2 style='font-size: 20px; font-weight: 600; display: inline-block; vertical-align: middle; margin: 0; color: $navy;'>Track your handover progress</h2>
  </div>
  <div style='font-size: 14px; color: $textMuted; margin: 8px 0 14px 38px;'>Live progress requires Power Automate &#8212; for now, use the sections below as a checklist. Each list you fill out (Stakeholders, Meetings, Decisions, Lessons, Acronyms) brings your replacement closer to ready.</div>
  <div style='margin-left: 38px;'>
    <div style='background: $borderLt; height: 10px; border-radius: 5px; overflow: hidden;'>
      <div style='background: linear-gradient(90deg, $gold, #ffb900); width: 35%; height: 100%;'></div>
    </div>
    <div style='font-size: 12px; color: $textMuted; margin-top: 6px; font-style: italic;'>Sample bar &#8212; replace with a real rollup once Power Automate is enabled.</div>
  </div>
</div>
"@
Add-Section -PageName $offName -SectionIndex 2 -TextBlocks @($offProgressHtml)

# --- Section 3: Step 1 - Capture stakeholders ---
$off1 = New-OffSection -Num "1" -Title "Capture your stakeholders" `
    -Lead "The people your replacement needs to know about &#8212; name, role, why they matter." `
    -Body "<p style='font-size: 14px; margin: 0 0 12px 0;'>Add or update entries in the Stakeholders list. Aim for everyone your replacement will reasonably interact with in their first 90 days.</p><p style='margin: 0;'><a href='$urlStakeholdersNew' style='display:inline-block; padding: 10px 20px; background: $gold; color: white; border-radius: 4px; text-decoration: none; font-weight: 600; font-size: 14px;'>Add a stakeholder</a> &#160; <a href='$urlStakeholders' style='color: $navy; font-weight: 600; text-decoration: none;'>Review existing &#8594;</a></p>"
Add-Section -PageName $offName -SectionIndex 3 -TextBlocks @($off1)

# --- Section 4: Step 2 - Document meetings ---
$off2 = New-OffSection -Num "2" -Title "Document your meetings" `
    -Lead "Recurring meetings you attend, with notes on what your role is and where the agendas live." `
    -Body "<p style='font-size: 14px; margin: 0 0 12px 0;'>Each entry should include cadence, your role (lead / participant / co-lead), and where the running agenda or notes doc lives.</p><p style='margin: 0;'><a href='$urlMeetingsNew' style='display:inline-block; padding: 10px 20px; background: $gold; color: white; border-radius: 4px; text-decoration: none; font-weight: 600; font-size: 14px;'>Add a meeting</a> &#160; <a href='$urlMeetings' style='color: $navy; font-weight: 600; text-decoration: none;'>Review existing &#8594;</a></p>"
Add-Section -PageName $offName -SectionIndex 4 -TextBlocks @($off2)

# --- Section 5: Step 3 - Acronyms / decisions / lessons ---
$off3 = New-OffSection -Num "3" -Title "Acronyms, decisions, lessons" `
    -Lead "The things that aren't written down anywhere. Tribal knowledge made structured." `
    -Body @"
<div style='display: grid; grid-template-columns: repeat(3, 1fr); gap: 12px; margin-bottom: 14px;'>
  <a href='$urlAcronymsNew' style='display:block; background: $cardGrey; padding: 14px; border-radius: 6px; text-align: center; text-decoration: none; color: inherit; border: 1px solid $borderLt;'>
    <div style='font-size: 14px; font-weight: 600; color: $gold; text-transform: uppercase; letter-spacing: 1px;'>+ Acronym</div>
    <div style='font-size: 12px; color: $textMuted; margin-top: 4px;'>The jargon you've stopped noticing.</div>
  </a>
  <a href='$urlDecisionsNew' style='display:block; background: $cardGrey; padding: 14px; border-radius: 6px; text-align: center; text-decoration: none; color: inherit; border: 1px solid $borderLt;'>
    <div style='font-size: 14px; font-weight: 600; color: $gold; text-transform: uppercase; letter-spacing: 1px;'>+ Decision</div>
    <div style='font-size: 12px; color: $textMuted; margin-top: 4px;'>What was chosen, when, and why.</div>
  </a>
  <a href='$urlLessonsNew' style='display:block; background: $cardGrey; padding: 14px; border-radius: 6px; text-align: center; text-decoration: none; color: inherit; border: 1px solid $borderLt;'>
    <div style='font-size: 14px; font-weight: 600; color: $gold; text-transform: uppercase; letter-spacing: 1px;'>+ Lesson</div>
    <div style='font-size: 12px; color: $textMuted; margin-top: 4px;'>What you'd do differently next time.</div>
  </a>
</div>
<p style='font-size: 13px; margin: 0;'>Browse existing: <a href='$urlAcronyms' style='color: $navy; text-decoration: none;'>Acronyms</a> &#160;|&#160; <a href='$urlDecisions' style='color: $navy; text-decoration: none;'>Decisions</a> &#160;|&#160; <a href='$urlLessons' style='color: $navy; text-decoration: none;'>Lessons</a></p>
"@
Add-Section -PageName $offName -SectionIndex 5 -TextBlocks @($off3)

# --- Section 6: Step 4 - Quick capture (text-only daily prompt) ---
$off4 = New-OffSection -Num "4" -Title "5-minute Quick Capture" `
    -Lead "Don't have time for full documentation? Answer one quick prompt &#8212; come back tomorrow for another." `
    -Body @"
<div style='background: $cardGrey; padding: 20px; border-radius: 6px; border: 1px solid $borderLt;'>
  <p style='font-size: 14px; font-weight: 600; margin: 0 0 8px 0;'>Today's prompt:</p>
  <p style='font-size: 14px; color: $navy; margin: 0 0 12px 0; font-style: italic;'>"Name one stakeholder your replacement needs to know about. (Name + one sentence on why.)"</p>
  <p style='font-size: 13px; color: $textMuted; margin: 0 0 12px 0;'>The rotating-prompt experience needs Power Automate. Until then, jot the answer straight into Stakeholders / Meetings / Lessons.</p>
  <a href='$urlStakeholdersNew' style='display:inline-block; padding: 10px 22px; background: $gold; color: white; border-radius: 4px; text-decoration: none; font-weight: 600; font-size: 14px;'>Quick-add a stakeholder</a>
</div>
"@
Add-Section -PageName $offName -SectionIndex 6 -TextBlocks @($off4)

# --- Section 7: Step 5 - Working style per stakeholder ---
$off5 = New-OffSection -Num "5" -Title "Capture each stakeholder's working style" `
    -Lead "This is the highest-value handoff content. Your replacement saves weeks of friction if they know how each person prefers to work. ~5 mins per stakeholder." `
    -Body "<p style='font-size: 14px; margin: 0 0 12px 0;'>Open each stakeholder entry and fill in the working-style fields: best channel, edit preference, hours, decision style, and one quirk. The full discovery question set is in <code>design/working-style-discovery.md</code>.</p><p style='margin: 0;'><a href='$urlStakeholders' style='display:inline-block; padding: 10px 22px; background: $gold; color: white; border-radius: 4px; text-decoration: none; font-weight: 600; font-size: 14px;'>Open Stakeholders</a></p>"
Add-Section -PageName $offName -SectionIndex 7 -TextBlocks @($off5)

# --- Section 8: Step 6 - Generate cookbook (gold gradient CTA) ---
$offCookbookHtml = @"
<div style='background: linear-gradient(135deg, $gold 0%, $goldDark 100%); color: white; border-radius: 8px; padding: 36px 32px; text-align: center; box-shadow: 0 1.6px 3.6px rgba(0,0,0,0.06);'>
  <h2 style='display: block; margin: 0 0 12px 0; color: white; font-weight: 600;'>Ready to hand off?</h2>
  <p style='margin: 0 0 16px 0; opacity: 0.95;'>Generate a Word document cookbook from everything you've captured. Hand it to your replacement.</p>
  <p style='font-size: 13px; margin: 0 0 16px 0; opacity: 0.95;'>Today this is a PowerShell script (Power Automate not yet enabled). Run it from a connected PnP session:</p>
  <pre style='display:inline-block; text-align:left; font-family:Consolas,monospace; background: rgba(0,0,0,0.18); padding: 10px 14px; border-radius: 4px; color: white; font-size: 13px; margin: 0 0 16px 0;'>. "C:\Users\cjtucke3\Documents\Personal\Career\MANTLE\scripts\generate-cookbook.ps1"</pre>
  <div>
    <a href='$urlMantleActions' style='display: inline-block; padding: 14px 30px; background: white; color: $goldDark; border-radius: 4px; text-decoration: none; font-size: 15px; font-weight: 600;'>See all MANTLE Actions</a>
  </div>
  <p style='font-size: 12px; opacity: 0.85; margin: 14px 0 0 0;'>We recommend reaching at least 60% capture before generating.</p>
</div>
"@
Add-Section -PageName $offName -SectionIndex 8 -TextBlocks @($offCookbookHtml)

Publish-Page -Name $offName -Title $offTitle

# ===========================================================================
# Quick Launch nav (Onboarding + Offboarding only; Home is site root)
# ===========================================================================
Write-Host ""
Write-Host "=== Quick Launch nav ===" -ForegroundColor Cyan

$onbRel = Resolve-PageUrl -Name $onbName
if (-not $onbRel) { $onbRel = "$siteRoot/SitePages/Onboarding.aspx" }
Add-NavIfMissing -Title $onbName -UrlRelative $onbRel

$offRel = Resolve-PageUrl -Name $offName
if (-not $offRel) { $offRel = "$siteRoot/SitePages/Offboarding.aspx" }
Add-NavIfMissing -Title $offName -UrlRelative $offRel

# ===========================================================================
# Summary
# ===========================================================================
Write-Host ""
Write-Host "==================== SUMMARY ====================" -ForegroundColor Cyan
Write-Host "Home         : $homeStatus  ($homeName)" -ForegroundColor Green
Write-Host "Onboarding   : $onbStatus  ($onbName)" -ForegroundColor Green
Write-Host "Offboarding  : $offStatus  ($offName)" -ForegroundColor Green

$homeUrl = "$siteUrl/SitePages/" + ($homeName.Replace(' ','-')) + ".aspx"
$onbUrl  = "$siteUrl/SitePages/$onbName.aspx"
$offUrl  = "$siteUrl/SitePages/$offName.aspx"
Write-Host ""
Write-Host "URLs:" -ForegroundColor Cyan
Write-Host "  Home       : $homeUrl"
Write-Host "  Onboarding : $onbUrl"
Write-Host "  Offboarding: $offUrl"

if ($failures.Count -gt 0) {
    Write-Host ""
    Write-Host "Failures ($($failures.Count)):" -ForegroundColor Red
    $failures | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
} else {
    Write-Host ""
    Write-Host "Failures     : none" -ForegroundColor Green
}
Write-Host "================================================="
