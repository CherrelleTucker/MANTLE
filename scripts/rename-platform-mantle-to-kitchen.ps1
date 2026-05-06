# Rename the SharePoint side of the platform from MANTLE to KITCHEN.
#
# Display titles change. URL slugs are intentionally PRESERVED:
#   - SharePoint site URL slug   (/teams/PCTransitionSandbox)         stays
#   - Page URL slugs             (SitePages/MANTLE-Home.aspx,
#                                 SitePages/MANTLE-Actions.aspx)      stay
#   - List internal names                                             stay
# Reason: bookmark stability. SharePoint's "rename a page URL" path is
# unreliable and breaks every link anyone has saved. Display titles can
# change freely without breaking URLs.
#
# Assumptions:
#   - Connect-PnPOnline -UseWebLogin has ALREADY been run against the site
#     (https://nasa.sharepoint.com/teams/PCTransitionSandbox) in this PS
#     session. This script does NOT call Connect-PnPOnline.
#   - Legacy SharePointPnPPowerShellOnline module on Windows PowerShell 5.1.
#
# Idempotent: each step checks current state and skips if already KITCHEN.
# Run as many times as you like.

$ErrorActionPreference = 'Continue'

$failures = @()
$applied  = @()
$skipped  = @()

# ---------------------------------------------------------------------------
# 1. Site title
# ---------------------------------------------------------------------------
Write-Host "[1/4] Site title" -ForegroundColor Cyan
try {
    $web = Get-PnPWeb -ErrorAction Stop
    if ($web.Title -eq 'KITCHEN') {
        Write-Host "  already 'KITCHEN' - skip"
        $skipped += "Site title (already KITCHEN)"
    } else {
        Set-PnPSite -Title 'KITCHEN' -ErrorAction Stop
        Write-Host "  set site title -> 'KITCHEN' (was '$($web.Title)')"
        $applied += "Site title: '$($web.Title)' -> 'KITCHEN'"
    }
} catch {
    Write-Warning "  failed: $_"
    $failures += "Site title: $_"
}

# ---------------------------------------------------------------------------
# 2. Page display titles
# ---------------------------------------------------------------------------
$pageRenames = @(
    @{ OldId = 'MANTLE Home';    NewTitle = 'KITCHEN Home' },
    @{ OldId = 'MANTLE Actions'; NewTitle = 'KITCHEN Actions' }
)

Write-Host "[2/4] Page display titles" -ForegroundColor Cyan
foreach ($r in $pageRenames) {
    $oldId    = $r.OldId
    $newTitle = $r.NewTitle
    try {
        # Try by current display name first, then by new name (idempotent path).
        $page = $null
        try { $page = Get-PnPClientSidePage -Identity $oldId -ErrorAction Stop } catch {}
        if (-not $page) {
            try { $page = Get-PnPClientSidePage -Identity $newTitle -ErrorAction Stop } catch {}
        }
        if (-not $page) {
            Write-Warning "  $oldId -> $newTitle : page not found by either name"
            $failures += "Page $oldId : not found"
            continue
        }
        if ($page.PageTitle -eq $newTitle) {
            Write-Host "  $($page.PageTitle) : already renamed - skip"
            $skipped += "Page (already $newTitle)"
        } else {
            Set-PnPClientSidePage -Identity $page.Name -Title $newTitle -ErrorAction Stop | Out-Null
            Write-Host "  page '$($page.PageTitle)' -> '$newTitle'"
            $applied += "Page title: '$($page.PageTitle)' -> '$newTitle'"
        }
    } catch {
        Write-Warning "  $oldId rename failed: $_"
        $failures += "Page $oldId : $_"
    }
}

# ---------------------------------------------------------------------------
# 3. Quick Launch nav node titles
# ---------------------------------------------------------------------------
# Legacy module pattern: Set-PnPNavigationNode does not exist. We Remove +
# Add (preserving Url and any sort order we can recover).
$navRenames = @(
    @{ Old = 'MANTLE Home';    New = 'KITCHEN Home' },
    @{ Old = 'MANTLE Actions'; New = 'KITCHEN Actions' },
    @{ Old = 'MANTLE';         New = 'KITCHEN' }
)

Write-Host "[3/4] Quick Launch nav nodes" -ForegroundColor Cyan
try {
    $allNodes = Get-PnPNavigationNode -Location QuickLaunch -ErrorAction Stop
    foreach ($r in $navRenames) {
        $oldTitle = $r.Old
        $newTitle = $r.New
        $node = $allNodes | Where-Object { $_.Title -eq $oldTitle } | Select-Object -First 1
        if (-not $node) {
            $alreadyNew = $allNodes | Where-Object { $_.Title -eq $newTitle } | Select-Object -First 1
            if ($alreadyNew) {
                Write-Host "  '$newTitle' already present - skip"
                $skipped += "Nav node (already $newTitle)"
            }
            continue
        }
        $url = $node.Url
        try {
            Remove-PnPNavigationNode -Identity $node.Id -Force -ErrorAction Stop
            Add-PnPNavigationNode -Location QuickLaunch -Title $newTitle -Url $url -ErrorAction Stop | Out-Null
            Write-Host "  nav '$oldTitle' -> '$newTitle'"
            $applied += "Nav node: '$oldTitle' -> '$newTitle'"
        } catch {
            Write-Warning "  nav '$oldTitle' rename failed: $_"
            $failures += "Nav $oldTitle : $_"
        }
    }
} catch {
    Write-Warning "  could not enumerate nav nodes: $_"
    $failures += "Nav enumeration: $_"
}

# ---------------------------------------------------------------------------
# 4. Summary
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "[4/4] Summary" -ForegroundColor Cyan
Write-Host "  Applied : $($applied.Count)"
foreach ($a in $applied)  { Write-Host "    - $a" }
Write-Host "  Skipped : $($skipped.Count)"
foreach ($s in $skipped)  { Write-Host "    - $s" }
$failColor = 'Gray'
if ($failures.Count -gt 0) { $failColor = 'Yellow' }
Write-Host "  Failed  : $($failures.Count)" -ForegroundColor $failColor
foreach ($f in $failures) { Write-Host "    - $f" -ForegroundColor Yellow }

Write-Host ""
Write-Host "Done. URL slugs (MANTLE-Home.aspx, MANTLE-Actions.aspx, /teams/PCTransitionSandbox)"
Write-Host "remain unchanged by design."
