# Cookbook Export — Build Guide (v1)

**Audience:** the PC building MANTLE in the NASA tenant (single-user deployment).
**Companion to:** `design/cookbook-export.md` (design intent), `data-model/schemas.md` (List schemas).
**Output of this guide:** a working `MANTLE — Generate Cookbook` flow that produces a `.docx` in the MANTLE site's `Cookbooks` library when triggered.

This is a click-by-click implementation guide. It assumes the design is settled and turns it into actions. Decisions made for you (and locked in for v1):

- **Output destination:** SharePoint document library on the MANTLE site at `/Documents/Cookbooks/` — *not* OneDrive. Reason: stays inside the tenant boundary (D9), is discoverable to a future second user, and survives the PC's departure.
- **Schema gaps:** v1 builds against the schema as it exists today. Anything the design doc calls out as "add to schema" (e.g., `Programs.PC responsibilities`, `30-60-90 Tasks.Cadence`) is a **v2 enhancement — leave the corresponding content control blank in v1**. The flow still binds it; the value is just an empty string.
- **Excel-imported lists** use generic internal names. Crosswalk inline below.

---

## Prerequisites

- Site: `https://nasa.sharepoint.com/teams/PCTransitionSandbox` (you are the owner).
- Lists already provisioned: `Programs`, `PCs`, `Trainee Profiles`, `Meetings`, `Stakeholders`, `Acronyms`, `Tools`, `Equivalency Map Real`, `30-60-90 Tasks`, `Decisions Log`, `PC↔Program History`, `Program↔Tool`.
- Power Automate access at `https://make.powerautomate.com` (sign in with NASA SSO).
- Word Online via M365 (`https://www.office.com` → Word).
- **Standard connectors only.** Confirmed available: SharePoint, Word Online (Business), Office 365 Outlook, Office 365 Users. **Do not** plan around HTTP, Premium SharePoint, or custom connectors.
- One known program ID for testing. Get it now: open the `Programs` list in SharePoint, open one item, look at the URL — `…&ID=3` means programId `3`.

### Internal-name crosswalk (Excel-imported lists)

Per D12, lists provisioned via Excel import have generic internal column names. The flow's `Filter Query` and `Select` mappings must use the internal name, not the display name.

**`Tools` list:**

| Display name | Internal name |
|--------------|---------------|
| Tool Name (Title) | `Title` |
| Category | `field_1` |
| Vendor | `field_2` |
| Description | `field_3` |

**`Equivalency Map Real` list:**

| Display name | Internal name |
|--------------|---------------|
| Mapping (Title) | `Title` |
| Category | `field_1` |
| From-Tool (lookup) | `field_2` |
| To-Tool (lookup) | `field_3` |
| What's the same | `field_4` |
| Gotchas | `field_5` |
| Maturity | `field_6` |

To verify on your tenant: open the list → **Settings (gear) → List settings → Columns → click a column → check the URL** (`…&Field=field_1`). Update the table above if anything differs before you build the flow.

All other lists were provisioned natively, so use the display name (with spaces removed) as the internal name (e.g., `PCResponsibilities`, `DateDecided`).

---

## Phase 1 — Build the Word template

You will build this in **Word Desktop** if available (Developer tab is fully featured). Word Online works but the Repeating Section control is only insertable in Desktop. If you only have Word Online, build in Desktop on a personal device first or borrow an unmanaged machine — there's no workaround inside the gov-tenant Word Online.

### 1.1 Enable the Developer tab

1. Open Word Desktop → **File → Options → Customize Ribbon**.
2. In the right pane, check **Developer**.
3. Click **OK**. The Developer tab now appears in the ribbon.

### 1.2 Lay out the document

1. Start from a blank document. Type each section heading from the design doc (sections 1–13). Apply **Heading 1** to top-level sections, **Heading 2** to subsections.
2. Type any boilerplate prose verbatim (sections 2, 3, 10 contain static text per the design — paste from one of the existing example cookbooks).
3. Leave a blank paragraph everywhere a content control will go.

### 1.3 Insert content controls

For each row in the design doc's section table:

1. Place the cursor where the value should appear.
2. **Developer tab → Plain Text Content Control** (the "Aa" icon). For prose paragraphs that need formatting carry-over, use **Rich Text Content Control** instead.
3. With the new control selected, click **Developer → Properties**.
4. In **Title**, enter the camelCase name from the design doc. **Tag** can be left blank or set to the same value. Click **OK**.

Required plain-text controls (cover/title): `pcName`, `pcEmail`, `programName`, `programLongName`, `customer`, `coverDate`.
Required rich-text controls: `programDescription`, `positionPurpose`, `jobDuties`, `reportsSection`, `personalNotes`.

