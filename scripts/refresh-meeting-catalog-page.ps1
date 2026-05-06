# Provision / refresh the "Meeting Catalog" SharePoint page.
# Reads the Meetings list and renders it as a visual, cadence-grouped catalog
# that replaces the raw SharePoint list view as the user-facing browse surface.
#
# Assumes: Connect-PnPOnline -UseWebLogin already run against the MANTLE site.
# Target site: https://nasa.sharepoint.com/teams/PCTransitionSandbox
#
# Cmdlet versions:
#   Targets the legacy SharePointPnPPowerShellOnline module (PS 5.1).
#   Uses: Add-PnPClientSidePage, Add-PnPClientSidePageSection,
#         Add-PnPClientSideText, Set-PnPClientSidePage, Get-PnPClientSidePage,
#         Get-PnPListItem, Add-PnPNavigationNode, Get-PnPNavigationNode.
#   In newer PnP.PowerShell modules these were renamed to
#   Add-PnPPage, Add-PnPPageSection, Add-PnPPageTextPart, Set-PnPPage, Get-PnPPage.
#
# ASCII-only: any Unicode (arrows, em-dashes, ellipsis) is encoded as numeric
# HTML entities (e.g. &#8230; for ellipsis, &#8594; for right arrow).
# Tables, not CSS Grid, for layout (modern SharePoint Text web parts strip Grid).
#
# Idempotent: existing controls are wiped and the page is rewritten on every run.

# ===========================================================================
# Config
# ===========================================================================
$siteUrl  = "https://nasa.sharepoint.com/teams/PCTransitionSandbox"
$siteRoot = "/teams/PCTransitionSandbox"

$pageName  = "Meeting Catalog"
$pageTitle = "Meeting Catalog"

# Brand palette (matches provision-guided-experience-pages.ps1)
$navy      = "#182039"
$navyDark  = "#0F1A2E"
$blue      = "#0693E3"
$gold      = "#E8B86A"
$goldDark  = "#C99A4A"
$bgGrey    = "#F5F7FA"
$cardGrey  = "#FAFBFD"
$textMuted = "#615E5E"
$borderLt  = "#E4E4E4"

# Cadence display order (also drives section ordering)
$cadenceOrder = @("Daily","Weekly","Bi-weekly","Monthly","Quarterly","Annual","Ad hoc")

# Cadence pill palette. Picked from Barrios accents plus tints so the
# rainbow stays on-brand: navy/blue/gold + complementary tints.
# Each entry: bg color, text color.
$cadencePalette = @{
    "Daily"     = @{ bg = "#0693E3"; fg = "#FFFFFF" }   # primary blue
    "Weekly"    = @{ bg = "#182039"; fg = "#FFFFFF" }   # navy
    "Bi-weekly" = @{ bg = "#3F5BB7"; fg = "#FFFFFF" }   # navy/blue blend
    "Monthly"   = @{ bg = "#E8B86A"; fg = "#3D2A0A" }   # gold
    "Quarterly" = @{ bg = "#7A5BA1"; fg = "#FFFFFF" }   # purple (complement)
    "Annual"    = @{ bg = "#C99A4A"; fg = "#FFFFFF" }   # darker gold
    "Ad hoc"    = @{ bg = "#E4E4E4"; fg = "#615E5E" }   # neutral
}

# PC role badge palette (Lead/Co-lead = navy bg; Participant/Observer = gray)
$rolePalette = @{
    "Lead"        = @{ bg = "#182039"; fg = "#FFFFFF" }
    "Co-lead"     = @{ bg = "#182039"; fg = "#FFFFFF" }
    "Participant" = @{ bg = "#E1E1E1"; fg = "#3A3A3A" }
    "Observer"    = @{ bg = "#E1E1E1"; fg = "#3A3A3A" }
    "Optional"    = @{ bg = "#F0EAD8"; fg = "#615E5E" }
}

# Meetings list URL (raw view fallback link in footer)
$urlMeetings    = "$siteUrl/Lists/Meetings/AllItems.aspx"
$urlMeetingsNew = "$siteUrl/Lists/Meetings/NewForm.aspx"
$urlHome        = "$siteUrl/SitePages/MANTLE-Home.aspx"

$failures = @()
$created  = $false
$updated  = $false
$navAdded = $false

