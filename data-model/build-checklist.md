# Build Checklist

## Status

**Mission 1 (Skeleton) and Mission 2 (Foundation Lists) are complete.** Both were built using PnP PowerShell automation against the live NASA tenant. The scripts that did the work live in `scripts/` — see `populate-equivalency-lookups.ps1`, `add-missing-admin-tools.ps1`, `backfill-admin-tools-metadata.ps1`, and `remove-duplicate-lookup-columns.ps1`.

---

Run through each list, verify column names, types, choices, and descriptions. Built so you can audit your work and catch drift between the design and what's actually deployed.

> **Notation:** ✅ = built, 🛠️ = in progress, ⏳ = not yet, ⚠️ = known gotcha.
>
> Each column entry shows: **Name — Type · Description ·** *(Choices, if applicable)*

---

## Mission 1 — Skeleton

### Equivalency Map (List)

- [x] List exists, named `Equivalency Map`
- [ ] Title column: leave as `Title`, OR rename to `Mapping`
  - *The "From → To" pair this row maps. Used as the lookup key when other lists reference an equivalency entry.*
- [ ] **Category** — Choice (no fill-in)
  - *The functional category of both tools. Drives grouping in views and filtering in dashboards.*
  - Choices: `Chat`, `Docs`, `Storage`, `Project Mgmt`, `Email`, `Calendar`, `Notes`, `Forms`, `Automation`, `Dashboards`, `Identity`, `Other`
- [ ] **From-Tool** — Lookup → Tools
  - *The tool a coordinator is migrating away from. Filtered against the user's previous tools (in their Trainee Profile) to personalize the Equivalency Map view.*
  - Lookup config: Primary `Title` (= Tool Name) · Additional `Category` · Single value
  - Source of values: every entry in the Tools list. Adding a tool there auto-makes it available here.
- [ ] **To-Tool** — Lookup → Tools
  - *The tool the destination program uses. Filtered against the program's `Tools used` to scope the equivalency map to relevant migrations only.*
  - Lookup config: Primary `Title` (= Tool Name) · Additional `Category` · Single value
  - Same pattern as From-Tool.
- [ ] **What's the same** — Multiple lines of text
  - *Capabilities that map cleanly between the two tools. Helps a coordinator feel oriented in the new ecosystem.*
- [ ] **Gotchas** — Multiple lines of text
  - *What surprises people during migration. The most valuable field — the kind of thing nobody documents in vendor-marketing material.*
- [ ] **Maturity** — Choice (no fill-in)
  - *How clean the mapping is. Drives the colored pill display (green/yellow/red).*
  - Choices: `High`, `Partial`, `None`
- [ ] 31 rows imported (verify row 22 reads `Jira → Azure DevOps Boards`, not Asana/Planner)

### Other tabs in Home channel

- [ ] **30-60-90** — Planner tab
  - *Visual Kanban for the new coordinator's onboarding tasks, organized by phase.*
  - Buckets: `Days 1-30`, `Days 31-60`, `Days 61-90`
- [ ] **KITCHEN Notes** — OneNote tab
  - *Free-form personal notebook for things that don't fit a structured List.*
  - Section: `Things I'm Learning`

---

## Mission 2 — Foundation Lists

### Tools (List)

- [ ] List exists, named `Tools`
- [ ] Title renamed to `Tool Name`
  - *Canonical name of the tool. Used as the lookup key by Equivalency Map, Trainee Profiles, and the Program↔Tool junction.*
- [ ] **Category** — Choice (no fill-in)
  - *Functional grouping. Shared vocabulary with the Equivalency Map's Category column.*
  - Choices: `Chat`, `Docs`, `Storage`, `Project Mgmt`, `Email`, `Calendar`, `Notes`, `Forms`, `Automation`, `Dashboards`, `Identity`, `Other`
- [ ] **Vendor** — Single line of text
  - *Company that produces the tool. Useful for vendor-level analytics ("how much of our stack is Microsoft vs. Google?").*
- [ ] **Description** — Multiple lines of text
  - *One-sentence plain-language summary of what the tool does. Surfaces in tooltips and the lookup picker.*
- [ ] 60 rows imported

### Programs (List)

- [ ] List exists, named `Programs`
- [ ] Title renamed to `Program Name`
  - *Official name of the NASA program/customer being supported. Lookup key referenced by Meetings, Stakeholders, Decisions Log, and PC↔Program History.*
- [ ] **Customer** — Single line of text
  - *Sponsoring organization or top-level customer (e.g., ESDS, OCSDO, MSFC ST Office).*
- [ ] **Center** — Choice
  - *The NASA center hosting the program. Used for filtering ("show me all MSFC programs") and reporting.*
  - Choices: `MSFC`, `GSFC`, `JPL`, `ARC`, `LaRC`, `GRC`, `JSC`, `KSC`, `SSC`, `AFRC`, `WFF`, `MAF`, `HQ`
- [ ] **Status** — Choice (default `Active`)
  - *Whether the program is currently active, paused, or wound down.*
  - Choices: `Active`, `Inactive`, `Sunset`
- [ ] **Description** — Multiple lines of text
  - *Plain-language summary of the program's purpose, charter, or scope.*
- [ ] **Barrios Lead** — Person or Group (allow people only)
  - *The PC's direct Barrios manager for this program.*
- [ ] **PC Customer** — Person or Group (allow people only)
  - *The NASA civil servant the PC supports day-to-day. Often a Project Manager or Project Lead.*
