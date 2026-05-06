# MANTLE Update / Offboarding Page -- GUI Build Recipe

Manual, drag-and-drop SharePoint Modern build recipe for the MANTLE Update / Offboarding page. Target persona: a PC who is either (a) doing **quarterly maintenance** of their handoff data so the cookbook stays 80%+ ready, or (b) executing a **final handoff** before leaving the role or contract.

- **Site**: https://nasa.sharepoint.com/teams/PCTransitionSandbox
- **Site type**: Group-connected. OneColumn / TwoColumn / ThreeColumn / Vertical sections available.
- **Audience**: a single PC, executing manually in Modern Edit mode.
- **Web parts allowed**: native only (Hero, Text, Button, Quick Links, List, Image, Highlighted Content). No SPFx, no embed/script, no HTML hacks.

## Primary design principle

**Mirror the Onboarding recipe's middle sections.** Stakeholders, Meetings, and (here) Acronyms all reuse the exact same per-PC views and form CTAs as the Onboarding page, so a PC toggling between the two pages sees consistent UX. Differences live in the bookends: the hero framing at the top, and the Generate Cookbook closing action at the bottom.

Every working section pairs:

- An embedded LIST web part scoped to the current user (Owner = [Me] view, or Contract-filtered view) -- same view names as Onboarding.
- A clear CTA (Button) that opens the relevant LIST FORM (NewForm.aspx for new entries; clicking a row in the embedded list opens that item's EditForm).
- A short "what's changed?" prompt to nudge update behavior, not just additive entry.

Realistic expectation: native components produce a polished but flat page. No gradients, no hovers, no animated counters. The mockup's colored accent bars and stacked card chrome will not reproduce -- the heading + paragraph + section emphasis carry the structure.

---

## Total estimated build time

**~110-130 minutes** end to end (assumes Onboarding pre-work views already exist; if not, add ~12 min).

- Pre-work (theme check, confirm per-PC views, identify own PC ID, create page): ~15 min
- Section 1 -- Hero scope band: ~6 min
- Section 2 -- Why this page exists: ~8 min
- Section 3 -- Phase 1 Stakeholders refresh: ~12 min
- Section 4 -- Phase 2 Meetings refresh: ~10 min
- Section 5 -- Phase 3 Acronyms (knowledge): ~10 min
- Section 6 -- Phase 4 Templates and forms: ~12 min
- Section 7 -- Final action: Generate cookbook: ~10 min
- Section 8 -- Cookbook readiness panel: ~10 min
- Section 9 -- How to refer back: ~5 min
- Section 10 -- Internal-use-only footer: ~3 min
- Publish + smoke test: ~6 min

---

## Section plan at a glance

| # | Section template | Emphasis | Web parts | Purpose |
|---|---|---|---|---|
| 1 | OneColumn | Strong | Hero (Layers, 1 tile) | Hero + scope (refresh OR final handoff) |
| 2 | TwoColumn | None | Text + Image | Why this page exists |
| 3 | TwoColumn | None | Text + Button + List | Phase 1: Stakeholders refresh |
| 4 | TwoColumn | Neutral | Text + Button + List | Phase 2: Meetings refresh |
| 5 | TwoColumn | None | Text + Button + List | Phase 3: Acronyms (knowledge) |
| 6 | TwoColumn | Neutral | Text + Highlighted Content (or Quick Links) | Phase 4: Templates and forms |
| 7 | OneColumn | Strong | Text + Button | Final step: Generate cookbook |
| 8 | OneColumn | Soft | Text + List(s) | Cookbook readiness panel |
| 9 | OneColumn | Soft | Text + Quick Links | How to refer back |
| 10 | OneColumn | Soft | Text | Internal-use-only footer |

---

## PRE-WORK

### P0. Apply the Barrios theme (~2 min)

1. Gear -> **Change the look** -> **Theme**. Pick Barrios if published, otherwise the closest built-in (Blue). Save.
2. See `page-recipe-home.md` PRE-WORK for the full theme decision -- reuse here.

### P1. Confirm the per-PC filtered views exist (~3 min)

This page reuses the same `My Stakeholders`, `My Meetings`, and (new) `My Acronyms` views as Onboarding. If you already built the Onboarding recipe, the first two are done.

- `My Stakeholders` on Stakeholders -- filter `Owner is equal to [Me]`. See Onboarding P2a.
- `My Meetings` on Meetings -- filter `Contract is equal to {your contract title}`. See Onboarding P2b.
- `My Acronyms` on Acronyms -- NEW. Steps below in P2.

### P2. Create `My Acronyms` view on Acronyms list (~4 min)

The schema script added a `Contract` lookup to Acronyms. Create a per-contract view.

1. Open `/Lists/Acronyms/AllItems.aspx`.
2. Top-right view dropdown -> **Create new view**.
3. Name: `My Acronyms`. Type: **List**. Public: **Yes**. Click **Create**.
4. **Filter**: `Contract is equal to {your contract title}` (e.g., `IMPACT`). If you maintain a universal acronym set as well, change to `Contract is equal to {your contract} OR Contract is empty`.
5. Sort: Title ascending.
6. Visible columns: Title, Expansion, Context, Contract, Modified.
7. Save. Copy the view URL for Section 5.

### P3. Identify your own PC record ID (~3 min)

Only used by Section 8 (Cookbook readiness) if you choose to deep-link to your own PC EditForm rather than the list view. Same procedure as Onboarding P1: open `/Lists/PCs/AllItems.aspx`, find your row, note the `ID=N` from the DispForm URL.

### P4. Create (or reuse) the Update-Offboarding page (~3 min)

1. Gear -> **Site contents** -> **Site Pages**.
2. If a page named `Offboarding` or `Update-Offboarding` already exists with HTML hacks: rename it `[ARCHIVED] Offboarding (HTML)` and create a new one. Do not delete yet.
3. **+ New** -> **Site page** -> **Blank** -> **Create page**.
4. Title: `Update-Offboarding`.
5. Title-area panel: Layout = **Plain**. Show published date = Off. Show topic header = Off.
6. **Save as draft**.

---

## SECTION 1 -- Hero scope band

Mockup reference: Update/Offboarding S1 + S2 collapsed. Establishes "two reasons you might be here" framing.

- **Section template**: OneColumn
- **Section emphasis**: **Strong** (navy fill)
- **Web parts**: 1x **Hero**

### Steps

1. Click **+** at the top of the canvas -> **One column**.
2. Section settings pencil -> **Section background**: **Strong**. Vertical alignment: Top.
3. Inside the section, click **+** -> search `Hero` -> **Hero**.
4. Click the Hero -> edit pencil. Right panel:
   - **Layout**: **Layers**.
   - **Number of layers**: **1**.
5. Click the single hero tile -> Details pane:
   - **Image**: upload or link a wide, dark, low-detail banner. Site Assets is fine. (Reuse a different image than Onboarding so the two pages feel distinct.)
   - **Title**: `Update / Offboarding`
   - **Subtitle**: `Refresh your handoff data, or capture remaining knowledge before you go.`
   - **Call to action**: Off (each phase section has its own CTA).
   - **Show topic**: optional. If on: `QUARTERLY MAINTENANCE . FINAL HANDOFF . COOKBOOK READY`
6. Close the panel.

**Why this works**: the Hero web part is the only native component that produces a true full-bleed banner; Strong section emphasis frames the page as a deliberate, contract-sensitive workflow.

**Time**: ~6 min.

---

## SECTION 2 -- Why this page exists

Short explainer. Sets the maintenance-vs-handoff frame in plain language.

- **Section template**: TwoColumn
- **Section emphasis**: None
- **Web parts**: Left = **Text**. Right = **Image**.

### Steps

1. Below Section 1, **+** -> **Two columns** -> emphasis **None**.
2. **Left column** -> **+** -> **Text**:
   - Style **Heading 4** (eyebrow): `WHY THIS PAGE EXISTS`
   - Style **Heading 2**: `Your replacement should not be guessing`
   - Style **Normal**: `Whether you are moving to another contract or fully leaving the role, the people you have worked with and the meetings you ran do not have to be re-learned from scratch.`
   - Style **Normal**: `This page is also for quarterly maintenance. Keep your records fresh so when handoff comes, your cookbook is already 80% written.`
3. **Right column** -> **+** -> **Image**.
   - Upload (or link from Site Assets) a calm, neutral image. Suggested: a handoff conversation, a desk-side meeting, or an open notebook. 800x500 minimum.
   - Alt text: `Two coordinators in conversation during a handoff.`

**Why this works**: a soft two-column intro section orients the user without yet asking them to do anything -- it is the bridge from the hero to the work.

**Time**: ~8 min.

---

## SECTION 3 -- Phase 1: Stakeholders refresh

Mirrors Onboarding Step 4 (Stakeholders) section-for-section. Same view, same NewForm CTA. Adds a "what's changed?" prompt.

- **Section template**: TwoColumn
- **Section emphasis**: None
- **Web parts**: Left = **Text** + **Button**. Right = **List** (Stakeholders, `My Stakeholders` view).

### Steps

1. **+** -> **Two columns** -> emphasis **None**.
2. **Left column** -> **Text**:
   - Heading 4: `PHASE 1 OF 4`
   - Heading 2: `Stakeholders -- capture working styles for everyone you work with`
   - Normal: `On the right are the stakeholders you own. Click any name to open that person's record and update working-style answers as the relationship evolves. The form will reuse your last saved answers as a starting point.`
   - Normal: `If a stakeholder is missing, add them with the button below. The form asks for name, role, contract, and the same Working Styles Matrix questions you answered for yourself.`
   - Heading 4: `WHAT HAS CHANGED SINCE YOUR LAST REVIEW?`
   - Bulleted list (Normal):
     - `New people who joined your contract this quarter`
     - `Stakeholders whose role or org has shifted`
     - `Working-style preferences that have evolved (decision timing, channel, deep-work pattern)`
     - `Stakeholders who left -- mark Status = Inactive in their EditForm rather than deleting`
3. **Button** below the Text:
   - **Label**: `Add a stakeholder`
   - **Link**: `https://nasa.sharepoint.com/teams/PCTransitionSandbox/Lists/Stakeholders/NewForm.aspx`
   - **Alignment**: Left.
4. **Right column** -> **List**.
   - Pick **Stakeholders**.
   - **List view**: `My Stakeholders` (filter `Owner = [Me]`).
   - **Title displayed**: `Your stakeholders`
   - **Show command bar**: Off.
   - **Show toolbar**: See all (so the user can click through to the full list).
   - Visible columns: Title, Person, Role, Contracts, Modified.
5. Empty-state behavior is fine -- if no rows match, the user has clear "Add" guidance on the left.

**Why this works**: clicking any embedded row natively opens that item's display form -- one click further opens its EditForm, which IS the working-style update workflow. No custom code needed.

**Time**: ~12 min.

---

## SECTION 4 -- Phase 2: Meetings refresh

Mirrors Onboarding Step 5 (Meetings). Same view, same NewForm CTA. Adds deprecation guidance.

- **Section template**: TwoColumn
- **Section emphasis**: Neutral
- **Web parts**: Left = **Text** + **Button**. Right = **List** (Meetings, `My Meetings` view).

### Steps

1. **+** -> **Two columns** -> emphasis **Neutral**.
2. **Left column** -> **Text**:
   - Heading 4: `PHASE 2 OF 4`
   - Heading 2: `Meetings -- keep the catalog current`
   - Normal: `Meetings come and go. Standups split, working sessions end, new review cycles spin up. Make sure the right-hand list reflects what your contract actually runs today.`
   - Normal: `Click any meeting to open its EditForm and update cadence, owner, your role, or the agenda link. Add new meetings with the button below.`
   - Heading 4: `MARK A MEETING AS DEPRECATED`
   - Normal: `If a meeting no longer happens, do not delete the row -- open its EditForm and set Status = Deprecated (or add "[DEPRECATED]" to the Title if Status does not exist yet). Keeps the historical record for the next PC.`
3. **Button**:
   - **Label**: `Add a meeting`
   - **Link**: `https://nasa.sharepoint.com/teams/PCTransitionSandbox/Lists/Meetings/NewForm.aspx`
4. **Right column** -> **List**.
   - Pick **Meetings**.
   - **List view**: `My Meetings` (Contract-filtered).
   - **Title displayed**: `Meetings on your contract`
   - **Show toolbar**: See all.
   - Visible columns: Title, Cadence, Contract, Person/Owner, Modified.

**Why this works**: same form-and-list pairing as Onboarding -- the user does not have to learn a new pattern, just a new framing.

**Time**: ~10 min.

---

## SECTION 5 -- Phase 3: Knowledge (Acronyms)

NEW for Update/Offboarding -- the unwritten parts. Decisions Log was dropped from the architecture; this phase captures acronyms only.

- **Section template**: TwoColumn
- **Section emphasis**: None
- **Web parts**: Left = **Text** + **Button**. Right = **List** (Acronyms, `My Acronyms` view).

### Steps

1. **+** -> **Two columns** -> emphasis **None**.
2. **Left column** -> **Text**:
   - Heading 4: `PHASE 3 OF 4`
   - Heading 2: `Knowledge -- acronyms and unwritten rules`
   - Normal: `Your replacement will hear contract-specific acronyms in week one. The right-hand list is what you have captured for this contract. Add anything missing -- especially the ones that mean something different here than they do elsewhere at NASA or at Barrios.`
   - Normal: `Click any acronym to open its EditForm and refine the expansion or context. Add new acronyms with the button below.`
   - Italic: `Tip: each time you catch yourself defining an acronym in a meeting, that is one to add here.`
3. **Button**:
   - **Label**: `Add an acronym`
   - **Link**: `https://nasa.sharepoint.com/teams/PCTransitionSandbox/Lists/Acronyms/NewForm.aspx`
4. **Right column** -> **List**.
   - Pick **Acronyms**.
   - **List view**: `My Acronyms` (Contract-filtered, from Pre-work P2).
   - **Title displayed**: `Acronyms on your contract`
   - **Show toolbar**: See all.
   - Visible columns: Title, Expansion, Context, Contract, Modified.

**Why this works**: same pattern as Phases 1 and 2 -- a contract-scoped list view plus a NewForm button. The user's mental model is fully transferred from the previous two sections.

**Time**: ~10 min.

---

## SECTION 6 -- Phase 4: Templates and forms

Reference materials. Surface the Word templates and one-pagers a PC needs while doing handoff.

- **Section template**: TwoColumn
- **Section emphasis**: Neutral
- **Web parts**: Left = **Text**. Right = **Highlighted Content** (or **Quick Links** as fallback).

### Steps

1. **+** -> **Two columns** -> emphasis **Neutral**.
2. **Left column** -> **Text**:
   - Heading 4: `PHASE 4 OF 4`
   - Heading 2: `Templates and reference docs`
   - Normal: `Word templates and one-pagers to support the work in Phases 1-3. Tag any document in the Documents library with the keyword "Offboarding" to surface it here automatically.`
   - Bulleted list (Normal):
     - `Stakeholder handoff template -- one-page Word doc for capturing a stakeholder profile`
     - `Meeting cheat-sheet -- two-page Word doc summarizing a recurring meeting and its unwritten rules`
     - `Decisions one-pager -- one-page Word doc for documenting a settled decision and reasoning`
3. **Right column** -> **+** -> **Highlighted Content**.
   - **Source**: This site.
   - **Type**: Documents.
   - **Filter**: **Managed property** -> add a filter where **Tags** (or **Keywords**) **Equals** `Offboarding`. If your tenant exposes the simpler filter UI, use **Title** **contains** `Offboarding` instead.
   - **Sort**: Most recent.
   - **Layout**: List (compact). Items to show: 6.
   - **Title**: `Offboarding templates`
4. **Fallback if Highlighted Content is unavailable or returns nothing**: replace with a **Quick Links** web part, Layout **List**, Title `Offboarding templates`. Click **+ Add links** for each:
   - `Stakeholder handoff template` -> direct URL of the Word file in your Documents library.
   - `Meeting cheat-sheet` -> direct URL.
   - `Decisions one-pager` -> direct URL.
   - `Cookbook generator script (reference)` -> URL to `scripts/generate-cookbook.ps1` if mirrored to a Documents library, or to the MANTLE Actions page.

**Why this works**: Highlighted Content gives a self-maintaining list when the documents library is tagged correctly; Quick Links is the reliable fallback when tagging is not yet set up.

**Time**: ~12 min.

---

## SECTION 7 -- Final action: Generate the cookbook

The unique closing action. The Onboarding page does not have this; the Update/Offboarding page exists for it.

- **Section template**: OneColumn
- **Section emphasis**: **Strong**
- **Web parts**: 1x **Text** + 1x **Button**.

### Steps

1. **+** -> **One column** -> emphasis **Strong**.
2. **+** -> **Text**:
   - Heading 4 (eyebrow, will read as light text on Strong navy): `FINAL STEP`
   - Heading 2: `Generate the cookbook`
   - Normal: `Once you have refreshed your data in Phases 1-3, generate the Word document that hands everything off to your replacement. The cookbook pulls Stakeholders, Meetings, Acronyms, and your Working Styles into one file.`
   - Normal: `Recommended completeness rule: aim for 60%+ of your stakeholders to have working-style profiles (PrimaryChannel filled at minimum) before generating. Below that threshold the cookbook is mostly skeleton.`
3. **Button** below the Text:
   - **Label**: `Open MANTLE Actions`
   - **Link**: paste the URL of your MANTLE Actions page (the page that documents the cookbook generator). Format example: `https://nasa.sharepoint.com/teams/PCTransitionSandbox/SitePages/MANTLE-Actions.aspx`.
   - **Alignment**: Left.
4. **Alternative wording** if you (the owner) run the generator script directly from your laptop and there is no MANTLE Actions page yet, replace the Button label and add a second Text block:
   - Button label: `View generator script`
   - Button link: URL to `scripts/generate-cookbook.ps1` in the MANTLE GitHub repo (`https://github.com/CherrelleTucker/MANTLE/blob/main/scripts/generate-cookbook.ps1`).
   - Add a Text block below the button with the exact PowerShell command in a code block (Heading 4 `RUN LOCALLY`, then Normal):
     - `Connect-PnPOnline -Url https://nasa.sharepoint.com/teams/PCTransitionSandbox -UseWebLogin`
     - `.\generate-cookbook.ps1`
     - `(omit -PCName to auto-resolve to the current Windows user; cookbook saves to C:\Users\<you>\Documents\Personal\Career\MANTLE\cookbooks\)`

**Why this works**: Strong navy section with a single prominent Button is the visual anchor of the page. The user does not have to scroll past clutter to find the closing action.

**Time**: ~10 min.

---

## SECTION 8 -- Cookbook readiness panel

Lightweight progress indicator so the PC knows whether they are ready to generate.

- **Section template**: OneColumn
- **Section emphasis**: Soft
- **Web parts**: 1x **Text** + 2-4x **List** (count-only views).

Native list web parts can show item counts in the toolbar but cannot natively render a "23 / 30" progress widget. Two options below; pick one.

### Option A (recommended): show small lists with counts visible

1. **+** -> **One column** -> emphasis **Soft**.
2. **+** -> **Text**:
   - Heading 3: `Cookbook readiness`
   - Normal: `Use these counts to gauge whether you are ready to generate. Targets are guidelines, not gates.`
   - Bulleted list (Normal):
     - `Stakeholders captured: aim for 12+`
     - `Working styles documented (PrimaryChannel filled): aim for 60% of stakeholders`
     - `Meetings catalogued: aim for every recurring meeting on your calendar`
     - `Acronyms: aim for 15+ contract-specific entries`
3. Below the Text, drop **List** web parts side-by-side (use a Three-column section nested inside, or a single One-column with stacked Lists). For each list:
   - Pick the relevant list (Stakeholders, Meetings, Acronyms).
   - **List view**: the per-PC view created in Pre-work.
   - **Show toolbar**: Compact. The toolbar will display "Showing N items" -- that is your count.
   - **Items per page**: 5 (keeps the panel short).
   - **Title displayed**: `Stakeholders (count)`, `Meetings (count)`, `Acronyms (count)` respectively.

### Option B (simpler): pure-text manual readiness checklist

If embedding three List web parts feels heavy, use a single Text web part with manual instructions:

1. **+** -> **One column** -> emphasis **Soft**.
2. **+** -> **Text**:
   - Heading 3: `Cookbook readiness`
   - Normal: `Open each list and check the count in the upper toolbar. You are ready to generate when:`
   - Numbered list:
     - `Stakeholders -> at least 12 rows where Owner = you`
     - `Stakeholders -> at least 60% have PrimaryChannel filled`
     - `Meetings -> every recurring meeting on your calendar appears`
     - `Acronyms -> at least 15 contract-specific entries`
   - Normal: `Below the threshold? Spend another 30 minutes in Phase 1 before generating -- the resulting cookbook will be much stronger.`

**Why this works**: SharePoint native cannot do live progress bars without SPFx, so we either expose the count via the toolbar (Option A) or hand the user a checklist (Option B). Both are honest about the platform's limits and still give the PC a clear go/no-go signal.

**Time**: ~10 min.

---

## SECTION 9 -- How to refer back

A PC will return to this page each quarter for maintenance. Tell them how. Mirrors Onboarding Section 7.

- **Section template**: OneColumn
- **Section emphasis**: Soft
- **Web parts**: 1x **Text** + 1x **Quick Links** (List layout).

### Steps

1. **+** -> **One column** -> emphasis **Soft**.
2. **+** -> **Text**:
   - Heading 3: `How to find this page again`
   - Normal: `You will refer back to this page every quarter and again when handoff is imminent. Three ways to come back fast:`
   - Numbered list:
     - `Bookmark this page in your browser as "MANTLE Update / Offboarding".`
     - `Pin this URL to your favorites bar.`
     - `Use the Quick Launch nav on the left -- "Update-Offboarding" is listed there.`
   - Normal: `Each list also has a "My ..." view, so you can hop straight to your own records:`
3. Below the Text, **+** -> **Quick Links** -> Layout **List**. Title: `Your shortcuts`. Click **+ Add links** for each:
   - `My Stakeholders` -> URL of `My Stakeholders` view from Onboarding P2a.
   - `My Meetings` -> URL of `My Meetings` view from Onboarding P2b.
   - `My Acronyms` -> URL of `My Acronyms` view from Pre-work P2.
   - `My PC Record (Working Styles)` -> `/Lists/PCs/EditForm.aspx?ID=N` (your ID from P3).
   - `MANTLE Actions (cookbook generator)` -> URL of MANTLE Actions page.

**Why this works**: a soft-tinted recap section explicitly reinforces "this page is durable, here is how to come back" -- which is the entire point of the quarterly maintenance frame.

**Time**: ~5 min.

---

## SECTION 10 -- Internal-use-only footer

Trust signal. Same as Home recipe Section 7 and Onboarding Section 8.

- **Section template**: OneColumn
- **Section emphasis**: Soft
- **Web parts**: 1x **Text**.

### Steps

1. **+** -> **One column** -> emphasis **Soft**.
2. **+** -> **Text**. Single paragraph, center-aligned:
   - Bold: `Internal use only.`
   - Normal: ` Stakeholder relationship notes and internal decisions on this page are not for external sharing under any circumstance. Cookbooks generated from this data are also internal-only.`

**Why this works**: visual consistency with Home and Onboarding footers signals that the same trust posture applies across MANTLE.

**Time**: ~3 min.

---

## PUBLISH AND SMOKE TEST

1. Top right: **Publish**.
2. Optional: add this page to Quick Launch nav. Gear -> **Edit** the nav -> **+ Add link** -> Title `Update-Offboarding` -> URL of the published page.
3. In a fresh browser session, click each CTA button:
   - [ ] Add a stakeholder opens the Stakeholders NewForm.
   - [ ] Add a meeting opens the Meetings NewForm.
   - [ ] Add an acronym opens the Acronyms NewForm.
   - [ ] Open MANTLE Actions opens the actions page (or the generator script).
4. Verify each embedded List web part loads rows (or shows the expected empty state).
5. Click a row in the Stakeholders embedded list -> verify the item's display form opens, then click Edit -> verify the Working Styles Matrix fields render.
6. Confirm the Highlighted Content (Section 6) shows tagged Offboarding documents, OR that the Quick Links fallback resolves to real document URLs.
7. Hard-refresh the page to confirm published rendering.

**Time**: ~6 min.

---

## OPEN QUESTIONS FOR THE OWNER

1. **MANTLE Actions page**: Section 7's primary CTA assumes a MANTLE Actions page exists that documents how to run `generate-cookbook.ps1`. If no such page exists yet, use the alternative wording (link straight to the GitHub-hosted script and inline the PowerShell command). Decide before publishing.
2. **Acronyms Contract scoping**: `My Acronyms` filters by a single Contract. If the user works across multiple contracts, change the filter to `Contract IN (a, b, c)` or `Contract is empty OR Contract = {yours}` to include universal acronyms.
3. **Stakeholder Status field**: Section 3's "mark as Inactive" guidance assumes a Status column on Stakeholders. If it does not exist, either add it (Wave 2) or change the guidance to "add `[INACTIVE]` to the Title".
4. **Meeting Status field**: same question for Meetings -- does a Status (or Deprecated) column exist? Adjust Section 4 wording accordingly.
5. **Highlighted Content tagging**: Section 6 assumes Documents in the site library are tagged with `Offboarding`. If your tenant's library does not have a Tags / Keywords managed property exposed in the filter UI, fall back to Quick Links from the start.
6. **Cookbook readiness counts**: Section 8 Option A relies on the List web part toolbar showing a count. Some tenant configurations hide it when toolbar = Compact. Verify in your tenant; if hidden, switch to Option B.
7. **Per-PC view scoping when multiple PCs share the page**: same caveat as Onboarding -- Section 8's deep-link to your own PC EditForm uses a hard-coded ID. If multiple PCs share this page, swap for a Quick Link to `/Lists/PCs/AllItems.aspx?FilterField1=PCname&FilterValue1=[Me]` style filtering (or a per-user view) and let the user click into their own row.
8. **60% completeness rule**: stated in Sections 7 and 8 as a guideline. If you (owner) want this enforced, that requires a Power Automate flow or SPFx and is out of scope for this native-only recipe -- the rule lives only as guidance text.