# ===========================================================================
# Helpers
# ===========================================================================

function Encode-Html {
    param([string]$Text)
    if ($null -eq $Text) { return "" }
    $s = [string]$Text
    $s = $s.Replace("&","&amp;")
    $s = $s.Replace("<","&lt;")
    $s = $s.Replace(">","&gt;")
    $s = $s.Replace('"',"&quot;")
    $s = $s.Replace("'","&#39;")
    return $s
}

function Truncate-Text {
    param([string]$Text, [int]$Max = 150)
    if ($null -eq $Text) { return @{ short = ""; truncated = $false } }
    $clean = ([string]$Text) -replace "\s+"," "
    $clean = $clean.Trim()
    if ($clean.Length -le $Max) {
        return @{ short = $clean; truncated = $false }
    }
    $cut = $clean.Substring(0, $Max)
    # Try to break at last space for cleaner truncation
    $lastSpace = $cut.LastIndexOf(" ")
    if ($lastSpace -gt ($Max - 30)) { $cut = $cut.Substring(0, $lastSpace) }
    return @{ short = $cut; truncated = $true }
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

function Ensure-Page {
    param([string]$Name, [string]$Title)
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
        $script:created = $true
    } else {
        Write-Host "Page '$Name' already exists. Wiping controls and rewriting." -ForegroundColor Yellow
        try {
            $page = Get-PnPClientSidePage -Identity $Name
            foreach ($ctrl in @($page.Controls)) {
                try {
                    Remove-PnPClientSideComponent -Page $Name -InstanceId $ctrl.InstanceId -Force -ErrorAction Stop | Out-Null
                } catch {
                    # tolerate: cmdlet may not exist or control not removable
                }
            }
        } catch {
            Write-Host "  Could not clear existing controls; new sections will append." -ForegroundColor Yellow
        }
        $script:updated = $true
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
            $script:navAdded = $true
        }
    } catch {
        Write-Host "  FAILED to update Quick Launch for '$Title': $($_.Exception.Message)" -ForegroundColor Red
        $script:failures += "Quick Launch '$Title': $($_.Exception.Message)"
    }
}

# ===========================================================================
# 1. Read the Meetings list
# ===========================================================================
Write-Host ""
Write-Host "=== Reading Meetings list ===" -ForegroundColor Cyan

$allMeetings = @()
try {
    $allMeetings = Get-PnPListItem -List "Meetings" -ErrorAction Stop
    Write-Host "  Loaded $($allMeetings.Count) meetings." -ForegroundColor DarkGray
} catch {
    Write-Host "FAILED to read Meetings list: $($_.Exception.Message)" -ForegroundColor Red
    $failures += "Read Meetings: $($_.Exception.Message)"
    Write-Host "Aborting before page build." -ForegroundColor Red
    return
}

# Group by cadence (preserve order from $cadenceOrder; bucket unknown cadences as 'Ad hoc')
$grouped = @{}
foreach ($cad in $cadenceOrder) { $grouped[$cad] = @() }

foreach ($m in $allMeetings) {
    $cad = $m.FieldValues["Cadence"]
    if (-not $cad -or -not ($cadenceOrder -contains $cad)) {
        $cad = "Ad hoc"
    }
    $grouped[$cad] += ,$m
}

# Tally totals for stat tiles
$totalMeetings = $allMeetings.Count
$totalLead = 0
$totalParticipant = 0
foreach ($m in $allMeetings) {
    $r = $m.FieldValues["PCRole"]
    if ($r -eq "Lead" -or $r -eq "Co-lead") { $totalLead++ }
    if ($r -eq "Participant" -or $r -eq "Observer") { $totalParticipant++ }
}

Write-Host "  Totals: $totalMeetings meetings | Lead/Co-lead: $totalLead | Participant/Observer: $totalParticipant" -ForegroundColor DarkGray

# ===========================================================================
# 2. Ensure / wipe page
# ===========================================================================
Write-Host ""
Write-Host "=== Page: $pageName ===" -ForegroundColor Cyan
Ensure-Page -Name $pageName -Title $pageTitle

# ===========================================================================
# 3. Build sections
# ===========================================================================
$sectionIndex = 1

