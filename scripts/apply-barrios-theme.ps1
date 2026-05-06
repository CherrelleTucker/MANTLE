# apply-barrios-theme.ps1
# Applies a Barrios-branded custom theme to the MANTLE SharePoint site.
#
# Requires:
#   - Windows PowerShell 5.1
#   - SharePointPnPPowerShellOnline (legacy module)
#   - Active connection: Connect-PnPOnline -Url https://nasa.sharepoint.com/teams/PCTransitionSandbox -UseWebLogin
#
# Brand reference (verified against barrios.com):
#   Primary navy        #182039
#   Bright blue accent  #0693E3
#   Moon gold accent    #E8B86A
#   Deep navy hover     #0F1A2E
#   Off-white bg        #F5F7FA
#   Body text dark      #18130C
#   Muted text          #615E5E
#
# Usage:
#   PS> .\apply-barrios-theme.ps1
#
# ASCII-only. No Unicode literals.

$ErrorActionPreference = 'Stop'

$ThemeName = 'Barrios MANTLE'

# ---------------------------------------------------------------------------
# Color palette
#
# themePrimary is Barrios navy #182039. The lighter/darker variants below
# are hand-tinted toward white (lighter) and black (darker) so they match
# the Fluent UI ramp shape that SharePoint expects. Neutrals lean cool
# off-white -> deep navy to harmonize with the brand. Accent is Barrios gold.
# ---------------------------------------------------------------------------
$BarriosTheme = @{
    # Primary ramp (navy #182039)
    'themePrimary'         = '#182039'
    'themeLighterAlt'      = '#f4f5f8'   # ~97% tint
    'themeLighter'         = '#d6d9e1'   # ~85% tint
    'themeLight'           = '#b3b9c7'   # ~70% tint
    'themeTertiary'        = '#6c7591'   # ~45% tint
    'themeSecondary'       = '#2f3a5b'   # slight tint
    'themeDarkAlt'         = '#161d34'   # slight shade
    'themeDark'            = '#12182c'   # darker
    'themeDarker'          = '#0d1220'   # darkest
    # Neutral ramp (cool off-white to deep navy)
    'neutralLighterAlt'    = '#faf9f8'
    'neutralLighter'       = '#f5f7fa'   # Barrios off-white background
    'neutralLight'         = '#edebe9'
    'neutralQuaternaryAlt' = '#e1dfdd'
    'neutralQuaternary'    = '#d2d0ce'
    'neutralTertiaryAlt'   = '#c8c6c4'
    'neutralTertiary'      = '#a19f9d'
    'neutralSecondary'     = '#615e5e'   # Barrios muted text
    'neutralPrimaryAlt'    = '#3b3a39'
    'neutralPrimary'       = '#18130c'   # Barrios body text dark
    'neutralDark'          = '#201f1e'
    'black'                = '#000000'
    'white'                = '#ffffff'
    # Surfaces / text aliases
    'primaryBackground'    = '#ffffff'
    'primaryText'          = '#18130c'
    'bodyBackground'       = '#ffffff'
    'bodyText'             = '#18130c'
    'disabledBackground'   = '#f3f2f1'
    'disabledText'         = '#a19f9d'
    # Accent (Barrios moon gold)
    'accent'               = '#E8B86A'
}

function Write-Section {
    param([string]$Title)
    Write-Host ''
    Write-Host ('=' * 72)
    Write-Host $Title
    Write-Host ('=' * 72)
}

# ---------------------------------------------------------------------------
# Verify a PnP connection exists before doing anything else.
# ---------------------------------------------------------------------------
Write-Section 'Verifying PnP connection'
try {
    $ctx = Get-PnPContext
    $web = Get-PnPWeb
    Write-Host ("Connected to : " + $web.Url)
    Write-Host ("Web title    : " + $web.Title)
} catch {
    Write-Host 'ERROR: No active PnP connection.' -ForegroundColor Red
    Write-Host 'Run: Connect-PnPOnline -Url https://nasa.sharepoint.com/teams/PCTransitionSandbox -UseWebLogin'
    exit 1
}

