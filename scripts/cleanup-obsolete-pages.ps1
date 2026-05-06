# cleanup-obsolete-pages.ps1
# Renames obsolete rich-HTML pages (Team Directory, Meeting Catalog, Acronym
# Glossary) that have been superseded by the formatted list views accessed
# directly via Site Contents. Retention policy blocks deletion, so we rename
# the FileLeafRef to start with _OLD- and prefix the Title with [OLD] for a
# visual flag in any list view that surfaces them. Also removes any
# QuickLaunch nodes that point to those pages.
#
# Connection assumed: already Connect-PnPOnline'd to
#   https://nasa.sharepoint.com/teams/PCTransitionSandbox
# Module: legacy SharePointPnPPowerShellOnline on Windows PowerShell 5.1.

$ErrorActionPreference = "Stop"

# Each entry: friendly label + candidate filenames (space and hyphen variants)
# + candidate QuickLaunch link tails to match against.
$pages = @(
    @{
        Label      = "Team Directory"
        Candidates = @("Team Directory.aspx", "Team-Directory.aspx", "TeamDirectory.aspx")
        NavMatch   = @("Team Directory", "Team-Directory", "TeamDirectory")
    },
    @{
        Label      = "Meeting Catalog"
        Candidates = @("Meeting Catalog.aspx", "Meeting-Catalog.aspx", "MeetingCatalog.aspx")
        NavMatch   = @("Meeting Catalog", "Meeting-Catalog", "MeetingCatalog")
    },
    @{
        Label      = "Acronym Glossary"
        Candidates = @("Acronym Glossary.aspx", "Acronym-Glossary.aspx", "AcronymGlossary.aspx")
        NavMatch   = @("Acronym Glossary", "Acronym-Glossary", "AcronymGlossary")
    }
)

$renamed   = @()
$skipped   = @()
$notFound  = @()
$failed    = @()
$navRemoved = @()
$navFailed  = @()

function Find-PageItem {
    param(
        [string[]] $Candidates
    )
    foreach ($name in $Candidates) {
        try {
            $xmlName = [System.Security.SecurityElement]::Escape($name)
            $query = "<View><Query><Where><Eq><FieldRef Name='FileLeafRef'/><Value Type='Text'>$xmlName</Value></Eq></Where></Query></View>"
            $item = Get-PnPListItem -List "Site Pages" -Query $query -ErrorAction Stop
            if ($item) {
                return @{ Item = $item; MatchedName = $name }
            }
        } catch {
            # Try next candidate
        }
    }
    return $null
}

Write-Host ""
Write-Host "=== Cleanup obsolete rich-HTML pages ===" -ForegroundColor Cyan
Write-Host ""

foreach ($page in $pages) {
    $label = $page.Label
    Write-Host "--- $label ---" -ForegroundColor Yellow

    try {
        $found = Find-PageItem -Candidates $page.Candidates

        if ($null -eq $found) {
            # Also check whether an already-renamed _OLD- copy exists
            $oldCandidates = @()
            foreach ($c in $page.Candidates) { $oldCandidates += "_OLD-$c" }
            $alreadyOld = Find-PageItem -Candidates $oldCandidates

            if ($alreadyOld) {
                Write-Host "  Already renamed previously ($($alreadyOld.MatchedName)). Skipping." -ForegroundColor DarkGray
                $skipped += $label
            } else {
                Write-Host "  Not found in Site Pages library (tried: $($page.Candidates -join ', ')). Skipping." -ForegroundColor DarkGray
                $notFound += $label
            }
        } else {
            $matched = $found.MatchedName
            $item    = $found.Item

            if ($matched.StartsWith("_OLD-")) {
                Write-Host "  Already starts with _OLD-. Skipping." -ForegroundColor DarkGray
                $skipped += $label
            } else {
                $newLeaf  = "_OLD-$matched"
                $newTitle = "[OLD] $label"
                try {
                    Set-PnPListItem -List "Site Pages" -Identity $item.Id -Values @{
                        FileLeafRef = $newLeaf
                        Title       = $newTitle
                    } -ErrorAction Stop | Out-Null
                    Write-Host "  Renamed: $matched -> $newLeaf" -ForegroundColor Green
                    Write-Host "  Title  : $newTitle" -ForegroundColor Green
                    $renamed += "$label ($matched -> $newLeaf)"
                } catch {
                    Write-Host "  FAILED to rename $matched : $($_.Exception.Message)" -ForegroundColor Red
                    $failed += "$label (rename: $($_.Exception.Message))"
                }
            }
        }
    } catch {
        Write-Host "  FAILED while processing $label : $($_.Exception.Message)" -ForegroundColor Red
        $failed += "$label (lookup: $($_.Exception.Message))"
    }
}

Write-Host ""
Write-Host "--- QuickLaunch cleanup ---" -ForegroundColor Yellow

try {
    $nodes = Get-PnPNavigationNode -Location QuickLaunch -ErrorAction Stop

    foreach ($page in $pages) {
        $label    = $page.Label
        $matchers = $page.NavMatch
        $matchers += $label

        $hits = @()
        foreach ($n in $nodes) {
            $title = "$($n.Title)"
            $url   = "$($n.Url)"
            foreach ($m in $matchers) {
                if ($title -ieq $m) { $hits += $n; break }
                if ($url -match [regex]::Escape($m)) { $hits += $n; break }
            }
        }

        if ($hits.Count -eq 0) {
            Write-Host "  No QuickLaunch node found for '$label'." -ForegroundColor DarkGray
            continue
        }

        foreach ($node in ($hits | Select-Object -Unique)) {
            try {
                Remove-PnPNavigationNode -Identity $node.Id -Force -ErrorAction Stop
                Write-Host "  Removed nav node: '$($node.Title)' (Id $($node.Id))" -ForegroundColor Green
                $navRemoved += "$label -> $($node.Title)"
            } catch {
                Write-Host "  FAILED to remove nav node '$($node.Title)' : $($_.Exception.Message)" -ForegroundColor Red
                $navFailed += "$label -> $($node.Title) ($($_.Exception.Message))"
            }
        }
    }
} catch {
    Write-Host "  FAILED to enumerate QuickLaunch: $($_.Exception.Message)" -ForegroundColor Red
    $navFailed += "enumerate: $($_.Exception.Message)"
}

Write-Host ""
Write-Host "================ SUMMARY ================" -ForegroundColor Cyan
Write-Host "Renamed pages   : $($renamed.Count)"
foreach ($r in $renamed) { Write-Host "  - $r" }
Write-Host "Skipped pages   : $($skipped.Count)"
foreach ($s in $skipped) { Write-Host "  - $s" }
Write-Host "Not found pages : $($notFound.Count)"
foreach ($n in $notFound) { Write-Host "  - $n" }
Write-Host "Failed pages    : $($failed.Count)"
foreach ($f in $failed) { Write-Host "  - $f" }
Write-Host "Nav nodes removed: $($navRemoved.Count)"
foreach ($nr in $navRemoved) { Write-Host "  - $nr" }
Write-Host "Nav nodes failed : $($navFailed.Count)"
foreach ($nf in $navFailed) { Write-Host "  - $nf" }
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""