# --- Section: Header (navy gradient) ---
$headerHtml = @"
<div style='background: linear-gradient(135deg, $navy 0%, $blue 100%); color: white; padding: 56px 32px 48px; text-align: center; border-radius: 8px;'>
  <div style='font-size: 11px; letter-spacing: 2.5px; text-transform: uppercase; opacity: 0.85; margin-bottom: 12px;'>MANTLE</div>
  <h1 style='font-size: 36px; font-weight: 300; margin: 0 0 12px 0; color: white;'>Meeting Catalog</h1>
  <div style='font-size: 16px; opacity: 0.95; max-width: 640px; margin: 0 auto;'>Your recurring meetings, by cadence.</div>
</div>
"@
Add-Section -PageName $pageName -SectionIndex $sectionIndex -TextBlocks @($headerHtml)
$sectionIndex++

# --- Section: Stat tiles ---
$statsHtml = @"
<table border='0' style='width: 100%; max-width: 880px; margin: 16px auto 0; border-collapse: separate; border-spacing: 12px; border: 0;' cellpadding='0' cellspacing='12'>
  <tr>
    <td style='width: 33%; vertical-align: top; padding: 0; border: 0;'>
      <div style='background: $cardGrey; border-radius: 8px; padding: 22px 16px; text-align: center; border-top: 3px solid $navy;'>
        <div style='font-size: 32px; font-weight: 700; color: $navy; line-height: 1;'>$totalMeetings</div>
        <div style='font-size: 11px; color: $textMuted; text-transform: uppercase; letter-spacing: 1.2px; margin-top: 8px;'>Meetings tracked</div>
      </div>
    </td>
    <td style='width: 33%; vertical-align: top; padding: 0; border: 0;'>
      <div style='background: $cardGrey; border-radius: 8px; padding: 22px 16px; text-align: center; border-top: 3px solid $blue;'>
        <div style='font-size: 32px; font-weight: 700; color: $navy; line-height: 1;'>$totalLead</div>
        <div style='font-size: 11px; color: $textMuted; text-transform: uppercase; letter-spacing: 1.2px; margin-top: 8px;'>You lead / co-lead</div>
      </div>
    </td>
    <td style='width: 33%; vertical-align: top; padding: 0; border: 0;'>
      <div style='background: $cardGrey; border-radius: 8px; padding: 22px 16px; text-align: center; border-top: 3px solid $gold;'>
        <div style='font-size: 32px; font-weight: 700; color: $navy; line-height: 1;'>$totalParticipant</div>
        <div style='font-size: 11px; color: $textMuted; text-transform: uppercase; letter-spacing: 1.2px; margin-top: 8px;'>You participate / observe</div>
      </div>
    </td>
  </tr>
</table>
"@
Add-Section -PageName $pageName -SectionIndex $sectionIndex -TextBlocks @($statsHtml)
$sectionIndex++

