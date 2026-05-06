# Refresh the "Acronym Glossary" SharePoint page from the Acronyms list.
# Assumes: Connect-PnPOnline -UseWebLogin already run against the KITCHEN site.
# Target site: https://nasa.sharepoint.com/teams/PCTransitionSandbox
#
# Cmdlet versions:
#   Targets the legacy SharePointPnPPowerShellOnline module (PS 5.1).
#   Uses: Add-PnPClientSidePage, Add-PnPClientSidePageSection,
#         Add-PnPClientSideText, Set-PnPClientSidePage, Get-PnPClientSidePage,
#         Get-PnPListItem, Add-PnPNavigationNode, Get-PnPNavigationNode.
#
# What it does:
#   1. Reads ALL Acronyms from the Acronyms list
#   2. Groups by first letter (A..Z, plus "Other" for non-letter starts)
#   3. Sorts alphabetically within each group
#   4. Generates a SharePoint page with:
#        - Navy gradient header ("Acronym Glossary" + count subtitle)
#        - Alphabet jump bar with anchor links to each section
#        - One Text web part per letter section (smaller payloads)
#        - Two-column table per section, each row = one acronym entry
#   5. Adds "Acronym Glossary" to QuickLaunch nav
#   6. Idempotent: wipes and rebuilds existing page; nav add is no-op if present
#
# ASCII-only: any Unicode (arrows, bullets) encoded as numeric HTML entities.
# All layout is <table>-based; CSS Grid is unreliable inside Text web parts.

$siteUrl  = "https://nasa.sharepoint.com/teams/PCTransitionSandbox"
$siteRoot = "/teams/PCTransitionSandbox"

$pageName  = "Acronym Glossary"
$pageTitle = "Acronym Glossary"

# Brand palette (matches provision-guided-experience-pages.ps1)
$navy      = "#182039"
$navyDark  = "#0F1A2E"
$blue      = "#0693E3"
$gold      = "#E8B86A"
$purple    = "#6B46C1"
$grey      = "#615E5E"
$bgGrey    = "#F5F7FA"
$cardGrey  = "#FAFBFD"
$textMuted = "#615E5E"
$borderLt  = "#E4E4E4"

# Context badge color map (Choice values -> background, text color)
# Agency=navy, Center=blue, Program=gold, Project=purple, Industry=gray
function Get-BadgeStyle {
    param([string]$Context)
    switch ($Context) {
        "Agency"   { return @{ bg = "#182039"; fg = "#FFFFFF" } }
        "Center"   { return @{ bg = "#0693E3"; fg = "#FFFFFF" } }
        "Program"  { return @{ bg = "#E8B86A"; fg = "#FFFFFF" } }
        "Project"  { return @{ bg = "#6B46C1"; fg = "#FFFFFF" } }
        "Industry" { return @{ bg = "#615E5E"; fg = "#FFFFFF" } }
        default    { return @{ bg = "#E4E4E4"; fg = "#182039" } }
    }
}

function Encode-Html {
    param([string]$Text)
    if ($null -eq $Text) { return "" }
    $t = $Text
    $t = $t -replace '&', '&amp;'
    $t = $t -replace '<', '&lt;'
    $t = $t -replace '>', '&gt;'
    $t = $t -replace '"', '&quot;'
    return $t
}

$failures = @()

# ===========================================================================
# 1. Read all acronyms from the Acronyms list
# ===========================================================================
Write-Host ""
Write-Host "=== Reading Acronyms list ===" -ForegroundColor Cyan

$items = @()
try {
    $items = Get-PnPListItem -List "Acronyms" -PageSize 500 -ErrorAction Stop
    Write-Host "Read $($items.Count) acronyms." -ForegroundColor Green
} catch {
    Write-Host "FAILED to read Acronyms list: $($_.Exception.Message)" -ForegroundColor Red
    $failures += "Read Acronyms: $($_.Exception.Message)"
    return
}

# Project to PSObjects with the fields we need.
$acronyms = @()
foreach ($it in $items) {
    $title     = [string]$it.FieldValues["Title"]
    $expansion = [string]$it.FieldValues["Expansion"]
    $context   = [string]$it.FieldValues["AcronymContext"]
    $notes     = [string]$it.FieldValues["Notes"]

    if ([string]::IsNullOrWhiteSpace($title)) { continue }

    $acronyms += [PSCustomObject]@{
        Title     = $title.Trim()
        Expansion = $expansion
        Context   = $context
        Notes     = $notes
    }
}
$totalCount = $acronyms.Count
Write-Host "Usable entries (non-blank Title): $totalCount" -ForegroundColor Green

# ===========================================================================
# 2. Group by first letter, sort each group
# ===========================================================================
$letters = @("A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z")
$groups = @{}
foreach ($L in $letters) { $groups[$L] = @() }
$groups["Other"] = @()

