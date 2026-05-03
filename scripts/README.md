# MANTLE Scripts

PowerShell scripts that automate provisioning and maintenance of MANTLE's SharePoint Lists.

All scripts assume you're running in a PowerShell session that has already connected to your SharePoint site via:

```powershell
Connect-PnPOnline -Url "https://nasa.sharepoint.com/teams/PCTransitionSandbox" -UseWebLogin
```

## Running a script

You have three options:

### Option 1 — Dot-source (recommended)

In your connected PowerShell session, run:

```powershell
. "C:\Users\cjtucke3\Documents\Personal\Career\MANTLE\scripts\populate-equivalency-lookups.ps1"
```

The leading `.` (dot-space) "dot-sources" the script — it runs in your current session, keeping your PnP connection.

If PowerShell complains about execution policy, set it for the current session only:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

Then dot-source again. No admin needed; only affects this PowerShell window.

### Option 2 — Open and copy-paste

Open the `.ps1` file in Notepad (or VS Code, or any editor). Select all (Ctrl+A), copy (Ctrl+C), paste into your PowerShell session. Slower but bypasses execution policy entirely.

### Option 3 — Direct invoke

```powershell
& "C:\Users\cjtucke3\Documents\Personal\Career\MANTLE\scripts\populate-equivalency-lookups.ps1"
```

Same caveats as Option 1 (execution policy may need bypass).

## Scripts in this folder

| File | Purpose |
|------|---------|
| `populate-equivalency-lookups.ps1` | Populates From-Tool / To-Tool Lookups on `Equivalency Map Real` |
| `add-missing-admin-tools.ps1` | Adds 4 admin tools (Google Workspace Admin, M365 Admin Center, Google Groups, Microsoft 365 Groups) to the Tools list |
| `backfill-admin-tools-metadata.ps1` | Backfills Category/Vendor/Description on the 4 added admin tools using the `field_1`/`field_2`/`field_3` internal names |
| `remove-duplicate-lookup-columns.ps1` | Removes the temporary `FromToolLookup`/`ToToolLookup` columns added during migration |

(More to come as we automate further.)