### 1.4 Insert repeating sections

For each repeating section (`meetings`, `stakeholders`, `tools`, `equivalencies`, `decisions`, `acronyms`, `dailyTasks`, `weeklyTasks`, `monthlyTasks`, `quarterlyTasks`):

1. Type one example row's worth of content as a table row or paragraph block. Inside that block, insert the inner Plain Text Content Controls and title each one per the design (e.g., `meetingName`, `meetingCadence`, `meetingDayTime`, `meetingType`, `meetingOwner`, `pcRole`, `pcResponsibilities`, `meetingResources`).
2. **Select the entire row/block** (including the inner controls).
3. **Developer → Repeating Section Content Control**.
4. **Properties → Title** = the plural camelCase name (e.g., `meetings`).

### 1.5 Save and upload

1. **File → Save As → Browse** → save locally as `Cookbook_Template_v1.docx` (`.docx`, not `.dotx`).
2. In your browser, go to `https://nasa.sharepoint.com/teams/PCTransitionSandbox/Shared Documents`.
3. Create folder **CookbookTemplates** (no space — easier to reference in the flow).
4. Upload `Cookbook_Template_v1.docx` into it.
5. Create a sibling folder **Cookbooks** at the same level — this is where the flow will write outputs.

---

## Phase 2 — Build the Power Automate flow

### 2.1 Create the flow shell

1. Browse to `https://make.powerautomate.com` → sign in with NASA SSO.
2. Confirm the environment selector (top right) shows the correct NASA tenant environment.
3. **+ Create → Instant cloud flow.**
4. **Flow name:** `MANTLE — Generate Cookbook`. **Trigger:** *Manually trigger a flow*. Click **Create**.
5. On the trigger card, click **+ Add an input → Number**. Name it `programId`.

### 2.2 Initialize variables

Click **+ New step**:

- **Initialize variable** → Name: `runId`, Type: String, Value (expression): `formatDateTime(utcNow(),'yyyyMMdd-HHmmss')`.

### 2.3 Identify the running user

- **+ New step → Office 365 Users → Get my profile (V2).** Default fields are fine.

### 2.4 Get the trainee profile

- **+ New step → SharePoint → Get items.**
  - **Site Address:** select the MANTLE site from the dropdown (do not paste the URL).
  - **List Name:** `Trainee Profiles`.
  - **Filter Query:** `PC/EMail eq '@{outputs('Get_my_profile_(V2)')?['body/mail']}'`
  - **Top Count:** `1`.
  - Rename the action: click the title bar → "Get_TraineeProfile".

### 2.5 Get the program

- **+ New step → SharePoint → Get item.**
  - Site Address: MANTLE site. List Name: `Programs`.
  - **Id:** click the field, then **Dynamic content → programId** (from the trigger).
  - Rename: "Get_Program".

### 2.6 Get the related lists

For each of the following, add **SharePoint → Get items**, then set **Site Address**, **List Name**, **Filter Query**, **Order By**, **Top Count**, and rename the action. Always click **Show advanced options** to see Filter Query.

| Action name | List | Filter Query | Order By | Top |
|-------------|------|--------------|----------|-----|
| Get_Meetings | Meetings | `Program/Id eq @{triggerBody()?['number']}` | `Cadence asc,Title asc` | 500 |
| Get_Stakeholders | Stakeholders | `Programs/Id eq @{triggerBody()?['number']} and Sensitive eq 0` | `Title asc` | 500 |
| Get_Acronyms | Acronyms | `Programs/Id eq @{triggerBody()?['number']} or Context eq 'Agency'` | `Title asc` | 1000 |
| Get_Decisions | Decisions Log | `Program/Id eq @{triggerBody()?['number']}` | `DateDecided desc` | 20 |
| Get_OngoingTasks | 30-60-90 Tasks | `PC/EMail eq '@{outputs('Get_my_profile_(V2)')?['body/mail']}' and Phase eq 'Ongoing'` | `Title asc` | 500 |
| Get_ProgramTools | Program↔Tool | `Program/Id eq @{triggerBody()?['number']} and SunsetDate eq null` | `Title asc` | 200 |
| Get_Tools | Tools | (leave blank — filtered downstream by Select against Get_ProgramTools) | `Title asc` | 1000 |
| Get_Equivalencies | Equivalency Map Real | `field_2 ne null` (refined in Select) | `Title asc` | 500 |

**Notes on Filter Query syntax:**

