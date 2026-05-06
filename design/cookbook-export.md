# Cookbook Export — Design

**Status:** v1 design, not yet built
**Owner:** PC-as-builder
**Related:** D4 (centerpiece), D5 (never frame as replacement), `data-model/schemas.md`

The Cookbook Export is KITCHEN's defining output: a Word document assembled from SharePoint List data that reads like a hand-written PC cookbook. The build below targets a single click from the PC's home page producing a `.docx` in their OneDrive in under 60 seconds.

---

## 1. Word document template structure

Drawn from the Tucker (NSITE MO) and Chung (OCSDO) cookbooks, both follow the same skeleton even though they differ in customer, formatting, and verbosity. The template encodes that skeleton with **Word content controls** (Developer tab → Plain Text Content Control) named to match the data feed.

| # | Section | Source List(s) | Content control(s) | Notes |
|---|---------|----------------|--------------------|-------|
| 1 | Cover / title block | `PCs`, `Trainee Profiles`, `Programs` | `pcName`, `pcEmail`, `programName`, `programLongName`, `customer`, `coverDate` | Plain text controls; one per field. |
| 2 | About this document | Static boilerplate + `Programs.Description` | `programDescription` | Boilerplate stays in template; one control for the program-specific paragraph. |
| 3 | Position purpose & scope | `Programs.Description` + Tier 1 baseline (paste the Barrios 4.1 task description verbatim into the template — it's the same for every PC) | `positionPurpose` | The Barrios task description is a constant; treat as static template text, not a List feed. |
| 4 | Job duties / responsibilities | Tier 1 baseline + per-program additions stored in a free-form `Programs.PC responsibilities` field (add to schema if not present) | `jobDuties` (rich text content control) | Allows formatting carry-over. |
| 5 | Daily / Weekly / Monthly / Quarterly tasks | `30-60-90 Tasks` filtered to `Phase = Ongoing` and grouped by a new `Cadence` field (add: Daily, Weekly, Monthly, Quarterly, Annual) | Repeating Section content controls per cadence: `dailyTasks`, `weeklyTasks`, `monthlyTasks`, `quarterlyTasks` | Each repeating section contains nested controls: `taskTitle`, `taskNotes`. |
| 6 | Meeting catalog | `Meetings` filtered to current program | Repeating Section `meetings` containing `meetingName`, `meetingCadence`, `meetingDayTime`, `meetingType`, `meetingOwner`, `pcRole`, `pcResponsibilities`, `meetingResources` | The single largest section in both example cookbooks. Group by `Cadence` in the flow before populating. |
| 7 | Stakeholders / contacts | `Stakeholders` filtered to current program AND `Sensitive? = No` (sensitive contacts get a stub note: "See KITCHEN for restricted contacts") | Repeating Section `stakeholders` containing `contactName`, `contactRole`, `contactOrg`, `contactNotes` | Optionally split by Influence. |
| 8 | Tools & resources | `Tools` joined via `Program↔Tool` for current program | Repeating Section `tools` with `toolName`, `toolCategory`, `toolDescription` | One-line per tool. |
| 9 | Equivalency map | `Equivalency Map` filtered where `From-Tool ∈ Trainee Profile.Tools they came from` | Repeating Section `equivalencies` with `mappingTitle`, `whatsTheSame`, `gotchas`, `maturity` | Skip section entirely if the trainee has no prior-tool data. |
| 10 | Reports & cadences | Tier 1 boilerplate (MTR, ST Reporting) + `Programs.Reports notes` field | `reportsSection` (rich text) | Static template text with one optional override. |
| 11 | Decisions log highlights | `Decisions Log` filtered to current program, sorted by `Date decided` desc, top 20 | Repeating Section `decisions` with `decisionTitle`, `dateDecided`, `decisionContext`, `decisionText`, `decisionRationale` | Hard-cap to keep document size sane. |
| 12 | Acronyms | `Acronyms` filtered where `Programs` includes current program OR `Context = Agency` | Repeating Section `acronyms` with `acronym`, `expansion` | Sort A–Z. |
| 13 | Personal annotations | Free-form notes from `Trainee Profiles.Previous role context` and any program-specific notes the PC has captured | `personalNotes` (rich text) | Optional — empty if blank. |

**Naming convention:** content control titles use `camelCase`; repeating sections use plural nouns (`meetings`, `stakeholders`); inner controls are singular and prefixed with the parent name (`meetingName`, `stakeholderName`). The Power Automate `Populate a Microsoft Word template` action uses these titles as JSON keys, so consistency is non-negotiable.

---

## 2. Power Automate flow design

**Flow name:** `KITCHEN — Generate Cookbook`
**Trigger:** *Manually trigger a flow* (button), with one input — `Program ID` (Number). v1.1 may swap for a Forms trigger if a self-service form is preferred.

**Steps (in order):**

1. **Trigger** — Manually trigger a flow. Input: `programId` (Number).
2. **Initialize variable** `runId` = `formatDateTime(utcNow(),'yyyyMMdd-HHmmss')`.
3. **Get my profile (V2)** — captures the running user's email/display name.
4. **Get items — Trainee Profiles** — Filter Query: `PC/EMail eq '@{outputs('Get_my_profile')?['body/mail']}'`. Top 1.
5. **Get item — Programs** — by `programId` from trigger input.
6. **Get items — Meetings** — Filter Query: `Program/Id eq @{triggerBody()?['programId']}`. Order: `Cadence asc, Title asc`. Top 500.
7. **Get items — Stakeholders** — Filter: `Programs/Id eq @{triggerBody()?['programId']} and Sensitive eq false`. Top 500.
8. **Get items — Acronyms** — Filter: `Programs/Id eq @{triggerBody()?['programId']} or Context eq 'Agency'`. Top 1000.
9. **Get items — Decisions Log** — Filter: `Program/Id eq @{triggerBody()?['programId']}`. Order: `DateDecided desc`. Top 20.
10. **Get items — 30-60-90 Tasks** — Filter: `PC/EMail eq '@{...}' and Phase eq 'Ongoing'`. Top 500.
11. **Get items — Program↔Tool** — Filter: `Program/Id eq @{triggerBody()?['programId']} and SunsetDate eq null`. Expand `Tool`.
12. **Get items — Equivalency Map** — Filter: `FromTool/Id in (...)` built from Trainee Profile's `Tools they came from`. Skip if empty.
13. **Select** actions — one per repeating section — to project SharePoint items into the JSON shape the Word template expects. (Avoids Apply-to-each, which is slow and creates fragile loop expressions.) Example for meetings:
    ```
    From: outputs('Get_items_-_Meetings')?['body/value']
    Map:  {
            "meetingName": item()?['Title'],
            "meetingCadence": item()?['Cadence/Value'],
            "meetingDayTime": item()?['DayTime'],
            "pcRole": item()?['PC_Role/Value'],
            "pcResponsibilities": item()?['PCResponsibilities'],
            "meetingResources": item()?['Resources']
          }
    ```
14. **Populate a Microsoft Word template** — pick the template from the `Cookbook Templates` library. Fill plain-text controls from steps 4–5 outputs and repeating sections from the `Select` outputs.
15. **Create file** — Destination: OneDrive for Business `/Cookbooks/`. Filename: `@{outputs('Get_my_profile')?['body/displayName']}_@{outputs('Get_item_-_Programs')?['body/Title']}_Cookbook_@{variables('runId')}.docx`. Body: output of step 14.
16. **Send me an email notification** — link to the new file.

**Why `Select` instead of `Apply to each`:** the Word populate action accepts an array directly. `Apply to each` adds 5–30 seconds per item and runs into concurrency limits in the gov tenant.

---

## 3. Step-by-step build instructions

### A. Build the Word template (Word Online or Desktop)

1. Open Word. **File → Options → Customize Ribbon → check Developer.** (Word Online: Developer tab is exposed by default for templates stored in SharePoint.)
2. Type the cookbook structure as plain text first — copy headings from one of the example cookbooks to anchor the visual style. Apply Heading 1 / Heading 2 styles consistently; the populated document will inherit them.
3. For each placeholder location:
   - Plain field → **Developer → Plain Text Content Control (Aa).** Click **Properties → Title** and enter the camelCase name from the table above.
   - Rich content → **Rich Text Content Control.**
   - Repeating list → wrap the row/paragraph in a **Repeating Section Content Control**, then nest plain-text controls inside for each field. Set the repeating section's Title to the plural name (`meetings`).
4. Save as `.docx` (NOT `.dotx`). Name it `Cookbook_Template_v1.docx`.
5. Upload to a SharePoint document library `Cookbook Templates` on the KITCHEN site.

### B. Build the Power Automate flow

1. Go to `https://make.powerautomate.com` (NASA tenant — sign in with NASA SSO).
2. **+ Create → Instant cloud flow.** Name it `KITCHEN — Generate Cookbook`. Trigger: *Manually trigger a flow*. Add input `programId` (Number).
3. Add each action listed in section 2, in order. For every SharePoint `Get items`, set Site Address to the KITCHEN site and List Name from the dropdown — never type the GUID.
4. For each List with Lookup or Choice columns, expand **Advanced options** and set **Limit Columns by View** to a view that flattens lookups (faster + smaller payloads).
5. The `Populate a Microsoft Word template` action is under the **Word Online (Business)** connector. Point it at the template file in the `Cookbook Templates` library. Power Automate will read the content controls and render an input field per control — fill them with dynamic content from earlier steps.
6. Save. Test by clicking **Run** and supplying a known `programId`.
7. Once verified, surface the trigger as a button on the SharePoint home page using the **Power Automate** web part, or embed in a SharePoint button via the *Run a flow* action.

---

## 4. Limitations and gotchas

- **Gov tenant connectors:** the NASA M365 tenant restricts Power Platform connectors. SharePoint, Word Online (Business), OneDrive for Business, and Outlook are confirmed available; anything beyond that (HTTP, custom connectors, third-party) requires a request through the Power Platform Support team — see the link in Tucker's cookbook.
- **`Get items` default 100, max 5000.** Always set Top Count explicitly. Enable **Pagination** (Settings on the action) for any list expected to exceed 5000 rows. v1 lists won't, but Acronyms could grow.
- **`Filter Query` is OData.** Lookups filter on `<Column>/Id`; Choice on `<Column>/Value`; Person on `<Column>/EMail`. Quote string values with single quotes. Reference internal column names — for Lists provisioned via Excel import (per D12), this means `field_1`, `field_2`, etc. Document the mapping in the flow's Notes.
- **Word template content controls are case-sensitive.** A control titled `meetingName` will not bind to a flow input labeled `MeetingName`. Establish naming convention once, enforce it everywhere.
- **Repeating sections require an array of objects with key names exactly matching the inner control titles.** Mismatched keys silently skip — the section repeats N times but cells are blank. If you see empty rows in the output, key mismatch is the first place to check.
- **Word template file size:** keep under 10 MB. Strip example images from the template; styling alone gets you 90% of the visual fidelity.
- **No predecessor data:** wrap each repeating section's surrounding heading inside a `Repeating Section` of length 0 or 1 driven by an `if(empty(...), null, ...)` expression. Cleaner alternative: use Word's IF field around the heading. Simplest v1: always render the section heading; if the array is empty, populate with a single placeholder row reading "No entries yet — see KITCHEN to add."
- **Trainee Profile may be missing.** Guard step 4 with a Condition: if no profile, fall back to defaults (program-only cookbook with no personalization sections).
- **Personally identifying info:** per D9, never let a generated cookbook leave the NASA tenant via a connector that lands outside it. The Create file step targets OneDrive for Business — confirm the user is signed in to the NASA-tenant OneDrive, not personal.
- **Run history retains the document** for 28 days. For audit hygiene, do not log filter values that include personal email addresses outside the user's own.

---

## Future enhancements (out of v1 scope)

- PDF export option (Word Online → Convert File action).
- Forms-based trigger that accepts "include sensitive contacts? Y/N" and other toggles.
- Versioned "snapshot" archive in a SharePoint library with metadata per export.
- Template variants per customer (NSITE-flavored vs OCSDO-flavored heading styles).
