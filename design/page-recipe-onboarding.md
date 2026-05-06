# KITCHEN Onboarding Page -- GUI Build Recipe

Manual, drag-and-drop SharePoint Modern build recipe for the KITCHEN Onboarding page. Target persona: a NEW PC arriving to KITCHEN who does not know what the previous PC left behind, does not want to edit list grids directly, and wants to FILL OUT FORMS to capture and review their onboarding context.

- **Site**: https://nasa.sharepoint.com/teams/PCTransitionSandbox
- **Site type**: Group-connected. OneColumn / TwoColumn / ThreeColumn / Vertical section available.
- **Audience**: a single PC, executing manually in Modern Edit mode.
- **Web parts allowed**: native only (Hero, Text, Button, Quick Links, List, Call to Action, Image, People). No SPFx, no embed/script, no HTML hacks.

## Primary design principle

Forms-driven onboarding. Every step pairs:

- A clear CTA (Button or Quick Link) that opens the relevant LIST FORM (NewForm.aspx for new entries, EditForm.aspx for the user's own existing record).
- An embedded LIST web part scoped to the current user (Owner = [Me] view, or Contract-filtered view), so they can see what is already captured.
- Default SharePoint click-through: clicking any row opens that item's display/edit form. That click-into IS the "interview a stakeholder" workflow.

Realistic expectation: native components produce a polished but flat page. No gradients, no hovers, no animated counters. The mockup's colored accent bars and rounded card chrome will not reproduce -- the heading + paragraph + section emphasis carry the structure.

---

## Total estimated build time

**~95-115 minutes** end to end.

- Pre-work (theme check, find own PC ID, create per-PC views, create the page): ~25 min
- Section 1 -- Hero scope band: ~6 min
- Section 2 -- Step 1 Trainee Profile: ~10 min
- Section 3 -- Step 2 Working Styles Matrix (PCs EditForm): ~10 min
- Section 4 -- Step 3 Tools: ~10 min
- Section 5 -- Step 4 Stakeholders: ~12 min
- Section 6 -- Step 5 Meetings: ~10 min
- Section 7 -- How to refer back: ~5 min
- Section 8 -- Internal-use-only footer: ~3 min
- Publish + smoke test: ~5 min

---

## Section plan at a glance

| # | Section template | Emphasis | Web parts | Purpose |
|---|---|---|---|---|
| 1 | OneColumn | Strong | Hero (Layers, 1 tile) | Welcome + scope |
| 2 | TwoColumn | None | Text + Button + List | Step 1: Trainee Profile form |
| 3 | TwoColumn | Neutral | Text + Button | Step 2: Working Styles Matrix (own PC EditForm) |
| 4 | TwoColumn | None | Text + List + Button | Step 3: Tools |
| 5 | TwoColumn | None | Text + List + Button | Step 4: Stakeholders (interview workflow) |
| 6 | TwoColumn | Neutral | Text + List + Button | Step 5: Meetings |
| 7 | OneColumn | Soft | Text + Quick Links | How to refer back |
| 8 | OneColumn | Soft | Text | Internal-use-only footer |

---

## PRE-WORK

### P0. Apply the Barrios theme (~2 min)

1. Gear -> **Change the look** -> **Theme**. Pick the Barrios theme if published, otherwise the closest built-in (Blue). Save.
2. See `page-recipe-home.md` PRE-WORK for the full theme conversation -- reuse the same decision here.

### P1. Identify your own PC record ID (~5 min)

The Step 2 CTA needs to deep-link to YOUR PC record's EditForm (so the user does not have to hunt for their own row).

1. Open `https://nasa.sharepoint.com/teams/PCTransitionSandbox/Lists/PCs/AllItems.aspx`.
2. Find the row whose **Coordinator Name** column is your own AD account. If none exists, click **+ New**, fill in Title and Coordinator Name = yourself, save. Note the new row's ID.
3. To find an existing row's ID: hover the row, click the row's "..." menu -> **Properties**. The browser URL bar now shows `...DispForm.aspx?ID=N`. Note N.
4. Save N somewhere -- it gets pasted into Section 3's CTA URL.

**Open question for owner**: if multiple PCs share this site, every PC's onboarding page would need a different ID. For v1, this page is single-user; if you later need a shared page, replace the deep-link with a Quick Link to `/Lists/PCs/AllItems.aspx` filtered to "Coordinator Name = [Me]" (a per-user view) and let the user click into their own row.

### P2. Create per-PC filtered views (~12 min total)

The Stakeholders, Meetings, and Tools embedded views all need per-PC scoping. Use the `[Me]` token in list view filters. Repeat the pattern below for each list.

#### P2a. Stakeholders -- `My Stakeholders` view (~4 min)

1. Open `/Lists/Stakeholders/AllItems.aspx`.
2. Top-right view dropdown -> **Create new view**.
3. Name: `My Stakeholders`. Type: **List**. Public: **Yes**. Click **Create**.
4. In the new view, click the **Filter** funnel icon -> **Owner** -> set filter `Owner is equal to [Me]`. (If Owner does not exist on Stakeholders, fall back to **Created By** = `[Me]`. Owner is preferred because the schema script's pattern uses Owner for per-PC scoping.)
5. Sort by **Modified** descending.
6. Visible columns: Title, Person, Role, Contracts, Modified.
7. Click **Save view as** -> overwrite `My Stakeholders`.
8. Copy the URL of this view (full URL from address bar). Save it for Section 5.

#### P2b. Meetings -- `My Meetings` view (~4 min)

Meetings has a Contract lookup but not an Owner column directly. Two options:

- **Option A (recommended)**: Filter by `Contract` = the contract the user is assigned to. Static per build.
- **Option B**: Filter by `Created By` = `[Me]` (only shows meetings the user themselves added).

Use Option A for v1. Steps:

1. Open `/Lists/Meetings/AllItems.aspx`.
2. New view: `My Meetings`. List, Public.
3. Filter: `Contract is equal to {your contract title}` (e.g., `IMPACT`).
4. Sort: Title ascending.
5. Visible: Title, Cadence, Contract, Person/Owner, Modified.
6. Save and copy the URL.

#### P2c. Tools -- `My Tools` view (~4 min)

Tools has no per-PC ownership column in Wave 1 schema. Filter by Contract IF a Tools-Contract column exists; otherwise show all Tools and accept the wider scope.

1. Open `/Lists/Tools/AllItems.aspx`.
2. Check whether Tools has a Contract column. If yes, create a `My Tools` view filtered to your contract. If no, skip view creation and use the default `All Items` in Section 4.
3. If a view is created, copy its URL.

**Open question for owner**: does Tools currently have a Contract or Contracts column? If not, decide whether Wave 2 should add one, OR whether the Onboarding page should just show all Tools with a "browse the inventory" framing.

### P3. Create (or rename) the Onboarding page (~3 min)

1. Gear -> **Site contents** -> **Site Pages**.
2. If a page named `Onboarding` already exists with HTML hacks: rename it `[ARCHIVED] Onboarding (HTML)` and create a new one. Do not delete yet.
3. **+ New** -> **Site page** -> **Blank** -> **Create page**.
4. Title: `Onboarding`.
5. Title-area panel: Layout = **Plain**. Show published date = Off. Show topic header = Off.
6. **Save as draft**.

---

## SECTION 1 -- Hero scope band

Mockup reference: Onboarding page S1 + S2 collapsed. Welcomes the new PC and states the scope.

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
   - **Image**: upload or link a wide, dark, low-detail banner. Site Assets is fine.
   - **Title**: `Welcome to KITCHEN Onboarding`
   - **Subtitle**: `You are being onboarded as a Project Coordinator for your assigned contract. Walk through the five steps below.`
   - **Call to action**: Off (each step section has its own CTA).
   - **Show topic**: optional. If on: `KNOWLEDGE . INTERVIEWS . TRANSITIONS . COOKBOOKS . HANDOFFS . EQUIVALENCIES . NETWORK`
6. Close the panel.

**Why this works**: the Hero web part is the only native component that renders a true full-bleed banner at the top of a Modern page; Strong section emphasis gives it the brand-deep backdrop.

**Time**: ~6 min.

---

## SECTION 2 -- Step 1: Tell us about you (Trainee Profile)

- **Section template**: TwoColumn
- **Section emphasis**: None
- **Web parts**: Left = **Text** + **Button**. Right = **List** (Trainee Profiles).

### Steps

1. Below Section 1, **+** -> **Two columns** -> emphasis **None**.
2. **Left column** -> **+** -> **Text**. Type:
   - Style **Heading 4** (acts as eyebrow): `STEP 1 OF 5`
   - Style **Heading 2**: `Set up your Trainee Profile`
   - Style **Normal**: `Tell KITCHEN who you are. The Trainee Profile captures your name, contract assignment, start date, mentor, and the basics your manager and other PCs need to find you. This takes about 3 minutes.`
   - **Normal**: `Click the button below to open the Trainee Profile form. After you save, your record will appear in the panel on the right.`
3. Below the Text web part (still in left column), **+** -> **Button**. In the panel:
   - **Label**: `Open Trainee Profile form`
   - **Link**: `https://nasa.sharepoint.com/teams/PCTransitionSandbox/Lists/Trainee%20Profiles/NewForm.aspx`
   - **Alignment**: Left.
   - Tip: tick **Open in a new tab** if available; if not, accept default behavior.
4. **Right column** -> **+** -> **List**.
   - Pick **Trainee Profiles**.
   - **List view**: pick `All Items` (or create a `Mine` view in the Trainee Profiles list filtered `Created By = [Me]` for cleaner display).
   - **Title displayed**: `Your Trainee Profile`
   - **Show command bar**: Off.
   - **Show toolbar**: See all (so the user can click through to the full list).

**Why this works**: the Button is the most prominent native call-to-action; the List web part shows the user the result of submitting the form, closing the loop.

**Time**: ~10 min.

---

## SECTION 3 -- Step 2: Working Styles Matrix interview (own PC record)

- **Section template**: TwoColumn
- **Section emphasis**: Neutral
- **Web parts**: Left = **Text** + **Button**. Right = **Text** (instructions panel).

The PCs list holds 23 working-style fields per the Wave 1 schema. The user fills in those answers by editing their own PC row.

### Steps

1. Below Section 2, **+** -> **Two columns** -> emphasis **Neutral**.
2. **Left column** -> **Text**:
   - Heading 4: `STEP 2 OF 5`
   - Heading 2: `Tell us how you work`
   - Normal: `KITCHEN captures 21+ working-style answers per person -- communication channels, decision timing, deep-work habits, feedback preferences, conflict defaults, and more. Your answers help your contract teammates work with you on day one.`
   - Normal: `Plan for 10-15 minutes. Save as you go; the form lets you return later.`
3. **Button** below the Text:
   - **Label**: `Open Working Styles Matrix form`
   - **Link**: paste your PC EditForm URL. Format: `https://nasa.sharepoint.com/teams/PCTransitionSandbox/Lists/PCs/EditForm.aspx?ID=N` where N is the ID you noted in Pre-work P1.
   - If the user has no PC row yet, paste `https://nasa.sharepoint.com/teams/PCTransitionSandbox/Lists/PCs/NewForm.aspx` instead and instruct them to set Coordinator Name = themselves.
4. **Right column** -> **Text**:
   - Heading 4: `WHAT THE FORM ASKS`
   - Bulleted list (Normal):
     - `Primary and secondary preferred channel`
     - `How you leave and receive edits in shared files`
     - `Decision timing -- yours and others'`
     - `Deep-work style and rabbit-trail tendency`
     - `Feedback and recognition preferences`
     - `Conflict default move`
   - Italic: `If a question doesn't apply, leave it blank. You can update any answer later.`

**Why this works**: deep-linking to the user's own EditForm removes the "find your row in a grid" cognitive load -- they get a form, not a list.

**Time**: ~10 min.

---

## SECTION 4 -- Step 3: Tools you'll be using

- **Section template**: TwoColumn
- **Section emphasis**: None
- **Web parts**: Left = **Text** + **Button** (Browse all Tools). Right = **List** (Tools).

### Steps

1. **+** -> **Two columns** -> emphasis **None**.
2. **Left column** -> **Text**:
   - Heading 4: `STEP 3 OF 5`
   - Heading 2: `What's in your toolkit`
   - Normal: `Below is the inventory of tools your contract uses -- communication, document management, scheduling, ticketing, automation. Treat this as your "what does my team actually run on" map.`
   - Normal: `Click any tool to open its full record (description, equivalents, access path).`
3. **Button**:
   - **Label**: `Browse all Tools`
   - **Link**: `https://nasa.sharepoint.com/teams/PCTransitionSandbox/Lists/Tools/AllItems.aspx`
4. **Right column** -> **List**.
   - Pick **Tools**.
   - **List view**: `My Tools` if created in Pre-work P2c, else `All Items`.
   - **Title displayed**: `Your contract's tools`
   - **Show toolbar**: See all.
   - **Show command bar**: Off.

**Why this works**: read-only inventory in the right column, clear "go deeper" CTA in the left column. No form-fill is expected of the user here -- Tools are catalogued by admins.

**Time**: ~10 min.

---

## SECTION 5 -- Step 4: Your stakeholders (interview workflow)

- **Section template**: TwoColumn
- **Section emphasis**: None
- **Web parts**: Left = **Text** + **Button** (Add Stakeholder). Right = **List** (Stakeholders, `My Stakeholders` view).

This is the core interview pattern. The user sees who the previous PC left behind, clicks any row to open the EditForm, and fills in working-style answers AS the interview happens.

### Steps

1. **+** -> **Two columns** -> emphasis **None**.
2. **Left column** -> **Text**:
   - Heading 4: `STEP 4 OF 5`
   - Heading 2: `Who you'll work with`
   - Normal: `Anyone listed on the right is someone you should interview using the Working Styles Matrix questions. Click a name to open that person's record and capture their answers as you go.`
   - Normal: `If a stakeholder is missing, add them with the button below. The form will ask for their name, role, contract, and the same matrix questions you answered in Step 2.`
   - Italic: `Tip: schedule a 30-minute "how do you work" call with each stakeholder in your first two weeks. Use that meeting to fill in the form together.`
3. **Button**:
   - **Label**: `Add a new Stakeholder`
   - **Link**: `https://nasa.sharepoint.com/teams/PCTransitionSandbox/Lists/Stakeholders/NewForm.aspx`
4. **Right column** -> **List**.
   - Pick **Stakeholders**.
   - **List view**: `My Stakeholders` (created in Pre-work P2a, filter `Owner = [Me]`).
   - **Title displayed**: `Your stakeholders`
   - **Show toolbar**: See all.
   - Visible columns confirmed in the view: Title, Person, Role, Contracts, Modified.
5. Empty state: if `My Stakeholders` is empty for a brand-new PC, the List web part will show "No items match your view." Acceptable -- the prominent button makes the next action obvious.

**Why this works**: clicking any embedded row natively opens that item's display form; from there the user clicks Edit to capture answers. No custom code needed -- this IS the interview workflow.

**Time**: ~12 min.

---

## SECTION 6 -- Step 5: Your meetings

- **Section template**: TwoColumn
- **Section emphasis**: Neutral
- **Web parts**: Left = **Text** + **Button** (Add a meeting). Right = **List** (Meetings, `My Meetings` view).

### Steps

1. **+** -> **Two columns** -> emphasis **Neutral**.
2. **Left column** -> **Text**:
   - Heading 4: `STEP 5 OF 5`
   - Heading 2: `Recurring meetings on your radar`
   - Normal: `These are the meetings your contract runs on cadence -- standups, status calls, reviews, working sessions. Sit in on each one once before participating.`
   - Normal: `If a meeting is missing, add it with the button below. Capture cadence, who runs it, your role (lead / co-lead / participant), and where the agenda lives.`
3. **Button**:
   - **Label**: `Add a meeting`
   - **Link**: `https://nasa.sharepoint.com/teams/PCTransitionSandbox/Lists/Meetings/NewForm.aspx`
4. **Right column** -> **List**.
   - Pick **Meetings**.
   - **List view**: `My Meetings` (Contract-filtered, from Pre-work P2b).
   - **Title displayed**: `Meetings on your contract`
   - **Show toolbar**: See all.

**Why this works**: same form-and-list pairing as Stakeholders. Meetings is a smaller catalogue and updates less often, so the right column reads like a reference card.

**Time**: ~10 min.

---

## SECTION 7 -- How to refer back

A new PC will want to come back to this page repeatedly during their first month. Tell them how.

- **Section template**: OneColumn
- **Section emphasis**: Soft
- **Web parts**: 1x **Text** + 1x **Quick Links** (List layout).

### Steps

1. **+** -> **One column** -> emphasis **Soft**.
2. **+** -> **Text**:
   - Heading 3: `How to find this page again`
   - Normal: `You will refer back to your onboarding context for weeks. Three ways to come back fast:`
   - Numbered list:
     - `Bookmark this page in your browser. Use a memorable name like "KITCHEN Onboarding".`
     - `Pin this URL to your favorites bar.`
     - `Use the Quick Launch nav on the left -- "Onboarding" is listed there.`
   - Normal: `Each list also has a "My ..." view, so you can hop straight to your own records:`
3. Below the Text, **+** -> **Quick Links** -> Layout **List**. Title: `Your shortcuts`. Click **+ Add links** for each:
   - `My Trainee Profile` -> URL of Trainee Profiles list (or your own DispForm if you noted the ID).
   - `My PC Record` -> `/Lists/PCs/EditForm.aspx?ID=N` (your own ID from P1).
   - `My Stakeholders` -> URL of `My Stakeholders` view from P2a.
   - `My Meetings` -> URL of `My Meetings` view from P2b.
   - `Tools inventory` -> Tools list URL.

**Why this works**: a soft-tinted recap section explicitly tells the user "this page is durable, here's how to come back." Quick Links gives a one-click route to each personal view.

**Time**: ~5 min.

---

## SECTION 8 -- Internal-use-only footer

Mirrors the Home recipe Section 7. Trust signal.

- **Section template**: OneColumn
- **Section emphasis**: Soft
- **Web parts**: 1x **Text**.

### Steps

1. **+** -> **One column** -> emphasis **Soft**.
2. **+** -> **Text**. Single paragraph, center-aligned:
   - Bold: `Internal use only.`
   - Normal: ` KITCHEN contains contract-sensitive context. Do not share pages or list exports outside Barrios or your contract team.`

**Why this works**: same Soft-emphasis Text web part as Home, for visual consistency.

**Time**: ~3 min.

---

## PUBLISH AND SMOKE TEST

1. Top right: **Publish**.
2. Optional: add this page to Quick Launch nav. Gear -> **Edit** the nav -> **+ Add link** -> Title `Onboarding` -> URL of the published page.
3. In a fresh browser session, click each CTA button:
   - [ ] Trainee Profile NewForm opens.
   - [ ] Working Styles Matrix EditForm opens to YOUR PC row.
   - [ ] Browse all Tools opens the Tools list.
   - [ ] Add a new Stakeholder opens the Stakeholders NewForm.
   - [ ] Add a meeting opens the Meetings NewForm.
4. Verify each embedded List web part loads rows (or shows the expected empty state with no errors).
5. Click a row in the Stakeholders embedded list -> verify the item's display form opens.
6. Hard-refresh the page to confirm published rendering.

**Time**: ~5 min.

---

## OPEN QUESTIONS FOR THE OWNER

1. **Multi-user reuse**: this page deep-links to one PC's EditForm via a hard-coded ID. If multiple PCs share this Onboarding page, swap the Step 2 button URL for `/Lists/PCs/AllItems.aspx` filtered to `Coordinator Name = [Me]` and add a note "click your own row to open the matrix." Decide before publishing whether this page is single-user or shared.
2. **Owner column on Stakeholders**: per-PC scoping for `My Stakeholders` assumes each Stakeholder row has an Owner person column whose value is the responsible PC. Confirm Owner exists; if it does not, fall back to filtering by Created By = [Me] and accept that pre-existing stakeholder rows (left by the previous PC) will not appear for the new PC until Owner is back-filled.
3. **Tools per-contract scoping**: Tools list has no Contract column in Wave 1. Decide whether Wave 2 adds one, or whether Step 3 just shows the full inventory.
4. **Trainee Profiles "Mine" view**: the right column of Section 2 looks cleanest if Trainee Profiles has a Public view filtered `Created By = [Me]`. Add this view as part of Pre-work if you want.
5. **Meetings filter**: `My Meetings` filters by a single Contract title. If the user works across multiple contracts, change the view to filter Contract IN (a, b, c) or use Created By = [Me].
6. **Banner image**: Hero needs a real image. Source one (1920x800, dark, low-detail) and upload to Site Assets before starting Section 1.
7. **Empty-state UX**: if the new PC has zero stakeholders and zero meetings on day one, the right columns of Sections 5 and 6 will be empty. Native List web parts handle this gracefully ("No items match your view"), but consider whether to add a tiny Text hint like "If this is empty, click the button on the left to add your first one."
