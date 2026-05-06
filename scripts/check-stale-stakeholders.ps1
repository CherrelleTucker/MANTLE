# Check Stale Stakeholders
# Finds Stakeholders whose Last Contact is older than their Cadence allows.
#
# Assumes:
#   Connect-PnPOnline -UseWebLogin already run against the target site.
#
# Power Automate replacement: see design/pa-replacement-stale-check.md

param(
    [string]$PCName,
    [ValidateSet("Console","OneNote","File")]
    [string]$OutputFormat = "Console"
)

# ---------------------------------------------------------------------------
# Cadence -> max-days lookup
# ---------------------------------------------------------------------------
$cadenceDays = @{
    "Weekly"    = 7
    "Bi-weekly" = 14
    "Monthly"   = 30
    "Quarterly" = 90
    "Ad hoc"    = 999
}

function Get-CurrentUserEmail {
    try {
        $upn = (whoami /upn 2>$null)
        if ($upn) { return $upn.Trim() }
    } catch {}
    return $env:USERNAME
}

# ---------------------------------------------------------------------------
# Resolve owning PC (for filter)
# ---------------------------------------------------------------------------
$ownerEmail = $null
if ($PCName) {
    $pcs = Get-PnPListItem -List "PCs" -Fields "ID","Title","Email"
    $match = $pcs | Where-Object { $_.FieldValues["Title"] -eq $PCName } | Select-Object -First 1
    if (-not $match) {
        Write-Host "ERROR: No PC with name '$PCName' found." -ForegroundColor Red
        return
    }
    $ownerEmail = $match.FieldValues["Email"]
} else {
    $ownerEmail = Get-CurrentUserEmail
}

Write-Host "Filtering stakeholders to Owner = $ownerEmail" -ForegroundColor Cyan

# ---------------------------------------------------------------------------
# Pull stakeholders
# ---------------------------------------------------------------------------
$all = Get-PnPListItem -List "Stakeholders" -Fields "ID","Title","Org_x0020_or_x0020_Team","OrgOrTeam","Cadence","LastContact","Owner"

$stale = @()
$now = Get-Date

foreach ($s in $all) {
    # Owner filter (best effort - User field with Email property)
    $owner = $s.FieldValues["Owner"]
    $ownerOk = $true
    if ($ownerEmail) {
        $ownerOk = $false
        if ($owner) {
            $em = $null
            if ($owner.Email) { $em = $owner.Email }
            elseif ($owner.LookupValue) { $em = $owner.LookupValue }
            if ($em -and $em.ToLower().Trim() -eq $ownerEmail.ToLower().Trim()) {
                $ownerOk = $true
            }
        }
    }
    if (-not $ownerOk) { continue }

    $cadence = $s.FieldValues["Cadence"]
    if (-not $cadence) { continue }
    if (-not $cadenceDays.ContainsKey($cadence)) { continue }
    $maxDays = $cadenceDays[$cadence]
    if ($maxDays -ge 999) { continue }   # Ad hoc - never auto-stale

    $last = $s.FieldValues["LastContact"]
    $daysSince = $null
    if ($last) {
        $daysSince = [int]([math]::Floor(($now - [datetime]$last).TotalDays))
    } else {
        $daysSince = 99999  # Never contacted - definitely stale
    }

    if ($daysSince -gt $maxDays) {
        $org = $s.FieldValues["OrgOrTeam"]
        if (-not $org) { $org = $s.FieldValues["Org_x0020_or_x0020_Team"] }
        $stale += [PSCustomObject]@{
            Name        = $s.FieldValues["Title"]
            Org         = $org
            Cadence     = $cadence
            DaysSince   = $daysSince
            MaxDays     = $maxDays
            DaysOverdue = $daysSince - $maxDays
            LastContact = if ($last) { ([datetime]$last).ToString("yyyy-MM-dd") } else { "(never)" }
        }
    }
}

$stale = $stale | Sort-Object -Property DaysOverdue -Descending

# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "==================== STALE STAKEHOLDERS ====================" -ForegroundColor Cyan
Write-Host "Count: $($stale.Count)" -ForegroundColor Yellow

switch ($OutputFormat) {
    "Console" {
        if ($stale.Count -eq 0) {
            Write-Host "No stale stakeholders. Nice work." -ForegroundColor Green
        } else {
            $stale | Format-Table Name, Org, Cadence, LastContact, DaysOverdue -AutoSize
        }
    }
    "File" {
        $reportDir = "C:\Users\cjtucke3\Documents\Personal\Career\KITCHEN\reports"
        if (-not (Test-Path $reportDir)) { New-Item -ItemType Directory -Path $reportDir | Out-Null }
        $datestamp = (Get-Date).ToString("yyyy-MM-dd")
        $reportPath = Join-Path $reportDir "stale-stakeholders-$datestamp.md"

        $sb = New-Object System.Text.StringBuilder
        [void]$sb.AppendLine("# Stale Stakeholders Report")
        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("Generated: " + $now.ToString("yyyy-MM-dd HH:mm"))
        [void]$sb.AppendLine("Owner filter: $ownerEmail")
        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("Total stale: " + $stale.Count)
        [void]$sb.AppendLine("")
        if ($stale.Count -gt 0) {
            [void]$sb.AppendLine("| Name | Org | Cadence | Last Contact | Days Overdue |")
            [void]$sb.AppendLine("|------|-----|---------|--------------|--------------|")
            foreach ($r in $stale) {
                [void]$sb.AppendLine("| $($r.Name) | $($r.Org) | $($r.Cadence) | $($r.LastContact) | $($r.DaysOverdue) |")
            }
        } else {
            [void]$sb.AppendLine("None. Nice work.")
        }
        $sb.ToString() | Out-File -FilePath $reportPath -Encoding utf8
        Write-Host "Wrote report to $reportPath" -ForegroundColor Green
    }
    "OneNote" {
        # TODO: OneNote output not yet implemented. The PnP module has limited
        # OneNote support; the cleanest path is to use the OneNote COM object
        # (Microsoft.Office.Interop.OneNote) to add a page to a configured
        # section. Falling back to Console output for now.
        Write-Host "OneNote output not implemented yet - printing to console instead." -ForegroundColor Yellow
        if ($stale.Count -eq 0) {
            Write-Host "No stale stakeholders." -ForegroundColor Green
        } else {
            $stale | Format-Table Name, Org, Cadence, LastContact, DaysOverdue -AutoSize
        }
    }
}

Write-Host "==========================================================="
