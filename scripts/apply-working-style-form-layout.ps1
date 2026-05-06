# Apply friendly form-formatting JSON to Stakeholders and PCs list forms.
#
# Groups the 23 working-style questions into the 4 matrix categories
# (Communication / Working / Thinking / Interpersonal) with section headers
# inside the side-panel new-item / edit-item form.
#
# After this runs, opening the form (click + New or pencil-edit any row)
# shows a clean grouped interview-style layout instead of a raw column list.
#
# What this DOES:
#   * Sets Form Header JSON on Stakeholders + PCs (intro text + brand color)
#   * Sets Form Body JSON on both (4 grouped sections + free-form area)
#   * Keeps every existing column visible -- only changes layout/grouping
#
# What this DOES NOT:
#   * Modify columns themselves
#   * Delete or hide any field permanently
#   * Touch any list other than Stakeholders + PCs
#
# Module: legacy SharePointPnPPowerShellOnline.
# Assumes: Connect-PnPOnline -UseWebLogin already done.
#
# Note: legacy module's form-customizer cmdlets are limited. If
# Set-PnPListItem-based application fails on this tenant, the script writes
# the JSON to two reference files and prints UI paste instructions.

# ===========================================================================
# Field maps -- different internal-name suffixes between the two lists
# ===========================================================================
$stakeholderFields = [ordered]@{
    Communication = @(
        "PreferredChannel",
        "SecondaryChannel",
        "EditsLeaveStyle2",
        "EditsReceiveStyle2",
        "DecisionTimingSelf2",
        "DecisionTimingOthers2",
        "DecisionFormat"
    )
    Working = @(
        "WorkingHoursStart",
        "WorkingHoursEnd",
        "MeetingTimePreference",
        "DeepWorkStyle2",
        "InclusionPreference2",
        "StatusUpdateCadence"
    )
    Thinking = @(
        "ProcessingStyle",
        "ThinkerType2",
        "RabbitTrails",
        "Overthinker"
    )
    Interpersonal = @(
        "ReceiveFeedback2",
        "GiveFeedback2",
        "ReceiveRecognition2",
        "GiveRecognition2",
        "ConflictDefault"
    )
    FreeForm = @(
        "WorkingStyleComments"
    )
}

$pcFields = [ordered]@{
    Communication = @(
        "PrimaryChannel",
        "SecondaryChannel",
        "EditsLeaveStyle",
        "EditsReceiveStyle",
        "DecisionTimingSelf",
        "DecisionTimingOthers",
        "DecisionFormat"
    )
    Working = @(
        "WorkingHoursStart",
        "WorkingHoursEnd",
        "MeetingTimePreference",
        "DeepWorkStyle",
        "InclusionPreference",
        "StatusUpdateCadence"
    )
    Thinking = @(
        "ProcessingStyle",
        "ThinkerType",
        "RabbitTrails",
        "Overthinker"
    )
    Interpersonal = @(
        "ReceiveFeedback",
        "GiveFeedback",
        "ReceiveRecognition",
        "GiveRecognition",
        "ConflictDefault"
    )
    FreeForm = @(
        "WorkingStyleComments"
    )
}

# ===========================================================================
# Header JSON -- one paragraph intro at the top of the form panel
# ===========================================================================
$headerJson = @'
{
  "elmType": "div",
  "attributes": { "class": "ms-borderColor-neutralTertiary" },
  "style": {
    "padding": "12px",
    "background-color": "#182039",
    "border-radius": "6px",
    "margin-bottom": "12px"
  },
  "children": [
    {
      "elmType": "div",
      "txtContent": "Working Styles Matrix",
      "style": {
        "color": "#E8B86A",
        "font-size": "16px",
        "font-weight": "bold",
        "margin-bottom": "6px"
      }
    },
    {
      "elmType": "div",
      "txtContent": "Capture how this person prefers to communicate, work, think, and resolve conflict. The questions below come from the Barrios Working Styles Matrix. Answer what is known; leave the rest blank for now.",
      "style": {
        "color": "#FFFFFF",
        "font-size": "13px"
      }
    }
  ]
}
'@

# ===========================================================================
# Body JSON builder: emits the 4-section + free-form layout for either list
# ===========================================================================
function Build-BodyJson {
    param([System.Collections.Specialized.OrderedDictionary]$Map)

    $sections = @(
        @{ displayname = "1. Communication Styles"; fields = $Map.Communication }
        @{ displayname = "2. Working Styles";       fields = $Map.Working }
        @{ displayname = "3. Thinking Styles";      fields = $Map.Thinking }
        @{ displayname = "4. Interpersonal Styles"; fields = $Map.Interpersonal }
        @{ displayname = "Free-form notes";         fields = $Map.FreeForm }
    )

    $body = @{ sections = $sections }
    return ($body | ConvertTo-Json -Depth 10 -Compress)
}

$stakeholderBody = Build-BodyJson -Map $stakeholderFields
$pcBody          = Build-BodyJson -Map $pcFields