# --- Sections: One per cadence group (only cadences with meetings) ---
foreach ($cad in $cadenceOrder) {
    $items = $grouped[$cad]
    if (-not $items -or $items.Count -eq 0) { continue }

    $cadPalette = $cadencePalette[$cad]
    if (-not $cadPalette) { $cadPalette = @{ bg = "#E4E4E4"; fg = "#615E5E" } }

    $cadEnc = Encode-Html $cad
    $count  = $items.Count

    # Sort meetings within group by Title for predictable display
    $sortedItems = $items | Sort-Object @{ Expression = { $_.FieldValues["Title"] } }

    # Build rows
    $rowsHtml = ""
    foreach ($m in $sortedItems) {
        $fv = $m.FieldValues
        $title = $fv["Title"]
        if (-not $title) { $title = "(untitled meeting)" }
        $titleEnc = Encode-Html $title

        $dayTime = $fv["DayAndTime"]
        if ($dayTime) {
            $dayTimeHtml = "<div style='font-size: 12px; color: $textMuted; margin-top: 2px;'>" + (Encode-Html $dayTime) + "</div>"
        } else {
            $dayTimeHtml = "<div style='font-size: 12px; color: $textMuted; margin-top: 2px; font-style: italic;'>Day &amp; time not set</div>"
        }

        # PC role badge
        $role = $fv["PCRole"]
        if ($role) {
            $rp = $rolePalette[$role]
            if (-not $rp) { $rp = @{ bg = "#E1E1E1"; fg = "#3A3A3A" } }
            $roleEnc = Encode-Html $role
            $roleHtml = "<span style='display: inline-block; font-size: 11px; padding: 3px 10px; border-radius: 12px; background: " + $rp.bg + "; color: " + $rp.fg + "; font-weight: 600; text-transform: uppercase; letter-spacing: 0.5px; white-space: nowrap;'>" + $roleEnc + "</span>"
        } else {
            $roleHtml = "<span style='display: inline-block; font-size: 11px; padding: 3px 10px; border-radius: 12px; background: #F5F5F5; color: #999999; font-weight: 600; text-transform: uppercase; letter-spacing: 0.5px; white-space: nowrap; font-style: italic;'>no role</span>"
        }

        # Cadence pill (per row)
        $pillHtml = "<span style='display: inline-block; font-size: 11px; padding: 4px 10px; border-radius: 4px; background: " + $cadPalette.bg + "; color: " + $cadPalette.fg + "; font-weight: 600; text-transform: uppercase; letter-spacing: 0.5px; white-space: nowrap; text-align: center; min-width: 80px;'>" + $cadEnc + "</span>"

        # PC responsibilities truncation
        $resp = $fv["PCResponsibilities"]
        if ($resp) {
            $tr = Truncate-Text -Text $resp -Max 150
            $respEnc = Encode-Html $tr.short
            if ($tr.truncated) {
                $respHtml = "<div style='font-size: 13px; color: $navy; margin-top: 8px; line-height: 1.5;'>" + $respEnc + "&#8230; <a href='" + $urlMeetings + "' style='color: $blue; text-decoration: none; font-weight: 600;'>see details &#8594;</a></div>"
            } else {
                $respHtml = "<div style='font-size: 13px; color: $navy; margin-top: 8px; line-height: 1.5;'>" + $respEnc + "</div>"
            }
        } else {
            $respHtml = "<div style='font-size: 12px; color: $textMuted; margin-top: 8px; font-style: italic;'>No PC responsibilities documented yet. <a href='" + $urlMeetings + "' style='color: $blue; text-decoration: none; font-weight: 600;'>Add &#8594;</a></div>"
        }

        $rowsHtml += @"
<tr>
  <td style='width: 110px; padding: 14px 12px 14px 0; vertical-align: top; border-bottom: 1px solid $bgGrey;'>$pillHtml</td>
  <td style='padding: 14px 12px; vertical-align: top; border-bottom: 1px solid $bgGrey;'>
    <div style='font-size: 14px; font-weight: 600; color: $navy;'>$titleEnc</div>
    $dayTimeHtml
    $respHtml
  </td>
  <td style='width: 120px; padding: 14px 0 14px 12px; vertical-align: top; text-align: right; border-bottom: 1px solid $bgGrey;'>$roleHtml</td>
</tr>
"@
    }

    $cadenceLabelLower = $cad.ToLower()
    $sectionHtml = @"
<div style='background: white; border-radius: 8px; padding: 24px 28px; box-shadow: 0 1.6px 3.6px rgba(0,0,0,0.06); margin-bottom: 8px;'>
  <div style='display: block; margin-bottom: 8px; padding-bottom: 12px; border-bottom: 2px solid $bgGrey;'>
    <span style='display: inline-block; width: 12px; height: 12px; border-radius: 50%; background: $($cadPalette.bg); vertical-align: middle; margin-right: 10px;'></span>
    <h2 style='display: inline-block; vertical-align: middle; margin: 0; font-size: 20px; font-weight: 600; color: $navy;'>$cadEnc meetings <span style='color: $textMuted; font-weight: 400; font-size: 16px;'>($count)</span></h2>
  </div>
  <table border='0' style='width: 100%; border-collapse: collapse; border: 0;' cellpadding='0' cellspacing='0'>
    $rowsHtml
  </table>
</div>
"@
    Add-Section -PageName $pageName -SectionIndex $sectionIndex -TextBlocks @($sectionHtml)
    $sectionIndex++
}