- The trigger input shows up in expressions as `triggerBody()?['number']` even though you named it `programId` — Power Automate stores the first Number input under the key `number`. Confirm by inspecting the trigger output schema after one test run; if your tenant differs, swap to `triggerBody()?['programId']`.
- Boolean Yes/No fields filter as `eq 0` / `eq 1` in OData, not `eq false` / `eq true` (the design doc's `eq false` will silently fail on some tenants — use `0` to be safe).
- `null` in OData has no quotes: `SunsetDate eq null`.
- For `Equivalency Map Real`, use the **internal** field name `field_2` (= From-Tool lookup), not the display name. Refer to the crosswalk table.

### 2.7 Project arrays with `Select` (not `Apply to each`)

For every repeating section, add a **Data Operation → Select** action immediately after the corresponding Get items.

**Why Select, not Apply to each:** the Word `Populate` action accepts arrays of objects directly. Select transforms in one step; Apply to each iterates and is 5–30× slower in the gov tenant.

Example — `Select_Meetings`:

- **From:** `outputs('Get_Meetings')?['body/value']`
- Switch to **Text mode** (icon at top right of the Map area). Paste:

```
{
  "meetingName": @{item()?['Title']},
  "meetingCadence": @{item()?['Cadence/Value']},
  "meetingDayTime": @{item()?['DayTime']},
  "meetingType": @{item()?['MeetingType/Value']},
  "meetingOwner": @{item()?['Owner/DisplayName']},
  "pcRole": @{item()?['PC_Role/Value']},
  "pcResponsibilities": @{item()?['PCResponsibilities']},
  "meetingResources": @{item()?['Resources']}
}
```

Repeat for each repeating section. Critical mappings:

- **Stakeholders:** `contactName` ← `Title`, `contactRole` ← `Role`, `contactOrg` ← `OrgTeam`, `contactNotes` ← `Notes`.
- **Acronyms:** `acronym` ← `Title`, `expansion` ← `Expansion`.
- **Decisions:** `decisionTitle` ← `Title`, `dateDecided` ← `formatDateTime(item()?['DateDecided'],'yyyy-MM-dd')`, `decisionContext` ← `Context`, `decisionText` ← `Decision`, `decisionRationale` ← `Rationale`.
- **Tools:** drive Select from `Get_ProgramTools` and reach into the expanded Tool lookup: `toolName` ← `Tool/Title`, `toolCategory` ← `Tool/field_1`, `toolDescription` ← `Tool/field_3`. (To get those expanded fields, set **Limit Columns by View** on Get_ProgramTools to a view that includes them, or add `$expand=Tool` via a manual workaround — simplest is just to reference `Tool/Title` directly; SharePoint expands single-value lookups automatically.)
- **Equivalencies:** `mappingTitle` ← `Title`, `whatsTheSame` ← `field_4`, `gotchas` ← `field_5`, `maturity` ← `field_6/Value`.
- **dailyTasks / weeklyTasks / monthlyTasks / quarterlyTasks:** all four read from `Get_OngoingTasks`. v1 schema has no `Cadence` field on tasks (v2 enhancement), so for v1 leave the four arrays empty: pass `[]` to the Word action for each, or skip the controls entirely.

### 2.8 Populate the Word template

- **+ New step → Word Online (Business) → Populate a Microsoft Word template.**
- **Location:** SharePoint Site.
- **Document Library:** Documents.
- **File:** browse to `/CookbookTemplates/Cookbook_Template_v1.docx`.
- The action will read the template's content controls and render an input field per control. Fill them:
  - Plain controls → expressions/dynamic content from `Get_Program`, `Get_TraineeProfile`, `Get_my_profile`. Examples:
    - `pcName` ← `outputs('Get_my_profile_(V2)')?['body/displayName']`
    - `pcEmail` ← `outputs('Get_my_profile_(V2)')?['body/mail']`
    - `programName` ← `outputs('Get_Program')?['body/Title']`
    - `customer` ← `outputs('Get_Program')?['body/Customer']`
    - `coverDate` ← `formatDateTime(utcNow(),'MMMM d, yyyy')`
    - `programDescription` ← `outputs('Get_Program')?['body/Description']`
  - v2-enhancement plain controls (`programLongName`, `positionPurpose`, `jobDuties`, `reportsSection`, `personalNotes`) — pass an empty string `''` or a placeholder like `'(See MANTLE to populate)'`.
  - Repeating-section controls — bind to the corresponding **Select** body, e.g., `body('Select_Meetings')`. Power Automate will surface the inner controls as keys; verify they match what the Select emits.

### 2.9 Save the file to SharePoint

- **+ New step → SharePoint → Create file.**
  - **Site Address:** MANTLE site.
  - **Folder Path:** `/Shared Documents/Cookbooks`.
  - **File Name:** `@{outputs('Get_my_profile_(V2)')?['body/displayName']}_@{outputs('Get_Program')?['body/Title']}_Cookbook_@{variables('runId')}.docx`
  - **File Content:** dynamic content → **Microsoft Word Document** (the body output of the Populate step).

### 2.10 Notify

- **+ New step → Office 365 Outlook → Send an email (V2).**
  - **To:** `outputs('Get_my_profile_(V2)')?['body/mail']`.
  - **Subject:** `Your MANTLE cookbook is ready — @{outputs('Get_Program')?['body/Title']}`.
  - **Body:** include the link from the Create file step's `Link to item` output.

Click **Save** at the top right.

---

## Phase 3 — Test

1. Pick a known program with at least 3 meetings, 3 stakeholders, and 5 acronyms populated. Note its `programId` (e.g., `3`).
2. In the flow page, click **Test → Manually → Save & Test**, then **Run flow**.
3. Enter `programId = 3` → **Run flow → Done**.
4. Watch the run. Each step should turn green within 30 seconds. Total runtime target: under 60 seconds.
5. Open the SharePoint library `/Documents/Cookbooks/`. The new `.docx` should be there. Open it.
6. Verify:
   - Cover block shows your name, email, the program name, today's date.
   - Meetings table has one row per meeting in that program, with cadence/day-time/role/responsibilities filled.
   - Stakeholders, acronyms, decisions sections are populated and sorted as expected.
   - Tools section reflects only tools currently linked to that program (no sunset entries).
   - Empty sections (e.g., dailyTasks if you skipped them) render the heading without rows — acceptable for v1.

---

## Phase 4 — Troubleshooting

**"Action 'Populate_a_Microsoft_Word_template' failed: invalid template."**
The template has a duplicate content control title or a control title with a space/hyphen. Open the template, **Developer → click each control → Properties**, and confirm every Title is unique camelCase, no spaces.

**Repeating section renders the right number of rows but cells are blank.**
Inner content control titles in the Word template don't match the keys emitted by your Select. Open the template, check the inner control titles; open the Select action, confirm the key names match exactly (case-sensitive). This is the single most common failure mode — design doc calls it out in section 4.

**Filter Query returns 0 items but you can see matching rows in SharePoint.**
- For Excel-imported lists, you used a display name instead of `field_N`. Fix per the crosswalk.
- For Yes/No fields, `eq false` failed silently on the gov tenant. Use `eq 0`.
- For Lookup columns, you used the column name alone instead of `<Column>/Id`. Use `Program/Id eq 3`, not `Program eq 3`.
- For Choice columns, you used the column name alone instead of `<Column>/Value`. Use `Cadence/Value eq 'Weekly'`.
- For Person columns, you used `mail` instead of `EMail`. Use `PC/EMail eq '...'`.

**Get items returns only 100 rows even though the list has 300.**
Default Top Count is 100. Set it explicitly. For lists that may exceed 5000, also enable **Settings (…) → Pagination → On**, threshold 5000.

**Lookup column shows up as a number, not the related text.**
You need `Column/Title` or `Column/Value`. Single-value lookups expand automatically in the action body if you reference `LookupColumn/Title` in dynamic content or expressions. Multi-value lookups return arrays — use a nested Select or `join(item()?['Programs'], ', ')` to flatten.

**Expression errors like "The template language function 'outputs' expects its parameter to be a string."**
Action names with spaces or hyphens must be referenced with underscores. `Get my profile (V2)` becomes `Get_my_profile_(V2)`. Always rename actions to underscore-friendly names early to avoid this.

**`triggerBody()?['programId']` returns null.**
Power Automate stored your number input under the key `number` (because it was the first Number input). Either rename the input *before* you save the flow the first time, or use `triggerBody()?['number']`. Inspect the trigger's raw output after the first test run to confirm the actual key.

**Create file step fails with "File already exists."**
The filename includes `runId` (a timestamp), so this should be rare. If it happens, either re-run (new timestamp) or change the conflict behavior in the action's settings.

**Word template content control is set to "cannot be edited."**
In Word, **Developer → Properties → uncheck "Content control cannot be deleted"** AND uncheck "Contents cannot be edited." Power Automate cannot fill locked controls.

---

## What's deliberately deferred to v2

- `Cadence` field on `30-60-90 Tasks` → Daily/Weekly/Monthly/Quarterly task arrays go empty in v1.
- `Programs.PC responsibilities` and `Programs.Reports notes` → `jobDuties` and `reportsSection` controls go empty / boilerplate-only.
- PDF conversion, Forms-based trigger, snapshot archive, customer-flavored template variants — all out of v1 scope per design doc section "Future enhancements."

When v2 schema additions land, the only flow change needed is updating the relevant Select projections to read the new fields. The template controls already exist.