# ---------------------------------------------------------------------------
# Echo palette so the user can see what is being applied.
# ---------------------------------------------------------------------------
Write-Section ("Palette: " + $ThemeName)
$BarriosTheme.GetEnumerator() |
    Sort-Object Name |
    ForEach-Object { Write-Host ('  {0,-22} {1}' -f $_.Key, $_.Value) }

# ---------------------------------------------------------------------------
# Method 1 (preferred): publish the theme tenant-wide, then apply by name.
# Requires SharePoint tenant admin. Will fail for standard site owners.
# ---------------------------------------------------------------------------
$tenantPublishOk = $false
Write-Section 'Method 1: Add-PnPTenantTheme (tenant-admin path)'
try {
    Add-PnPTenantTheme -Identity $ThemeName -Palette $BarriosTheme -IsInverted:$false -Overwrite -ErrorAction Stop
    Write-Host ("OK: Theme '" + $ThemeName + "' published to the tenant gallery.") -ForegroundColor Green
    $tenantPublishOk = $true
} catch {
    Write-Host 'SKIP: Could not publish at the tenant level.' -ForegroundColor Yellow
    Write-Host ('       Reason: ' + $_.Exception.Message)
    Write-Host '       This usually means you are not a SharePoint tenant admin.'
    Write-Host '       Falling back to a web-scoped apply (Method 2).'
}

# ---------------------------------------------------------------------------
# Method 2: apply the palette directly to the current web.
# Works for site owners. Survives across the site/subsites it is applied to.
# Try the named-theme apply first if Method 1 succeeded; otherwise apply
# the raw palette hashtable to this web.
# ---------------------------------------------------------------------------
Write-Section 'Method 2: Set-PnPWebTheme (web-scoped apply)'
$applied = $false
try {
    if ($tenantPublishOk) {
        Set-PnPWebTheme -Theme $ThemeName -ErrorAction Stop
        Write-Host ("OK: Applied tenant theme '" + $ThemeName + "' to the current web.") -ForegroundColor Green
        $applied = $true
    } else {
        # No tenant entry exists; push the palette hash straight at the web.
        Set-PnPWebTheme -Theme $BarriosTheme -ErrorAction Stop
        Write-Host 'OK: Applied custom Barrios palette to the current web.' -ForegroundColor Green
        $applied = $true
    }
} catch {
    Write-Host 'ERROR: Set-PnPWebTheme failed.' -ForegroundColor Red
    Write-Host ('       Reason: ' + $_.Exception.Message)
}

# ---------------------------------------------------------------------------
# Result + remediation hints.
# ---------------------------------------------------------------------------
Write-Section 'Result'
if ($applied) {
    Write-Host 'SUCCESS. Reload the site in your browser (Ctrl+F5) to see the new colors.' -ForegroundColor Green
    Write-Host 'Native SharePoint web parts will pick up the palette automatically.'
    if (-not $tenantPublishOk) {
        Write-Host ''
        Write-Host 'NOTE: The theme was applied at the WEB level only.'
        Write-Host '      If you want it available across the tenant or selectable from'
        Write-Host '      the Change-the-Look picker by name, ask a SharePoint tenant'
        Write-Host '      admin to run Add-PnPTenantTheme with this same palette.'
    }
    exit 0
} else {
    Write-Host 'FAILED to apply the Barrios palette.' -ForegroundColor Red
    Write-Host ''
    Write-Host 'Likely causes and fixes:'
    Write-Host '  1. You lack site-owner permission on this web.'
    Write-Host '     -> Ask the site owner to add you, or have them run this script.'
    Write-Host '  2. Custom scripts / theming is blocked at the tenant level.'
    Write-Host '     -> A SharePoint admin must run:'
    Write-Host '          Set-SPOSite -Identity <site-url> -DenyAddAndCustomizePages 0'
    Write-Host '        and/or publish the theme tenant-wide via Add-PnPTenantTheme,'
    Write-Host '        after which any user can pick it from Change the Look.'
    Write-Host '  3. Module is too old. Confirm SharePointPnPPowerShellOnline is loaded:'
    Write-Host '          Get-Module SharePointPnPPowerShellOnline'
    exit 2
}
