# PA Replacement: Generate PC Cookbook

Companion to `scripts/generate-cookbook.ps1`. The script generates a personalized Word document for a given Project Coordinator. This document describes the Power Automate (plus Office Scripts / Word Online) flow that would replace it on a fully-licensed tenant.

## 1. What the script does today

A PC (or admin) runs `generate-cookbook.ps1 -PCName "Cherrelle Tucker"`. The script:

1. Resolves the PC by `-PCName` parameter, or by mapping the logged-in user's UPN to the `PCs.Email` column.
2. Pulls the matching Trainee Profile(s); if more than one, prompts the user to pick.
3. From the chosen profile, follows the cascade: PC details, Program details, Stakeholders/Meetings/Acronyms/Decisions tagged to that program, all 30-60-90 Tasks for that PC, and Equivalency Map filtered to the tools-they-came-from.
4. Opens a hidden Word.Application via COM, builds a structured document (cover page + section per data area, with native Word headings and tables), saves to a configurable `-OutputPath`, and releases the COM objects cleanly.
5. Prints a summary of counts and the output file path.

The artifact is meant to be downloadable, printable, and shareable with a new PC on day one.

## 2. Power Automate equivalent

PA on its own can't generate a Word document with rich styling — the typical pattern is **PA orchestration + an Office Script or Word Online "Populate a Microsoft Word template" connector**.

**Trigger:** *Manually trigger a flow* (button) with optional input `PC Name (text)`. Alternatively, *For a selected item* on the `Trainee Profiles` list so the PC can launch from the list view.

**Action sequence:**

1. **SharePoint — Get items** on `Trainee Profiles`, filter by PC display name (or by the selected item's ID).
2. **Compose** the resolved PC Id and Program Id from the profile's lookup fields.
3. Parallel branches of **SharePoint — Get items** for: `PCs` (single), `Programs` (single), `Stakeholders` (filter `Programs/Id eq {pid}`), `Meetings` (filter `Program/Id eq {pid}`), `Acronyms` (filter on Programs lookup OR no programs assigned), `Decisions Log`, `30-60-90 Tasks` (filter `PC/Id eq {pcid}`), `Equivalency Map` (filter `From-Tool/Id` in `varPrevTools`).
4. **Word Online (Business) — Populate a Microsoft Word template** action. You upload a `.docx` template to OneDrive/SharePoint with content controls (Plain Text / Repeating Section) for each placeholder; the action populates them with data from prior steps.
5. **OneDrive / SharePoint — Create file** to write the populated document to `Documents/Cookbooks/{PC name}_{date}.docx`.
6. **Office 365 Outlook — Send email** with the file attached, or just a link to the saved file.

**Connector requirements:** SharePoint (standard), Office 365 Outlook (standard), **Word Online (Business) — Premium** for `Populate a Microsoft Word template`.

**Premium connectors needed:** Yes — Word Online (Business) is premium. If premium licensing is unavailable, fall back to an **Office Script** invoked via the *Excel Online (Business) — Run script* action (premium too) or use a **child flow** that calls a custom connector pointing at a Graph API endpoint that opens, modifies, and saves the docx — more brittle.

## 3. Migration steps (script -> flow)

1. Build a `.docx` template by hand in Word: cover page + headings + content controls for every dynamic field. Add Repeating Section content controls around the table rows for Stakeholders, Meetings, Acronyms, etc.
2. Save to `SharePoint > KITCHEN > Templates > Cookbook.docx`.
3. Build the PA flow per the action sequence above. Use a single test PC end-to-end to validate.
4. Update the KITCHEN home page button "Generate my cookbook" to point at the flow's run-only URL instead of instructing users to open PowerShell.
5. Keep the script available as a fallback (e.g., when the flow's premium connector budget runs out, or for offline/disconnected use).

## 4. Trade-offs

| Dimension | Script | Flow |
|-----------|--------|------|
| Setup effort | Low (one .ps1 file) | High (template + flow + premium license) |
| Customization | Full control over Word layout | Constrained by Word content controls |
| Self-service for non-technical PCs | Requires PowerShell + COM | One-click button in Teams/SharePoint |
| Output fidelity | Native Word styles, tables, formatting | Same — but tables grow via Repeating Section |
| Tenant cost | Zero | Premium connector licensing |
| Portability | Runs anywhere with Word installed | Locked to PA tenant |

The script's biggest advantage is zero-license overhead; the flow's biggest advantage is removing PowerShell as a prerequisite for the user. For a small team (under ~10 active PCs), the script is probably good enough indefinitely. For org-wide rollout, the flow becomes worth the premium license.