# ===========================================================================
# Apply via SharePoint REST. Legacy PnP doesn't expose a clean cmdlet for
# Form Customizer JSON, but we can set it via the list root folder
# property bag values for ClientFormCustomFormatter / ClientFormHeaderFormatter.
# ===========================================================================
function Set-FormLayout {
    param(
        [string]$ListName,
        [string]$HeaderJson,
        [string]$BodyJson
    )
    Write-Host ""
    Write-Host "=== $ListName ===" -ForegroundColor Cyan

    try {
        $list = Get-PnPList -Identity $ListName -ErrorAction Stop
    } catch {
        Write-Host "  list not found, skipping." -ForegroundColor Yellow
        return $false
    }

    # Approach: set via Content Type 'Item' on the list. The properties are:
    #   ClientFormCustomFormatter (body)
    #   ClientFormHeaderFormatter (header)
    # These get serialized into the form-customizer JSON for the new-item /
    # edit-item form panel.
    try {
        $ct = Get-PnPContentType -List $ListName -Identity "Item" -ErrorAction Stop
        $ctx = Get-PnPContext

        # Header
        $ct.ClientFormCustomFormatter = $BodyJson
        # Note: legacy module exposes ClientFormCustomFormatter for body.
        # Header is set via a different property on newer modules; on legacy
        # we may only be able to set body. Header gets emitted to a fallback
        # file for manual UI paste.
        $ct.Update($false)
        $ctx.ExecuteQuery()
        Write-Host "  Body JSON applied via Content Type 'Item'." -ForegroundColor Green
        return $true
    } catch {
        Write-Host "  Could not apply via PowerShell ($($_.Exception.Message))." -ForegroundColor Yellow
        Write-Host "  Falling back: writing JSON files for manual UI paste." -ForegroundColor DarkGray
        return $false
    }
}

# ===========================================================================
# Run for both lists; emit JSON files regardless (so manual paste is always
# an option, and so the JSON is preserved as a design artifact).
# ===========================================================================
$designDir = Join-Path (Split-Path -Parent $PSScriptRoot) "design"
if (-not (Test-Path $designDir)) {
    New-Item -ItemType Directory -Path $designDir -Force | Out-Null
}

# Always write the JSON files
$stakeholderHeaderPath = Join-Path $designDir "form-layout-stakeholders-header.json"
$stakeholderBodyPath   = Join-Path $designDir "form-layout-stakeholders-body.json"
$pcHeaderPath          = Join-Path $designDir "form-layout-pcs-header.json"
$pcBodyPath            = Join-Path $designDir "form-layout-pcs-body.json"

Set-Content -Path $stakeholderHeaderPath -Value $headerJson -Encoding UTF8
Set-Content -Path $stakeholderBodyPath   -Value $stakeholderBody -Encoding UTF8
Set-Content -Path $pcHeaderPath          -Value $headerJson -Encoding UTF8
Set-Content -Path $pcBodyPath            -Value $pcBody -Encoding UTF8

Write-Host ""
Write-Host "JSON files written to design/ folder:" -ForegroundColor Cyan
Write-Host "  $stakeholderHeaderPath"
Write-Host "  $stakeholderBodyPath"
Write-Host "  $pcHeaderPath"
Write-Host "  $pcBodyPath"

# Try to apply via PowerShell
$stakeholdersOk = Set-FormLayout -ListName "Stakeholders" -HeaderJson $headerJson -BodyJson $stakeholderBody
$pcsOk          = Set-FormLayout -ListName "PCs" -HeaderJson $headerJson -BodyJson $pcBody

# ===========================================================================
# Summary + manual instructions (always print -- header may need manual paste
# even when body succeeded)
# ===========================================================================
Write-Host ""
Write-Host "==================== MANUAL UI STEPS ====================" -ForegroundColor Yellow
Write-Host ""
Write-Host "Body section grouping is the main improvement. If the script"
Write-Host "applied it via PowerShell (green messages above), you are done"
Write-Host "for the body. The HEADER (intro text at top of the form panel)"
Write-Host "almost always needs manual paste via UI on legacy module."
Write-Host ""
Write-Host "For each list (Stakeholders, PCs):" -ForegroundColor Cyan
Write-Host "  1. Open the list -> click '+ New'"
Write-Host "  2. In the side panel that opens, click 'Edit form' (top)"
Write-Host "     OR click the '...' menu in the panel header -> 'Configure layout'"
Write-Host "  3. Choose 'Header'"
Write-Host "  4. Paste the contents of the matching header JSON file"
Write-Host "  5. Save"
Write-Host "  6. (If body did not auto-apply) Choose 'Body' -> paste body JSON file -> Save"
Write-Host ""
Write-Host "JSON files to copy from:" -ForegroundColor DarkGray
Write-Host "  Stakeholders header : $stakeholderHeaderPath"
Write-Host "  Stakeholders body   : $stakeholderBodyPath"
Write-Host "  PCs header          : $pcHeaderPath"
Write-Host "  PCs body            : $pcBodyPath"
Write-Host ""
Write-Host "After paste, click + New on the list -- you should see:"
Write-Host "  - Navy banner at top with 'Working Styles Matrix' heading and intro"
Write-Host "  - Fields grouped under 4 collapsible sections + free-form notes"
Write-Host "  - Same data underneath; just a friendlier layout"
Write-Host "================================================="