- [ ] **Tools used** — Lookup → Tools
  - *The tools this program currently uses. Drives the destination side of the Equivalency Map filter and feeds the Program↔Tool junction.*
  - Primary column: `Title` (the renamed `Tool Name`)
  - Additional column: `Category`
  - **Allow multiple values** ✅
- [ ] At least 1 row added (your current program)

### PCs (List)

- [ ] List exists, named `PCs`
- [ ] Title renamed to `Coordinator Name`
  - *Display name of the Project Coordinator. Lookup key referenced by Trainee Profiles and PC↔Program History.*
- [ ] **Person** — Person or Group (allow people only)
  - *The PC's M365 user reference. Pulls profile picture, email, org chart link from Entra. Lives only in the PCs list itself (Lookups can't reference Person columns).*
- [ ] **Email** — Single line of text
  - *Backup contact email. Useful for PCs whose Person field can't be resolved (e.g., departed users archived from Entra).*
- [ ] **Status** — Choice (default `Active`)
  - *Whether the PC is currently active in the role or has departed. Used to filter the catalog to currently-active PCs.*
  - Choices: `Active`, `Departed`
- [ ] **Contract** — Choice **with allow fill-in** (default `CPSS`)
  - *The Barrios contract vehicle assigning the PC to NASA. Useful for filtering when KITCHEN eventually scales across multiple Barrios contracts.*
  - Choices: `CPSS`, `Other`
- [ ] **Hire date** — Date
  - *When the PC joined the contract. Anchors tenure analytics.*
- [ ] Yourself added as a row, with **both** Coordinator Name (text) and Person (M365)

### Trainee Profiles (List)

- [ ] List exists, named `Trainee Profiles`
- [ ] Title renamed to `Profile Name`
  - *Identifier for this profile, typically "PC name — Program name". Used to disambiguate when one PC has multiple historical assignments.*
- [ ] **PC** — Lookup → PCs
  - *The Project Coordinator this profile belongs to.*
  - Primary column: `Title` (renamed `Coordinator Name`)
  - Additional column: `Email`
  - Single value
- [ ] **Current program** — Lookup → Programs
  - *The program the PC is currently supporting. Drives the destination side of the Equivalency Map filter and scopes the user's view of Meetings, Stakeholders, etc.*
  - Primary column: `Title` (renamed `Program Name`)
  - Additional column: `Customer`
  - Single value
- [ ] **Start date in current role** — Date
  - *When the PC started in this current assignment. Anchors the Day-N counter on the home page and the 30/60/90 task schedule.*
- [ ] **Tools they came from** — Lookup → Tools
  - *Tools the PC used in their previous role/customer. Drives the source side of the personalized Equivalency Map filter ("show me Slack → Teams because that's the migration I'm making").*
  - Primary column: `Title` (renamed `Tool Name`)
  - Additional column: `Category`
  - **Allow multiple values** ✅
- [ ] **Previous role context** — Multiple lines of text
  - *Optional free-form notes about the PC's prior assignment(s). Helps a successor understand what knowledge the predecessor brought in.*
- [ ] One row added: yourself, fully linked

---

## Known gotchas (already encountered)

⚠️ **CSV import as Excel mojibake.** Always re-export xlsx with UTF-8 encoding to preserve `→`, em-dashes, etc. Otherwise the arrows show as `â†'`.

⚠️ **Excel "From CSV" doesn't make a Table.** SharePoint Lists' "From Excel" import requires a named Table (Insert → Table). Use the PowerShell script we built, not just Save As.

⚠️ **Site Column "Name" is reserved.** NASA's tenant has a Site Column called "Name" registered, blocking new "Name" columns in any List on the site. Rename Title to list-specific names (`Coordinator Name`, `Program Name`, `Tool Name`).

⚠️ **Lookup columns can't reference Choice or Person columns.** Only text, number, date, and built-in columns are lookup-eligible. Choice and Person fields don't appear in the Lookup picker. Workaround: maintain a text Title column as the lookup key, alongside any Person columns you want for richness.

⚠️ **Lookup picker shows internal field names.** "Title" appears in the picker even after you renamed it to "Coordinator Name". Picking "Title" pulls the renamed display value — that's correct behavior.

⚠️ **Title column type cannot be changed.** It's locked as Single line of text, can't be deleted. Hide it from forms if you want; rename it freely.

---

## Not yet built (Mission 3+)

These come next. Listed here so you can see the shape of what's coming.

### Mission 3 — Operational Lists

- ⏳ **Stakeholders** — people the role touches
- ⏳ **Meetings** — recurring meeting catalog per program
- ⏳ **Acronyms** — searchable glossary
- ⏳ **Decisions Log** — what was decided, by whom, when, why

### Mission 4 — Tasks + Junctions

- ⏳ **30-60-90 Tasks** — the data behind your Planner board
- ⏳ **PC↔Program History** — junction: PC + Program + dates + role
- ⏳ **Program↔Tool** — junction: which programs use which tools

### Beyond — Forms + Power Automate + Power BI

- ⏳ Welcome Form (Microsoft Forms)
- ⏳ Power Automate flow: Welcome Form → Trainee Profile + 30-60-90 task seeding
- ⏳ Power Automate flow: Cookbook Export (Word document generation)
- ⏳ Power BI dashboard embedded in SharePoint home

---

*Last updated: 2026-05-02*
