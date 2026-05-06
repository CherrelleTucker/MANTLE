# KITCHEN Home Page -- GUI Build Recipe

Manual, drag-and-drop SharePoint Modern build recipe for the KITCHEN site home page. Target: approximate the design in `design/onboarding-offboarding-native-mockup.html` (Home panel) using ONLY native section templates and native web parts. No HTML hacks, no PowerShell, no SPFx.

- **Site**: https://nasa.sharepoint.com/teams/PCTransitionSandbox
- **Site type**: Group-connected (Teams-backed). OneColumn / TwoColumn / ThreeColumn / Vertical section are available; OneColumnFullWidth is NOT.
- **Tenant**: NASA GCC. Standard Modern web parts only. SPFx blocked. Copilot in SharePoint assumed unavailable.
- **Audience**: single owner (you), executing manually in Modern Edit mode.

---

## Total estimated build time

**~75-90 minutes** start to finish, broken down as:

- Pre-work (theme, scrap old page, create new page): ~10 min
- Per-office views in lists (one-time, optional but recommended): ~10 min
- Section 1 -- Hero: ~7 min
- Section 2 -- Path picker: ~7 min
- Section 3 -- What KITCHEN is + Quick Stats: ~10 min
- Section 4 -- Three feature cards: ~10 min
- Section 5 -- Quick links + Recent activity: ~12 min
- Section 6 -- Trust / visibility callout: ~5 min
- Section 7 -- Internal-use-only footer: ~3 min
- Publish, set as home, smoke test: ~5 min

---

## Section plan at a glance

| # | Section template | Emphasis | Web parts | Mockup mapping |
|---|---|---|---|---|
| Pre | -- | -- | (Theme + new page) | -- |
| 1 | OneColumn | Strong (Navy) | Hero (1 tile, Layers) | S1 -- Welcome / acronym tagline |
| 2 | TwoColumn | None | Call to Action x2 (or Hero, 2 tiles) | S2 -- Onboarding vs Offboarding tiles |
| 3 | TwoColumn | Neutral | Text + Quick Links (Compact) OR Highlighted Content | S3 -- What KITCHEN is + Stats |
| 4 | ThreeColumn | None | Quick Links x1 (Tiles, 3 links) OR three Text web parts | S4 -- Three feature cards |
| 5 | TwoColumn | None | Quick Links (List) + List (Stakeholders / Recent) | S5 -- Quick links + Recent activity |
| 6 | OneColumn | Soft | Text | Visibility / who-can-see callout |
| 7 | OneColumn | Soft (gold-ish via theme) | Text | S6 -- Internal-use-only footer |

After all sections, also add a **Vertical section** on the right (optional) for People web part of "KITCHEN admins" -- skip if you want a cleaner page.

---

## PRE-WORK

### P1. Apply the Barrios theme (~3 min)

1. Top right gear icon -> **Change the look** -> **Theme**.
2. If a custom Barrios theme has been deployed to the tenant, pick it from the list. If not, pick the closest built-in (e.g., "Blue") and accept that brand colors will not be exact -- do NOT try to write a custom theme JSON in the GUI; that requires PowerShell.
3. Click **Save**.
4. Confirm the navy/gold-ish accent shows in the suite bar and section emphasis swatches.

**Open question for owner**: is the Barrios theme actually published to this tenant? If not, decide between (a) accepting a built-in theme that is "close enough", or (b) requesting tenant admin push the theme (out of scope for this recipe).

### P2. Scrap the existing Home page (~3 min)

1. Gear -> **Site contents** -> **Site Pages** library.
2. Find the current "KITCHEN Home" (or "Home.aspx"). Right-click -> **Rename** to `[ARCHIVED] KITCHEN Home` (do NOT delete yet -- you may want a fallback while building).
3. Stay in Site Pages.

### P3. Create the new blank page (~3 min)

