# Refresh the "Team Directory" SharePoint page for MANTLE.
# Reads the Stakeholders list and renders a 3-column card grid keyed off
# Title (Contact Name), Role, OrgOrTeam, Influence, plus working-style chips
# from PreferredChannel / EditingPreference / WorkingHours.
#
# Assumes: Connect-PnPOnline -UseWebLogin already run against the MANTLE site.
# Target site: https://nasa.sharepoint.com/teams/PCTransitionSandbox
#
# Cmdlet versions: legacy SharePointPnPPowerShellOnline (PS 5.1).
#   Uses: Add-PnPClientSidePage, Add-PnPClientSidePageSection,
#         Add-PnPClientSideText, Set-PnPClientSidePage, Get-PnPClientSidePage,
#         Get-PnPListItem, Add-PnPNavigationNode, Get-PnPNavigationNode.
#
# ASCII-only literals: Unicode rendered via numeric HTML entities.
# Layout uses HTML <table> (CSS Grid is stripped by SharePoint Text web parts).

$siteUrl  = "https://nasa.sharepoint.com/teams/PCTransitionSandbox"
$siteRoot = "/teams/PCTransitionSandbox"

# Brand palette
$navy      = "#182039"
$navyDark  = "#0F1A2E"
$blue      = "#0693E3"
$gold      = "#E8B86A"
$bgGrey    = "#F5F7FA"
$cardGrey  = "#FAFBFD"
$textMuted = "#615E5E"
$borderLt  = "#E4E4E4"

$urlStakeholders    = "$siteUrl/Lists/Stakeholders/AllItems.aspx"
$urlStakeholdersNew = "$siteUrl/Lists/Stakeholders/NewForm.aspx"
$urlMantleHome      = "$siteUrl/SitePages/MANTLE-Home.aspx"

$pageName  = "Team Directory"
$pageTitle = "Team Directory"

$failures = @()

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

function Get-Initials {
    param([string]$Name)
    if ([string]::IsNullOrWhiteSpace($Name)) { return "?" }
    # Force array context — single-element -split collapses to a string in PS,
    # which then makes $parts[0] return a Char instead of a string.
    [array]$parts = $Name.Trim() -split '\s+'
    if ($parts.Count -eq 1) {
        $c = ([string]$parts[0]).Substring(0,1).ToUpper()
        return $c
    }
    $first = ([string]$parts[0]).Substring(0,1).ToUpper()
    $last  = ([string]$parts[$parts.Count - 1]).Substring(0,1).ToUpper()
    return "$first$last"
}

function HtmlEncode {
    param([string]$Text)
    if ($null -eq $Text) { return "" }
    $t = $Text
    $t = $t -replace '&', '&amp;'
    $t = $t -replace '<', '&lt;'
    $t = $t -replace '>', '&gt;'
    $t = $t -replace '"', '&quot;'
    $t = $t -replace "'", '&#39;'
    return $t
}

function Get-FieldString {
    param($Item, [string]$FieldName)
    try {
        $v = $Item.FieldValues[$FieldName]
        if ($null -eq $v) { return "" }
        # Choice fields can come back as strings; lookup/multilookup as arrays.
        if ($v -is [Array]) { return ($v -join ", ") }
        return [string]$v
    } catch {
        return ""
    }
}

function Get-FieldBool {
    param($Item, [string]$FieldName)
    try {
        $v = $Item.FieldValues[$FieldName]
        if ($null -eq $v) { return $false }
        if ($v -is [bool]) { return $v }
        $s = [string]$v
        return ($s -eq "True" -or $s -eq "true" -or $s -eq "1" -or $s -eq "Yes")
    } catch {
        return $false
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
        return "created"
    } else {
        Write-Host "Page '$Name' already exists. Wiping controls and rewriting." -ForegroundColor Yellow
        try {
            $page = Get-PnPClientSidePage -Identity $Name
            foreach ($ctrl in @($page.Controls)) {
                try {
                    Remove-PnPClientSideComponent -Page $Name -InstanceId $ctrl.InstanceId -Force -ErrorAction Stop | Out-Null
                } catch {
                    # tolerate
                }
            }
        } catch {
            Write-Host "  Could not clear existing controls; new sections will append." -ForegroundColor Yellow
        }
        return "updated"
    }
}

