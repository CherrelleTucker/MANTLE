$arrow = [char]0x2192

$tools = Get-PnPListItem -List "Tools" -Fields "ID","Title"
$toolByName = @{}
foreach ($t in $tools) {
    $title = $t.FieldValues["Title"]
    $toolByName[$title.ToLower().Trim()] = @{ Id = $t.Id; Title = $title }
    if ($title -like "Microsoft *") {
        $stripped = $title.Substring(10).ToLower().Trim()
        if (-not $toolByName.ContainsKey($stripped)) {
            $toolByName[$stripped] = @{ Id = $t.Id; Title = $title }
        }
    }
    if ($title -like "Google *") {
        $stripped = $title.Substring(7).ToLower().Trim()
        if (-not $toolByName.ContainsKey($stripped)) {
            $toolByName[$stripped] = @{ Id = $t.Id; Title = $title }
        }
    }
}

function Find-Tool($name) {
    if (-not $name) { return $null }
    $key = $name.ToLower().Trim()
    if ($toolByName.ContainsKey($key)) { return $toolByName[$key] }
    if ($toolByName.ContainsKey("microsoft $key")) { return $toolByName["microsoft $key"] }
    if ($toolByName.ContainsKey("google $key")) { return $toolByName["google $key"] }
    foreach ($k in $toolByName.Keys) {
        if ($k.Contains($key) -or $key.Contains($k)) { return $toolByName[$k] }
    }
    return $null
}

$items = Get-PnPListItem -List "Equivalency Map Real" -Fields "ID","Title","From_x002d_Tool","To_x002d_Tool"
$updated = 0
$failed = @()

foreach ($item in $items) {
    $title       = $item.FieldValues["Title"]
    $fromCurrent = $item.FieldValues["From_x002d_Tool"]
    $toCurrent   = $item.FieldValues["To_x002d_Tool"]
    $needsFrom   = -not $fromCurrent
    $needsTo     = -not $toCurrent

    if (-not ($needsFrom -or $needsTo)) { continue }

    $separators = @(
        (" " + $arrow + " "),
        " -> ",
        " > ",
        ([string]$arrow),
        "->"
    )
    $parts = $null
    foreach ($sep in $separators) {
        if ($title.Contains($sep)) {
            $parts = $title -split [regex]::Escape($sep), 2
            break
        }
    }
    if (-not $parts -or $parts.Count -ne 2) {
        $failed += [PSCustomObject]@{ ID = $item.Id; Title = $title; Reason = "Cannot parse title at arrow" }
        continue
    }

    $fromName = $parts[0].Trim()
    $toName   = $parts[1].Trim()
    $values   = @{}
    $missing  = @()

    if ($needsFrom) {
        $fromTool = Find-Tool $fromName
        if ($fromTool) { $values["From_x002d_Tool"] = $fromTool.Id }
        else { $missing += "From=$fromName" }
    }
    if ($needsTo) {
        $toTool = Find-Tool $toName
        if ($toTool) { $values["To_x002d_Tool"] = $toTool.Id }
        else { $missing += "To=$toName" }
    }

    if ($values.Count -gt 0) {
        Set-PnPListItem -List "Equivalency Map Real" -Identity $item.Id -Values $values | Out-Null
        $updated++
    }
    if ($missing.Count -gt 0) {
        $failed += [PSCustomObject]@{ ID = $item.Id; Title = $title; Reason = ($missing -join "; ") }
    }
}

Write-Host ""
Write-Host "Updated: $updated rows" -ForegroundColor Green
if ($failed.Count -gt 0) {
    Write-Host "$($failed.Count) rows need attention:" -ForegroundColor Yellow
    $failed | Format-Table -AutoSize
} else {
    Write-Host "All rows populated cleanly." -ForegroundColor Green
}