1. In Site Pages, click **+ New** -> **Site page**.
2. Template chooser: pick **Blank**. Click **Create page**.
3. Top of page, click the title placeholder. Type: `KITCHEN Home`.
4. Click the small banner area below the title. In the title-area panel on the right:
   - **Layout**: Plain (smallest header).
   - **Show published date**: Off.
   - **Show topic header**: Off.
   - Image: leave blank or upload a banner later.
5. Click **Save as draft** (top right) just to lock in the page name.

### P4. Set as site home page (do this AFTER publishing the build) (~1 min, defer to end)

Skip for now. Done after Section 7 is published.

---

## PER-OFFICE FILTERING -- decision

Sections that embed list data (Recent activity, Stakeholders rollup) face the multi-office problem: NSITE MO viewers want different rows than ODSI / ST50 / MSFC viewers. Options:

1. **Static filter**: web part filtered to a single office. Fine if you build one page per office. Requires duplicating the page; not recommended for a single home page.
2. **Quick Links to pre-filtered list views** (RECOMMENDED). You create one filtered list view per office once, then put four links on the home page: "Stakeholders -- NSITE MO view", "Stakeholders -- ODSI view", etc. Viewer picks their own. Zero per-viewer logic needed; works on any tenant.
3. **Audience targeting on sections**: each section appears only to a SharePoint group ("NSITE MO members", "ODSI members", etc.). Requires the groups exist and members be assigned. Heavier setup; defer until office groups are formalized.
4. **No filter, show all**: embed default view, let the viewer use the list's built-in filter pane. Simplest, least targeted.

**Recommended for v1**: Option 2 (quick links to per-office views) plus Option 4 fallback (a single unfiltered List web part below). When office groups exist, layer Option 3 on top.

### How to create a per-office filtered list view (do this once per list, ~3 min each)

For the Stakeholders list (repeat for any list that has the new Office multi-Choice on Owner):

1. Open the **Stakeholders** list.
2. Top right of the list, click the view dropdown (likely says "All Items") -> **Create new view**.
3. View name: `Stakeholders -- NSITE MO`.
4. Show as: **List**. Make Public: **Yes** (so others can see it).
5. Click **Create**.
6. View loads. Click the **Filter** funnel icon top right -> click the office field (once Owner.Office is added) -> check **NSITE MO**.
7. Click **Save view as** -> overwrite `Stakeholders -- NSITE MO`.
8. Copy the URL from the browser address bar. Save it for use in Section 5.
9. Repeat for ODSI, ST50, MSFC, External -- one view per office value.

**Note**: Office is a field on the **Owner** person record, not directly on Stakeholders. If Office is added as a column on the Stakeholders list itself (e.g., "Owner Office") then this is straightforward. If it lives only on a related Owner record, the list view filter cannot follow that link -- in that case fall back to filtering on a column the Stakeholders list owns directly (e.g., "Org or Team", or add a denormalized "Owner Office" column on Stakeholders during Wave 2).

---

## SECTION 1 -- Hero band

**Mockup reference**: S1 of Home page -- navy band, gold tagline `KNOWLEDGE . INTERVIEWS . TRANSITIONS . COOKBOOKS . HANDOFFS . EQUIVALENCIES . NETWORK`, large white "Welcome to KITCHEN" headline, descriptive paragraph below.

- **Section template**: OneColumn
- **Section emphasis**: **Strong** (this gives the dark navy fill that survives in published view; with a Barrios or NASA-blue theme, Strong renders as the deep brand color)
- **Web parts**: 1x **Hero**

### Steps

1. In edit mode, click the small **+** icon at the very top of the canvas (or hover between sections to find an insertion point).
2. Choose **One column** section.
3. Click the small section settings pencil on the left edge of the section. In the right panel:
   - **Section background**: Strong.
   - **Vertical alignment**: Top.
4. In the empty section, click the round **+** -> search for `Hero` -> click **Hero**.
5. The Hero appears with default tiles. Click the Hero, then click the small pencil/edit icon on the Hero toolbar.
6. In the right panel:
   - **Layout**: **Layers**.
   - **Number of layers**: **1**.