function Add-Section {
    param([string]$PageName, [int]$SectionIndex, [string[]]$TextBlocks)
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

# ---------------------------------------------------------------------------
# 1. Pull stakeholders, filter, sort
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "=== Reading Stakeholders list ===" -ForegroundColor Cyan

$rawItems = @()
try {
    $rawItems = Get-PnPListItem -List "Stakeholders" -ErrorAction Stop
    Write-Host "  Pulled $($rawItems.Count) stakeholder rows." -ForegroundColor Green
} catch {
    Write-Host "  FAILED to read Stakeholders list: $($_.Exception.Message)" -ForegroundColor Red
    $failures += "Read Stakeholders: $($_.Exception.Message)"
    Write-Host "Aborting." -ForegroundColor Red
    return
}

# Build plain objects, drop sensitive rows
$stakeholders = @()
$sensitiveCount = 0
foreach ($it in $rawItems) {
    $isSensitive = Get-FieldBool -Item $it -FieldName "Sensitive"
    if ($isSensitive) { $sensitiveCount++; continue }
    $title = Get-FieldString -Item $it -FieldName "Title"
    if ([string]::IsNullOrWhiteSpace($title)) { continue }
    $stakeholders += [pscustomobject]@{
        Title             = $title
        Role              = Get-FieldString -Item $it -FieldName "Role"
        OrgOrTeam         = Get-FieldString -Item $it -FieldName "OrgOrTeam"
        Influence         = Get-FieldString -Item $it -FieldName "Influence"
        Interest          = Get-FieldString -Item $it -FieldName "Interest"
        RelationshipStatus= Get-FieldString -Item $it -FieldName "RelationshipStatus"
        Cadence           = Get-FieldString -Item $it -FieldName "Cadence"
        PreferredChannel  = Get-FieldString -Item $it -FieldName "PreferredChannel"
        EditingPreference = Get-FieldString -Item $it -FieldName "EditingPreference"
        NoticePreference  = Get-FieldString -Item $it -FieldName "NoticePreference"
        WorkingHours      = Get-FieldString -Item $it -FieldName "WorkingHours"
        Quirks            = Get-FieldString -Item $it -FieldName "Quirks"
    }
}

# Sort alphabetically by Title (Contact Name). Last-name sort is more useful
# for a directory, but the field is a single free-text "Contact Name" string,
# so we sort by the trimmed Title as the user typed it. A future enhancement
# could compute a sort key from the last token.
$stakeholders = $stakeholders | Sort-Object -Property @{Expression={$_.Title.Trim()}}

$total = $stakeholders.Count
Write-Host "  Visible stakeholders: $total (omitted $sensitiveCount sensitive)" -ForegroundColor Green

# Influence breakdown (case-insensitive)
$infHigh = 0; $infMed = 0; $infLow = 0; $infOther = 0
foreach ($s in $stakeholders) {
    switch -Regex ($s.Influence.Trim().ToLower()) {
        '^high$'   { $infHigh++; break }
        '^medium$' { $infMed++;  break }
        '^low$'    { $infLow++;  break }
        default {
            if (-not [string]::IsNullOrWhiteSpace($s.Influence)) { $infOther++ }
        }
    }
}

# ---------------------------------------------------------------------------
# 2. Build alphabet jump links (for long directories)
# ---------------------------------------------------------------------------
$letters = @()
foreach ($s in $stakeholders) {
    $first = $s.Title.Trim().Substring(0,1).ToUpper()
    if ($first -match '[A-Z]') {
        if ($letters -notcontains $first) { $letters += $first }
    }
}
$letters = $letters | Sort-Object

$jumpHtml = ""
if ($letters.Count -gt 1) {
    $jumpParts = @()
    foreach ($L in $letters) {
        $jumpParts += "<a href='#tdletter-$L' style='display:inline-block; min-width:24px; padding:4px 8px; margin:2px; background:$cardGrey; color:$navy; border:1px solid $borderLt; border-radius:4px; text-decoration:none; font-weight:600; font-size:13px;'>$L</a>"
    }
    $jumpHtml = "<div style='text-align:center; padding:8px 16px 16px;'>" + ($jumpParts -join " ") + "</div>"
}

# ---------------------------------------------------------------------------
# 3. Build the card grid as a 3-column <table>
# ---------------------------------------------------------------------------

function New-Card {
    param($S)
    $name        = HtmlEncode $S.Title
    $role        = HtmlEncode $S.Role
    $org         = HtmlEncode $S.OrgOrTeam
    $initials    = Get-Initials -Name $S.Title

    # Role + Org line
    $roleLine = ""
    if ($role -and $org) {
        $roleLine = "$role &#183; $org"
    } elseif ($role) {
        $roleLine = $role
    } elseif ($org) {
        $roleLine = $org
    } else {
        $roleLine = "&#160;"
    }

    # Working-style chips
    $chips = @()
    if (-not [string]::IsNullOrWhiteSpace($S.PreferredChannel)) {
        $chips += "<span style='display:inline-block; font-size:11px; background:white; border:1px solid $borderLt; border-radius:12px; padding:2px 8px; color:$navy; margin:2px 3px 0 0; white-space:nowrap;'>" + (HtmlEncode $S.PreferredChannel) + "</span>"
    }
    if (-not [string]::IsNullOrWhiteSpace($S.EditingPreference)) {
        $chips += "<span style='display:inline-block; font-size:11px; background:white; border:1px solid $borderLt; border-radius:12px; padding:2px 8px; color:$navy; margin:2px 3px 0 0; white-space:nowrap;'>" + (HtmlEncode $S.EditingPreference) + "</span>"
    }
    if (-not [string]::IsNullOrWhiteSpace($S.WorkingHours)) {
        $chips += "<span style='display:inline-block; font-size:11px; background:white; border:1px solid $borderLt; border-radius:12px; padding:2px 8px; color:$navy; margin:2px 3px 0 0; white-space:nowrap;'>" + (HtmlEncode $S.WorkingHours) + "</span>"
    }
    $chipsHtml = ""
    if ($chips.Count -gt 0) {
        $chipsHtml = "<div style='margin-top:8px; line-height:1.6;'>" + ($chips -join "") + "</div>"
    }

    return @"
<div style='background:$cardGrey; padding:14px; border-radius:8px; border:1px solid $borderLt; height:100%;'>
  <table border='0' cellpadding='0' cellspacing='0' style='width:100%; border-collapse:collapse; border:0;'>
    <tr>
      <td valign='top' style='width:48px; padding:0 12px 0 0; border:0;'>
        <div style='width:40px; height:40px; border-radius:50%; background:linear-gradient(135deg, $blue, $navy); color:white; text-align:center; line-height:40px; font-weight:700; font-size:14px; font-family:Segoe UI,Arial,sans-serif;'>$initials</div>
      </td>
      <td valign='top' style='padding:0; border:0;'>
        <div style='font-weight:600; font-size:14px; color:$navy; line-height:1.3;'>$name</div>
        <div style='color:$textMuted; font-size:12px; margin-top:2px; line-height:1.4;'>$roleLine</div>
        $chipsHtml
      </td>
    </tr>
  </table>
</div>
"@
}

# Build rows of 3 cards each, with an alphabet anchor on the first card of
# each new starting letter. Many cards are fine in one HTML blob; the page
# will scroll. The alphabet jump links above provide quick navigation.
$rowsHtml = New-Object System.Text.StringBuilder
$null = $rowsHtml.Append("<table border='0' cellpadding='0' cellspacing='10' style='width:100%; border-collapse:separate; border-spacing:10px; border:0;'>")

$lastLetter = ""
$col = 0
$inRow = $false
for ($i = 0; $i -lt $stakeholders.Count; $i++) {
    $s = $stakeholders[$i]
    $first = $s.Title.Trim().Substring(0,1).ToUpper()
    $anchor = ""
    if ($first -match '[A-Z]' -and $first -ne $lastLetter) {
        $anchor = "<a id='tdletter-$first' style='position:relative; top:-60px;'></a>"
        $lastLetter = $first
    }

    if ($col -eq 0) {
        $null = $rowsHtml.Append("<tr>")
        $inRow = $true
    }

    $cardHtml = New-Card -S $s
    $null = $rowsHtml.Append("<td valign='top' width='33%' style='width:33%; vertical-align:top; padding:0; border:0;'>$anchor$cardHtml</td>")
    $col++

    if ($col -eq 3) {
        $null = $rowsHtml.Append("</tr>")
        $inRow = $false
        $col = 0
    }
}
# Close any partial row with empty cells so layout stays even
if ($inRow) {
    while ($col -lt 3) {
        $null = $rowsHtml.Append("<td valign='top' width='33%' style='width:33%; vertical-align:top; padding:0; border:0;'>&#160;</td>")
        $col++
    }
    $null = $rowsHtml.Append("</tr>")
}
$null = $rowsHtml.Append("</table>")

$gridHtml = $rowsHtml.ToString()

# ---------------------------------------------------------------------------
# 4. Build static HTML blocks
# ---------------------------------------------------------------------------

# Header (navy gradient)
$headerHtml = @"
<div style='background: linear-gradient(135deg, $navy 0%, $blue 100%); color: white; padding: 56px 32px 48px; text-align: center; border-radius: 8px;'>
  <div style='font-size: 11px; letter-spacing: 2.5px; text-transform: uppercase; opacity: 0.85; margin-bottom: 12px;'>MANTLE</div>
  <h1 style='font-size: 36px; font-weight: 300; margin: 0 0 12px 0; color: white;'>Team Directory</h1>
  <div style='font-size: 16px; opacity: 0.95; max-width: 640px; margin: 0 auto;'>Your stakeholders, at a glance.</div>
</div>
"@

# Stat tiles row (total + influence breakdown). Use a table for layout.
$infOtherTile = ""
if ($infOther -gt 0) {
    $infOtherTile = "<td valign='top' width='25%' style='width:25%; vertical-align:top; padding:0; border:0;'><div style='background:$cardGrey; padding:18px 14px; border-radius:8px; border:1px solid $borderLt; text-align:center;'><div style='font-size:28px; font-weight:700; color:$navy; line-height:1.1;'>$infOther</div><div style='font-size:11px; color:$textMuted; text-transform:uppercase; letter-spacing:1px; margin-top:6px;'>Other / Unset</div></div></td>"
} else {
    $infOtherTile = "<td valign='top' width='25%' style='width:25%; vertical-align:top; padding:0; border:0;'>&#160;</td>"
}

$statsHtml = @"
<table border='0' cellpadding='0' cellspacing='10' style='width:100%; border-collapse:separate; border-spacing:10px; border:0;'>
  <tr>
    <td valign='top' width='25%' style='width:25%; vertical-align:top; padding:0; border:0;'>
      <div style='background:$cardGrey; padding:18px 14px; border-radius:8px; border:1px solid $borderLt; text-align:center;'>
        <div style='font-size:28px; font-weight:700; color:$navy; line-height:1.1;'>$total</div>
        <div style='font-size:11px; color:$textMuted; text-transform:uppercase; letter-spacing:1px; margin-top:6px;'>Total stakeholders</div>
      </div>
    </td>
    <td valign='top' width='25%' style='width:25%; vertical-align:top; padding:0; border:0;'>
      <div style='background:$cardGrey; padding:18px 14px; border-radius:8px; border:1px solid $borderLt; border-top:3px solid $navy; text-align:center;'>
        <div style='font-size:28px; font-weight:700; color:$navy; line-height:1.1;'>$infHigh</div>
        <div style='font-size:11px; color:$textMuted; text-transform:uppercase; letter-spacing:1px; margin-top:6px;'>High influence</div>
      </div>
    </td>
    <td valign='top' width='25%' style='width:25%; vertical-align:top; padding:0; border:0;'>
      <div style='background:$cardGrey; padding:18px 14px; border-radius:8px; border:1px solid $borderLt; border-top:3px solid $blue; text-align:center;'>
        <div style='font-size:28px; font-weight:700; color:$navy; line-height:1.1;'>$infMed</div>
        <div style='font-size:11px; color:$textMuted; text-transform:uppercase; letter-spacing:1px; margin-top:6px;'>Medium influence</div>
      </div>
    </td>
    <td valign='top' width='25%' style='width:25%; vertical-align:top; padding:0; border:0;'>
      <div style='background:$cardGrey; padding:18px 14px; border-radius:8px; border:1px solid $borderLt; border-top:3px solid $gold; text-align:center;'>
        <div style='font-size:28px; font-weight:700; color:$navy; line-height:1.1;'>$infLow</div>
        <div style='font-size:11px; color:$textMuted; text-transform:uppercase; letter-spacing:1px; margin-top:6px;'>Low influence</div>
      </div>
    </td>
  </tr>
</table>
"@

# By-Influence summary line
$byInfluenceLine = "By Influence: $infHigh High, $infMed Medium, $infLow Low"
if ($infOther -gt 0) { $byInfluenceLine += ", $infOther Other" }
$summaryLineHtml = "<p style='text-align:center; font-size:13px; color:$textMuted; margin:8px 0 0 0;'>$byInfluenceLine &#160;&#183;&#160; $sensitiveCount sensitive entries hidden</p>"

# Footer
$footerHtml = @"
<div style='background:white; border-top:3px solid $navy; padding:24px 28px; border-radius:8px; text-align:center; box-shadow: 0 1.6px 3.6px rgba(0,0,0,0.06);'>
  <p style='margin:0 0 12px 0; font-size:13px; color:$textMuted;'>Need to update someone or add a new stakeholder? Edit the underlying list.</p>
  <a href='$urlMantleHome' style='display:inline-block; padding:10px 22px; background:$navy; color:white; border-radius:4px; text-decoration:none; font-weight:600; font-size:14px; margin:4px;'>&#8592; Back to MANTLE Home</a>
  <a href='$urlStakeholders' style='display:inline-block; padding:10px 22px; background:white; color:$navy; border:1px solid $navy; border-radius:4px; text-decoration:none; font-weight:600; font-size:14px; margin:4px;'>Edit Stakeholders list</a>
  <a href='$urlStakeholdersNew' style='display:inline-block; padding:10px 22px; background:$gold; color:white; border-radius:4px; text-decoration:none; font-weight:600; font-size:14px; margin:4px;'>+ Add stakeholder</a>
</div>
"@

# Empty-state fallback
if ($total -eq 0) {
    $gridHtml = "<div style='background:$cardGrey; border:1px dashed $borderLt; border-radius:8px; padding:40px 28px; text-align:center; color:$textMuted; font-size:14px;'>No stakeholders are visible yet. Add your first one to populate the directory.</div>"
    $jumpHtml = ""
}

# ---------------------------------------------------------------------------
# 5. Provision the page
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "=== Page: $pageName ===" -ForegroundColor Cyan

$pageStatus = Ensure-Page -Name $pageName -Title $pageTitle

# Section 1: Header
Add-Section -PageName $pageName -SectionIndex 1 -TextBlocks @($headerHtml)

# Section 2: Stat tiles + summary line + alphabet jump
$section2Blocks = @($statsHtml, $summaryLineHtml)
if ($jumpHtml) { $section2Blocks += $jumpHtml }
Add-Section -PageName $pageName -SectionIndex 2 -TextBlocks $section2Blocks

# Section 3: Card grid
Add-Section -PageName $pageName -SectionIndex 3 -TextBlocks @($gridHtml)

# Section 4: Footer
Add-Section -PageName $pageName -SectionIndex 4 -TextBlocks @($footerHtml)

Publish-Page -Name $pageName -Title $pageTitle

# ---------------------------------------------------------------------------
# 6. Add to Quick Launch
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "=== Quick Launch nav ===" -ForegroundColor Cyan
$rel = Resolve-PageUrl -Name $pageName
if (-not $rel) { $rel = "$siteRoot/SitePages/" + ($pageName.Replace(' ','-')) + ".aspx" }
Add-NavIfMissing -Title $pageName -UrlRelative $rel

# ---------------------------------------------------------------------------
# 7. Summary
# ---------------------------------------------------------------------------
$encodedRel  = $rel -replace ' ', '%20'
$publishedUrl = "https://nasa.sharepoint.com$encodedRel"

Write-Host ""
Write-Host "==================== SUMMARY ====================" -ForegroundColor Cyan
Write-Host "Page         : $pageStatus  ($pageName)" -ForegroundColor Green
Write-Host "Stakeholders : $total visible, $sensitiveCount sensitive omitted" -ForegroundColor Green
Write-Host "By Influence : $infHigh High / $infMed Medium / $infLow Low / $infOther Other" -ForegroundColor Green
Write-Host "URL          : $publishedUrl" -ForegroundColor Cyan

if ($failures.Count -gt 0) {
    Write-Host ""
    Write-Host "Failures ($($failures.Count)):" -ForegroundColor Red
    $failures | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
} else {
    Write-Host ""
    Write-Host "Failures     : none" -ForegroundColor Green
}
Write-Host "================================================="