# Empty-state section if nothing was rendered
$renderedAny = $false
foreach ($cad in $cadenceOrder) {
    if ($grouped[$cad] -and $grouped[$cad].Count -gt 0) { $renderedAny = $true; break }
}
if (-not $renderedAny) {
    $emptyHtml = @"
<div style='background: white; border-radius: 8px; padding: 36px 28px; box-shadow: 0 1.6px 3.6px rgba(0,0,0,0.06); text-align: center;'>
  <div style='font-size: 16px; color: $textMuted; margin-bottom: 16px;'>No meetings have been added to the Meetings list yet.</div>
  <a href='$urlMeetingsNew' style='display: inline-block; padding: 10px 22px; background: $navy; color: white; border-radius: 4px; text-decoration: none; font-weight: 600; font-size: 14px;'>Add your first meeting</a>
</div>
"@
    Add-Section -PageName $pageName -SectionIndex $sectionIndex -TextBlocks @($emptyHtml)
    $sectionIndex++
}

# --- Footer section ---
$footerHtml = @"
<div style='max-width: 880px; margin: 24px auto 40px; padding: 20px 24px; background: $cardGrey; border-radius: 8px; border-left: 4px solid $navy; font-size: 13px; color: $textMuted; text-align: center;'>
  <div style='margin-bottom: 8px;'>This catalog is generated from the <strong style='color: $navy;'>Meetings</strong> list. To add, edit, or remove meetings, edit the list directly.</div>
  <div>
    <a href='$urlHome' style='color: $navy; text-decoration: none; margin: 0 10px; font-weight: 600;'>&#8592; Home</a>
    <span>&#183;</span>
    <a href='$urlMeetings' style='color: $navy; text-decoration: none; margin: 0 10px; font-weight: 600;'>Open the raw Meetings list</a>
    <span>&#183;</span>
    <a href='$urlMeetingsNew' style='color: $navy; text-decoration: none; margin: 0 10px; font-weight: 600;'>+ Add a meeting</a>
  </div>
</div>
"@
Add-Section -PageName $pageName -SectionIndex $sectionIndex -TextBlocks @($footerHtml)

# ===========================================================================
# 4. Publish
# ===========================================================================
Write-Host ""
Write-Host "=== Publishing page ===" -ForegroundColor Cyan
Publish-Page -Name $pageName -Title $pageTitle

# ===========================================================================
# 5. Resolve URL + Quick Launch nav
# ===========================================================================
$pageUrlRelative = "$siteRoot/SitePages/" + ($pageName.Replace(' ','-')) + ".aspx"
$resolved = Resolve-PageUrl -Name $pageName
if ($resolved) {
    $pageUrlRelative = $resolved
    Write-Host "Resolved page URL: $pageUrlRelative" -ForegroundColor Cyan
} else {
    Write-Host "Could not resolve actual page URL; falling back to assumed slug ($pageUrlRelative)." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Quick Launch nav ===" -ForegroundColor Cyan
Add-NavIfMissing -Title $pageName -UrlRelative $pageUrlRelative

# ===========================================================================
# 6. Summary
# ===========================================================================
$encodedRelative = $pageUrlRelative -replace ' ', '%20'
$publishedUrl = "https://nasa.sharepoint.com$encodedRelative"

Write-Host ""
Write-Host "==================== SUMMARY ====================" -ForegroundColor Cyan
if ($created)  { Write-Host "Page created : $pageName" -ForegroundColor Green }
if ($updated)  { Write-Host "Page updated : $pageName (rewrote sections)" -ForegroundColor Green }
if ($navAdded) { Write-Host "Quick Launch : added" -ForegroundColor Green } else { Write-Host "Quick Launch : already present or skipped" -ForegroundColor Yellow }
Write-Host "Meetings     : $totalMeetings" -ForegroundColor Cyan
Write-Host "  Lead/co    : $totalLead" -ForegroundColor Cyan
Write-Host "  Participant: $totalParticipant" -ForegroundColor Cyan
foreach ($cad in $cadenceOrder) {
    $c = 0
    if ($grouped[$cad]) { $c = $grouped[$cad].Count }
    if ($c -gt 0) {
        Write-Host ("  {0,-10} : {1}" -f $cad, $c) -ForegroundColor DarkGray
    }
}
Write-Host "URL          : $publishedUrl" -ForegroundColor Cyan
if ($failures.Count -gt 0) {
    Write-Host "Failures ($($failures.Count)):" -ForegroundColor Red
    $failures | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
} else {
    Write-Host "Failures     : none" -ForegroundColor Green
}
Write-Host "================================================="