7. Click on the single hero tile -> Details pane opens.
   - **Image source**: click **Change** -> choose **From a link** -> paste a sourced banner image URL (a wide, dark, low-detail image works best -- the Hero overlay will darken it). Alternative: **Upload** a Barrios-branded banner you sourced separately.
   - **Title**: `Welcome to KITCHEN`
   - **Subtitle (alt text or caption)**: `Knowledge . Interviews . Transitions . Cookbooks . Handoffs . Equivalencies . Network`
   - **Link**: leave blank (the hero is decorative -- no click target).
   - **Call to action**: toggle **Off** (the path picker in Section 2 is the CTA; we don't want a duplicate button on the hero).
   - **Show topic**: optional. If on, type `Knowledge collected by every coordinator who has done this role before you.`
8. Close the panel.

**Visual outcome**: A full-width banner with a dark image, large "Welcome to KITCHEN" headline, the six-word tagline as subtitle, and (optionally) a one-line topic. No call-to-action button on the hero itself.

**Time**: ~7 min.

---

## SECTION 2 -- Path picker (Onboarding vs Update/Offboarding)

**Mockup reference**: S2 -- two side-by-side colored cards, each with a label, headline, paragraph, and gold "Start ..." button.

- **Section template**: TwoColumn
- **Section emphasis**: None
- **Web parts**: 2x **Call to Action** (one per column)

Native Modern has a **Call to Action** web part that does exactly this: image background, headline text, button text + URL. Two of them side by side approximates the mockup well.

### Steps

1. Below Section 1, click **+** -> **Two columns** section.
2. Section emphasis: **None**.
3. **Left column**: click **+** -> search `Call to action` -> click **Call to action**.
   - Click the web part to open its panel.
   - **Image**: click **Change image** -> upload or link an image evoking onboarding (a hallway, an open door, a desk being set up). For a flat color background, any solid blue 1200x600 image works.
   - **Image overlay opacity**: ~50% (so text is readable).
   - **Title text** (typed directly on the web part on canvas): `I'm joining a new team`
   - **Description / subtext** (also typed on canvas if the layout supports it; otherwise leave blank): `Walk through who you are, what tools you use, how you communicate, and what your day-to-day looks like.`
   - **Button label**: `Start Onboarding`
   - **Button link**: paste the URL of your Onboarding page (e.g., `https://nasa.sharepoint.com/teams/PCTransitionSandbox/SitePages/Onboarding.aspx`). If that page does not exist yet, paste `#` and update later.
   - **Alignment**: Center.
4. **Right column**: click **+** -> **Call to action**. Same drill.
   - **Image**: a darker / wrapping-up image (someone packing up a desk, a calendar marked, etc.). A solid navy 1200x600 image works.
   - **Title text**: `I'm wrapping up my role`
   - **Description**: `Capture what you know so your replacement isn't lost. Generate a cookbook when you're ready.`
   - **Button label**: `Start Update/Offboarding`
   - **Button link**: URL of Offboarding page, or `#` for now.
   - **Alignment**: Center.

**Fallback if Call to Action is not available on this tenant**: use a single **Hero** web part with **Layout = Tiles**, **2 tiles**. Tile 1 title `I'm joining a new team`, Tile 2 title `I'm wrapping up my role`. Each tile has its own image and link. Visually nearly identical.

**Visual outcome**: Two card-like panels, each with a background image, headline, short paragraph, and a gold-ish (theme accent) button. Clicking either button navigates to the corresponding journey page.

**Time**: ~7 min.

---

## SECTION 3 -- What KITCHEN is (left) + Quick stats (right)

**Mockup reference**: S3 -- left column has a small uppercase eyebrow, a heading, and two paragraphs of body text. Right column has a soft-grey panel with five rows of "label + big number".

- **Section template**: TwoColumn
- **Section emphasis**: Neutral (gives the right-hand stats panel a soft grey backdrop without needing per-cell styling)
- **Web parts**: Left = **Text**. Right = **Quick Links** (Compact list layout) OR a second **Text** web part with bold numbers.

Native web parts cannot do animated counters. The closest faithful render is a Text web part with a bulleted list using bold for the number. A **List** web part filtered to recent additions is overkill for a five-row stat block.

### Steps

1. Below Section 2, **+** -> **Two columns** -> emphasis **Neutral**.
2. **Left column**: **+** -> **Text**.
   - In the inline editor, type:
     - On line 1, set the style dropdown to "small text" or use the eyebrow style: type `WHAT KITCHEN IS` (then bold it; consider an em-dash divider after).
     - On line 2, switch to **Heading 3**: type `A platform for coordinator-to-coordinator knowledge transfer`.
     - Switch to **Normal**: paragraph 1: `PCs leave, contracts shift, and institutional knowledge vanishes. KITCHEN captures the relationships, meetings, decisions, and unwritten rules that make a working team actually work -- and packages it for the next person.`
     - New paragraph: `Built by coordinators, for coordinators. Maintained by every PC who uses it.`
   - No HTML, no custom colors. Just headings, paragraphs, bold.
3. **Right column**: **+** -> **Text**.
   - **Heading 3**: `ACROSS ALL CONTRACTS` (then optionally drop to Heading 4 with smaller emphasis if you prefer).
   - Switch to **Normal**, build a simple two-column-feel list using bold for the number:
     - `Stakeholders captured -- **47**`
     - `Working styles documented -- **23**`
     - `Meetings catalogued -- **19**`
     - `Decisions logged -- **31**`
     - `Cookbooks generated -- **8**`
   - Add at the bottom in italic: `Numbers shown are placeholders -- update quarterly.`

**Optional upgrade (~5 extra min)**: replace the right column with a **List** web part pointed at Stakeholders, view = `All Items`, layout = **Compact list**, sized to ~5 rows. This gives a real live feed but trades the "stat block" feel for a "recent items" feel. Pick one or the other; if you want both, add another section.

**Visual outcome**: Left side reads like marketing copy. Right side reads like a dashboard widget on a soft-grey background. No fancy formatting, but the structure carries.

**Time**: ~10 min.

---

## SECTION 4 -- Three feature cards

**Mockup reference**: S4 -- three equal columns, each a white card with a colored left stripe (navy / gold / blue), a heading, two-sentence paragraph, and a "Open ..." link.

- **Section template**: ThreeColumn
- **Section emphasis**: None
- **Web parts**: 3x **Quick Links** (one per column, layout = Button) OR 3x **Text** web parts

The native **Quick Links** web part with Button layout gives one button per "link", but each card needs a heading + paragraph + link, which Quick Links cannot do. Closest native match: 3x **Text** web parts.

### Steps

1. Below Section 3, **+** -> **Three columns** -> emphasis **None**.
2. **Left column** -> **+** -> **Text**:
   - **Heading 3**: `Capture working styles`
   - **Normal**: `Per-stakeholder discovery: 23 questions covering communication, decisions, deep work, feedback, conflict -- captured in your first 1:1s.`
   - New paragraph, **bold link**: type `Open Stakeholders ->` and select it -> Insert link icon -> paste Stakeholders list URL.
3. **Middle column** -> **+** -> **Text**:
   - **Heading 3**: `Generate cookbooks`
   - **Normal**: `One-click generation pulls everything you have documented into a Word document handoff. Your replacement reads it on day one.`
   - **Bold link**: `KITCHEN Actions ->` -> link to admin actions page (or `#` placeholder).
4. **Right column** -> **+** -> **Text**:
   - **Heading 3**: `Browse equivalencies`
   - **Normal**: `Cross-tool translations: Slack to Teams, Drive to OneDrive, Asana to Planner. Find the local equivalent of what you already know.`
   - **Bold link**: `Open Equivalency Map ->` -> link to Equivalency Map list URL.

The colored left stripe in the mockup cannot be reproduced by native Text. It is decorative and the heading + body still reads as a card thanks to the column gutter spacing.

**Optional upgrade**: collapse all three into a single **Quick Links** web part, layout **Tiles** (3 tiles), with each tile having a thumbnail image + title + URL. Loses the descriptive paragraph but gains a more visual feel.

**Visual outcome**: Three side-by-side text blocks. Each reads as a feature card thanks to the section gutter. Bold "Open ..." links on each.

**Time**: ~10 min.

---

## SECTION 5 -- Quick links + Recent activity

**Mockup reference**: S5 -- left column has a "Quick links" heading and 6 stacked link rows. Right column has "Recent activity" heading and stacked activity items.

- **Section template**: TwoColumn
- **Section emphasis**: None
- **Web parts**: Left = **Quick Links** (List layout). Right = **List** web part pointed at Stakeholders (or a different active list)

### Steps

1. Below Section 4, **+** -> **Two columns** -> emphasis **None**.
2. **Left column** -> **+** -> **Quick Links**.
   - Click the web part -> edit pane.
   - **Layout**: **List**.
   - **Title** (above the links): `Quick links`
   - Click **+ Add links**. For each item, click **Add** -> **From a link** (or browse the site):
     1. Title: `Stakeholders directory` -- URL: Stakeholders list URL.
     2. Title: `Meetings catalogue` -- URL: Meetings list URL.
     3. Title: `Acronym glossary` -- URL: Acronyms list URL.
     4. Title: `Tools inventory` -- URL: Tools list URL.
     5. Title: `Equivalency Map` -- URL: Equivalency Map list URL.
     6. Title: `Trainee Profiles` -- URL: Trainee Profiles list URL.
     7. Title: `30-60-90 Tasks` -- URL: 30-60-90 Tasks list URL.
     8. Title: `KITCHEN Actions (admin)` -- URL: admin actions page or `#` placeholder.
   - Per-office filtering: also add the per-office filtered Stakeholder views you created in PRE-WORK as separate links here. For example:
     - `Stakeholders -- NSITE MO`
     - `Stakeholders -- ODSI`
     - `Stakeholders -- ST50`
     - `Stakeholders -- MSFC`
     - `Stakeholders -- External`
   - Order matters -- drag the most-clicked items to the top.
3. **Right column** -> **+** -> **List** (the official "List" web part that embeds a SharePoint list).
   - Pick **Stakeholders** (or whatever has the most recent edit activity -- could be Meetings).
   - Edit pane:
     - **List view**: pick a view named something like `Recent` (create it in the list ahead of time: sort by Modified descending, top 10). If you didn't create one, pick `All Items` and configure size/sort here.
     - **Title displayed on web part**: `Recent activity`
     - **Show toolbar**: Off (cleaner look) or **See all** only.
     - **Show command bar**: Off.
   - Per-office filter on this single embedded list: the List web part does NOT support per-viewer filtering, so this view will show the SAME rows to every viewer. Acceptable for v1.
   - If the embedded List feels too heavy, replace it with a second **Quick Links** web part (List layout) titled `Recent activity` and manually paste 3-5 recent item URLs as a static curated list (refresh weekly).

**Visual outcome**: Left side is a clean stacked link list with the brand-blue link color from the theme. Right side is an interactive list view (sortable, scrollable) showing recent activity from Stakeholders.

**Time**: ~12 min.

---

## SECTION 6 -- Visibility / who-can-see callout (optional but recommended)

**Mockup reference**: not in the Home panel of the mockup, but mirrors the "WHO CAN SEE YOUR INPUT" trust card on the Onboarding/Offboarding panels. Useful as a trust signal on Home so first-time visitors understand the data model.

- **Section template**: OneColumn
- **Section emphasis**: Soft
- **Web parts**: 1x **Text**

### Steps

1. Below Section 5, **+** -> **One column** -> emphasis **Soft**.
2. **+** -> **Text**.
   - **Heading 3**: `Who can see what's on this site`
   - **Normal**: `KITCHEN is internal to Barrios and your contract team. Stakeholder records, working styles, and decisions are visible to:`
   - Bulleted list:
     - `You`
     - `Other PCs assigned to the same contract`
     - `Your Barrios manager`
     - `KITCHEN administrators`
   - New paragraph: `Items tagged Confidential are personal observations and never appear in public reports or external slides.`

**Visual outcome**: A soft-tinted band of text reassuring the viewer about the data audience. No fancy styling needed -- emphasis carries it.

**Time**: ~5 min.

---

## SECTION 7 -- Internal-use-only footer

**Mockup reference**: S6 -- single full-width gold-tinted band with bold "Internal use only." text and a one-sentence reminder.

- **Section template**: OneColumn
- **Section emphasis**: Soft (theme tints this in a brand-friendly way; native Modern does not let you pick gold specifically without custom theme JSON)
- **Web parts**: 1x **Text**

### Steps

1. Below Section 6, **+** -> **One column** -> emphasis **Soft**.
2. **+** -> **Text**.
   - All on one line, **Normal** style, mixing bold:
     - Bold: `Internal use only.`
     - Then non-bold: ` KITCHEN contains contract-sensitive context. Do not share pages or list exports outside Barrios or your contract team.`
3. Center-align the paragraph.

**Visual outcome**: A modest, slightly-tinted full-width band at the bottom of the page that reads as a footer disclaimer.

**Time**: ~3 min.

---

## PUBLISH AND SET AS HOME

1. Top right: **Publish** (or **Republish** if you've been saving drafts).
2. After publishing, click the title area -> **Page details** opens on the right -> scroll for **Make this page the home page** -> click it. Confirm.
3. Alternative path: gear -> **Site information** -> **View all site settings** -> Look and Feel -> **Welcome page** -> set to your new page URL.
4. Hard-refresh the site root (Ctrl+F5). Verify the new page renders as the landing page.

**Time**: ~5 min.

---

## SMOKE TEST CHECKLIST

After publishing:

- [ ] Hero renders with image and headline. No broken image icon.
- [ ] Both path-picker buttons navigate correctly (or are clearly placeholder `#`).
- [ ] All Quick Links resolve to real list URLs (no 404s).
- [ ] List web part in Section 5 actually loads rows. If blank, check the view permission and the chosen view's filters.
- [ ] Per-office view links open the correctly filtered list view for at least NSITE MO and ODSI.
- [ ] Page is set as site home (URL `/teams/PCTransitionSandbox/` lands on this page, not on the old one).
- [ ] Old page is renamed `[ARCHIVED] KITCHEN Home`, not deleted.
- [ ] No section emphasis is "Strong" except Section 1 (the hero band) -- protects readability.

---

## OPEN QUESTIONS FOR THE OWNER

1. **Barrios theme published?** If no custom theme is on the tenant, the navy/gold palette will be approximate (closest built-in theme). Decide whether to request tenant admin push the theme or accept the approximation.
2. **Onboarding / Offboarding page URLs**: Section 2's Call to Action buttons need real URLs. If those pages do not exist yet, build them next and come back to update.
3. **Office field location**: per-office filtering assumes Office is a column on Stakeholders (directly or denormalized). If Office only lives on the related Owner record, the per-office views need a different filter column. Confirm the Wave 2 schema decision before creating views.
4. **Banner image source**: Hero needs a real banner. Owner should source one image (1920x800 or larger, dark / low-detail) and upload to the Site Assets library before starting Section 1.
5. **Recent activity scope**: do you want Section 5 right column to show Stakeholders edits specifically, or a mixed feed across Stakeholders + Meetings + Decisions? Native List web part can only point at one list, so a true mixed feed requires multiple stacked List web parts (or accepting one canonical list).
6. **Stats numbers in Section 3**: hard-coded placeholders or refresh quarterly? Consider replacing with a live List web part (Compact, sized to 5 rows) of the most recently added stakeholder records as an alternative.