foreach ($a in $acronyms) {
    $first = $a.Title.Substring(0,1).ToUpper()
    if ($letters -contains $first) {
        $groups[$first] += $a
    } else {
        $groups["Other"] += $a
    }
}

# Sort each group alphabetically by Title (case-insensitive)
foreach ($key in @($groups.Keys)) {
    $groups[$key] = @($groups[$key] | Sort-Object -Property @{Expression = { $_.Title.ToLower() }})
}

# Determine which letters have content (for the jump bar styling) and which are empty
$emptyLetters = @()
$nonEmptyLetters = @()
foreach ($L in $letters) {
    if ($groups[$L].Count -eq 0) {
        $emptyLetters += $L
    } else {
        $nonEmptyLetters += $L
    }
}
$hasOther = ($groups["Other"].Count -gt 0)

Write-Host ""
Write-Host "Letters with entries: $($nonEmptyLetters -join ', ')" -ForegroundColor Green
if ($emptyLetters.Count -gt 0) {
    Write-Host "Letters with NO entries: $($emptyLetters -join ', ')" -ForegroundColor Yellow
}
if ($hasOther) {
    Write-Host "'Other' bucket (non-letter starts): $($groups['Other'].Count) entries" -ForegroundColor Yellow
}

# ===========================================================================
# 3. Page helpers (mirrors provision-guided-experience-pages.ps1)
# ===========================================================================
function Ensure-Page {
    param([string]$Name, [string]$Title)
    $exists = $false
    try {
        $existing = Get-PnPClientSidePage -Identity $Name -ErrorAction Stop
        if ($null -ne $existing) { $exists = $true }
    } catch { $exists = $false }

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
                    # tolerate: cmdlet may not exist or control not removable
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
        Write-Host "  FAILED to add section $SectionIndex : $($_.Exception.Message)" -ForegroundColor Red
        $script:failures += "Section $SectionIndex add: $($_.Exception.Message)"
        return
    }
    foreach ($block in $TextBlocks) {
        try {
            Add-PnPClientSideText -Page $PageName -Section $SectionIndex -Column 1 -Text $block | Out-Null
        } catch {
            Write-Host "  FAILED to add text in section $SectionIndex : $($_.Exception.Message)" -ForegroundColor Red
            $script:failures += "Section $SectionIndex text: $($_.Exception.Message)"
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

# ===========================================================================
# 4. Build the page
# ===========================================================================
Write-Host ""
Write-Host "=== Page: $pageName ===" -ForegroundColor Cyan

$pageStatus = Ensure-Page -Name $pageName -Title $pageTitle

$sectionIndex = 1

# --- Section 1: Hero header (navy gradient) ---
$heroHtml = @"
<div style='background: linear-gradient(135deg, $navy 0%, $blue 100%); padding: 48px 32px 40px; text-align: center; border-radius: 8px;'>
  <div style='font-size: 12px; letter-spacing: 2.5px; text-transform: uppercase; color: #FFFFFF; margin-bottom: 12px; text-shadow: 0 1px 2px rgba(0,0,0,0.3);'>KITCHEN Reference</div>
  <h1 style='font-size: 40px; font-weight: 600; line-height: 1.1; margin: 0 0 12px 0; color: #FFFFFF; text-shadow: 0 2px 4px rgba(0,0,0,0.4);'>Acronym Glossary</h1>
  <div style='font-size: 16px; color: #FFFFFF; max-width: 720px; margin: 0 auto; font-weight: 400; text-shadow: 0 1px 3px rgba(0,0,0,0.35);'>$totalCount acronyms across NASA</div>
</div>
"@
Add-Section -PageName $pageName -SectionIndex $sectionIndex -TextBlocks @($heroHtml)
$sectionIndex++

# --- Section 2: Alphabet jump bar + legend ---
# Anchors via id attributes. SharePoint may rewrite hash links; we use both
# href='#letter-X' and a same-page reference for resilience. This is best-effort
# without custom JS; users may need to scroll if the anchors get stripped.
$jumpCells = @()
foreach ($L in $letters) {
    $hasItems = ($groups[$L].Count -gt 0)
    if ($hasItems) {
        $jumpCells += "<a href='#letter-$L' style='display:inline-block; min-width:32px; padding:6px 8px; margin:2px; background:$navy; color:#FFFFFF; border-radius:4px; text-decoration:none; font-weight:600; font-size:14px; text-align:center;'>$L</a>"
    } else {
        $jumpCells += "<span style='display:inline-block; min-width:32px; padding:6px 8px; margin:2px; background:$borderLt; color:#A8A7A5; border-radius:4px; font-weight:600; font-size:14px; text-align:center;'>$L</span>"
    }
}
if ($hasOther) {
    $jumpCells += "<a href='#letter-Other' style='display:inline-block; min-width:48px; padding:6px 10px; margin:2px; background:$navy; color:#FFFFFF; border-radius:4px; text-decoration:none; font-weight:600; font-size:14px; text-align:center;'>#</a>"
}
$jumpHtml = ($jumpCells -join "")

$legendHtml = @"
<span style='display:inline-block; padding:3px 10px; background:#182039; color:#FFFFFF; border-radius:10px; font-size:11px; font-weight:600; margin:2px; text-transform:uppercase; letter-spacing:0.5px;'>Agency</span>
<span style='display:inline-block; padding:3px 10px; background:#0693E3; color:#FFFFFF; border-radius:10px; font-size:11px; font-weight:600; margin:2px; text-transform:uppercase; letter-spacing:0.5px;'>Center</span>
<span style='display:inline-block; padding:3px 10px; background:#E8B86A; color:#FFFFFF; border-radius:10px; font-size:11px; font-weight:600; margin:2px; text-transform:uppercase; letter-spacing:0.5px;'>Program</span>
<span style='display:inline-block; padding:3px 10px; background:#6B46C1; color:#FFFFFF; border-radius:10px; font-size:11px; font-weight:600; margin:2px; text-transform:uppercase; letter-spacing:0.5px;'>Project</span>
<span style='display:inline-block; padding:3px 10px; background:#615E5E; color:#FFFFFF; border-radius:10px; font-size:11px; font-weight:600; margin:2px; text-transform:uppercase; letter-spacing:0.5px;'>Industry</span>
"@

$jumpBarHtml = @"
<div style='background: #FFFFFF; border-radius: 8px; padding: 18px 22px; box-shadow: 0 1.6px 3.6px rgba(0,0,0,0.06); margin-bottom: 8px;'>
  <div style='font-size: 12px; color: $textMuted; text-transform: uppercase; letter-spacing: 1px; margin-bottom: 8px; font-weight: 600;'>Jump to letter</div>
  <div style='line-height: 2.2;'>$jumpHtml</div>
  <div style='border-top: 1px solid $borderLt; margin-top: 14px; padding-top: 12px;'>
    <div style='font-size: 12px; color: $textMuted; text-transform: uppercase; letter-spacing: 1px; margin-bottom: 6px; font-weight: 600;'>Context legend</div>
    <div>$legendHtml</div>
  </div>
</div>
"@
Add-Section -PageName $pageName -SectionIndex $sectionIndex -TextBlocks @($jumpBarHtml)
$sectionIndex++

# ===========================================================================
# 5. One section per letter that has entries
# ===========================================================================

function Build-LetterSectionHtml {
    param(
        [string]$Letter,
        [array]$Entries
    )
    $count = $Entries.Count

    # Two-column table: split entries down the middle, left half then right half
    $half = [int][Math]::Ceiling($count / 2.0)
    $leftEntries  = @()
    $rightEntries = @()
    for ($i = 0; $i -lt $count; $i++) {
        if ($i -lt $half) { $leftEntries += $Entries[$i] }
        else              { $rightEntries += $Entries[$i] }
    }

    function Build-EntryRow {
        param($Entry)
        $titleEnc     = Encode-Html $Entry.Title
        $expansionEnc = Encode-Html $Entry.Expansion
        $notesEnc     = Encode-Html $Entry.Notes
        $ctx          = $Entry.Context
        $ctxEnc       = Encode-Html $ctx

        $badge = ""
        if (-not [string]::IsNullOrWhiteSpace($ctx)) {
            $style = Get-BadgeStyle -Context $ctx
            $badge = "<span style='display:inline-block; padding:2px 8px; background:$($style.bg); color:$($style.fg); border-radius:10px; font-size:10px; font-weight:600; text-transform:uppercase; letter-spacing:0.5px; margin-left:8px; vertical-align:middle;'>$ctxEnc</span>"
        }

        $notesHtml = ""
        if (-not [string]::IsNullOrWhiteSpace($Entry.Notes)) {
            $notesHtml = "<div style='font-size:12px; color:#615E5E; font-style:italic; margin-top:3px;'>$notesEnc</div>"
        }

        return @"
<div style='padding:10px 12px; border-bottom:1px solid #F0F0F0;'>
  <div><span style='font-weight:700; color:#182039; font-size:14px;'>$titleEnc</span>$badge</div>
  <div style='font-size:13px; color:#182039; margin-top:2px;'>$expansionEnc</div>
  $notesHtml
</div>
"@
    }

    $leftHtml = ""
    foreach ($e in $leftEntries) { $leftHtml += (Build-EntryRow -Entry $e) }

    $rightHtml = ""
    foreach ($e in $rightEntries) { $rightHtml += (Build-EntryRow -Entry $e) }

    if ([string]::IsNullOrEmpty($rightHtml)) {
        $rightHtml = "<div style='padding:10px 12px; color:#A8A7A5; font-style:italic; font-size:12px;'>&nbsp;</div>"
    }

    $html = @"
<div id='letter-$Letter' style='background:#FFFFFF; border-radius:8px; padding:24px 28px; box-shadow:0 1.6px 3.6px rgba(0,0,0,0.06); margin-bottom:8px;'>
  <a name='letter-$Letter'></a>
  <div style='border-bottom:3px solid #182039; padding-bottom:8px; margin-bottom:14px;'>
    <span style='display:inline-block; font-size:32px; font-weight:700; color:#182039; vertical-align:middle;'>$Letter</span>
    <span style='display:inline-block; font-size:13px; color:#615E5E; margin-left:14px; vertical-align:middle;'>$count entries</span>
    <a href='#top' style='float:right; font-size:12px; color:#615E5E; text-decoration:none; padding-top:14px;'>top &#8593;</a>
  </div>
  <table border='0' cellpadding='0' cellspacing='0' style='width:100%; border-collapse:collapse; border:0;'>
    <tr>
      <td style='width:50%; vertical-align:top; padding:0 8px 0 0; border:0;'>$leftHtml</td>
      <td style='width:50%; vertical-align:top; padding:0 0 0 8px; border:0;'>$rightHtml</td>
    </tr>
  </table>
</div>
"@
    return $html
}

$totalHtmlBytes = 0
foreach ($L in $letters) {
    if ($groups[$L].Count -eq 0) { continue }
    $sectionHtml = Build-LetterSectionHtml -Letter $L -Entries $groups[$L]
    $totalHtmlBytes += $sectionHtml.Length
    Add-Section -PageName $pageName -SectionIndex $sectionIndex -TextBlocks @($sectionHtml)
    Write-Host "  Added section for '$L' ($($groups[$L].Count) entries, $([Math]::Round($sectionHtml.Length/1024,1)) KB)" -ForegroundColor DarkGray
    $sectionIndex++
}

if ($hasOther) {
    $otherHtml = Build-LetterSectionHtml -Letter "Other" -Entries $groups["Other"]
    $totalHtmlBytes += $otherHtml.Length
    Add-Section -PageName $pageName -SectionIndex $sectionIndex -TextBlocks @($otherHtml)
    Write-Host "  Added 'Other' section ($($groups['Other'].Count) entries)" -ForegroundColor DarkGray
    $sectionIndex++
}

# --- Footer section ---
$footerHtml = @"
<div style='text-align:center; padding:18px; color:$textMuted; font-size:12px;'>
  Generated from the <a href='$siteUrl/Lists/Acronyms/AllItems.aspx' style='color:$navy; font-weight:600; text-decoration:none;'>Acronyms list</a>.
  Re-run <code>refresh-acronym-glossary-page.ps1</code> to refresh after edits.
</div>
"@
Add-Section -PageName $pageName -SectionIndex $sectionIndex -TextBlocks @($footerHtml)

Publish-Page -Name $pageName -Title $pageTitle

# ===========================================================================
# 6. Quick Launch nav
# ===========================================================================
Write-Host ""
Write-Host "=== Quick Launch nav ===" -ForegroundColor Cyan

$pageRel = Resolve-PageUrl -Name $pageName
if (-not $pageRel) { $pageRel = "$siteRoot/SitePages/" + ($pageName.Replace(' ','-')) + ".aspx" }
Add-NavIfMissing -Title $pageName -UrlRelative $pageRel

# ===========================================================================
# 7. Summary
# ===========================================================================
$encodedRel = $pageRel -replace ' ', '%20'
$publishedUrl = "https://nasa.sharepoint.com$encodedRel"

Write-Host ""
Write-Host "==================== SUMMARY ====================" -ForegroundColor Cyan
Write-Host "Page         : $pageStatus  ($pageName)" -ForegroundColor Green
Write-Host "Acronyms     : $totalCount" -ForegroundColor Green
Write-Host "Sections     : $($sectionIndex - 1) (hero + jump bar + per-letter + footer)" -ForegroundColor Green
Write-Host "Total HTML   : ~$([Math]::Round($totalHtmlBytes/1024,1)) KB across letter sections" -ForegroundColor Green
Write-Host "Letters used : $($nonEmptyLetters -join ', ')" -ForegroundColor Green
if ($emptyLetters.Count -gt 0) {
    Write-Host "Empty letters: $($emptyLetters -join ', ')" -ForegroundColor Yellow
}
if ($hasOther) {
    Write-Host "Other bucket : $($groups['Other'].Count) entries" -ForegroundColor Yellow
}
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
