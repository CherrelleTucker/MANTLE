# Welcome Form + Intake — Build Guide

This is the click-by-click implementation guide for the MANTLE Welcome Form and the intake processing that creates a Trainee Profile and seeds 30-60-90 tasks. Source of truth for behavior is `design/welcome-flow.md`; data shapes come from `data-model/schemas.md`.

---

## 1. Decisions made up front

1. **One Form, with branching.** A single Microsoft Form covers both incoming and outgoing PCs. Question 1 is the mode selector and "Add branching" routes the rest. Two Forms doubles the maintenance surface.
2. **Power Automate is BLOCKED on this tenant.** `make.powerautomate.com` returns *"Your organization doesn't allow access via your work or school email."* Until that policy changes, intake runs through a local PowerShell script (`process-welcome-responses.ps1`, written separately) executed by the admin on cadence. Phase 5 of this guide preserves the PA design as a documented bridge for the day PA is unblocked.
3. **Auto-create missing PCs.** If the submitter's email doesn't match a row in the `PCs` list, the script creates a `PCs` row first with `Status = Active` and a `Notes` flag (`Auto-created by Welcome Form — review`), then proceeds. Failing the run leaves the user with a broken-feeling experience for a recoverable condition.
4. **Confirmation email is sent by the script** at processing time, not by the Form itself. The submitter gets a "you submitted" toast from Forms immediately; the real welcome email arrives when the admin runs the script.
5. **Q5 (previous tools) is NOT on the Form.** It moves to a post-intake step on the user's own Trainee Profile, where they multi-select from the live `Tools` Lookup. This dodges the Forms-can't-be-dynamic-from-SharePoint problem.
6. **Q4 (program) IS on the Form**, hardcoded as a Choice. The maintenance burden is accepted: when a new program is added to `Programs`, this Form's Q4 choices must be updated by hand. Documented below.
7. **Q8 (anything else) is dropped.** The destination for free-form text was unclear; not worth the friction.

---

## 2. Prerequisites

| Need | Where |
|------|-------|
| M365 work account on the NASA tenant | already provisioned |
| SharePoint site | `https://nasa.sharepoint.com/teams/PCTransitionSandbox` |
| All MANTLE Lists exist | `PCs`, `Trainee Profiles`, `Programs`, `30-60-90 Tasks`, `Tools`, `Stakeholders`, `Meetings`, `Acronyms`, `Decisions Log` |
| Microsoft Forms | `https://forms.office.com` (confirmed accessible) |
| PowerShell 5.1+ with `PnP.PowerShell` module installed | local laptop; `Install-Module PnP.PowerShell -Scope CurrentUser` |
| Permissions | Edit on the SharePoint site; ability to download Forms responses to Excel; mailbox to send confirmation emails from |
| Power Automate | **BLOCKED on this tenant** — see Phase 5 for the future-state design |

Before you start: confirm the internal SharePoint column names by opening each List → **Settings** → **List settings** → **Columns**. Lookup column **internal names** are what the script references (`PC` for the lookup, `PCId` for the underlying ID). The script needs those exact names.

---

## 3. Phase 1 — Build the Welcome Form

Go to `https://forms.office.com` → **+ New Form**. Title it **MANTLE — Welcome**. Description: *"Welcome. You're in the right place. MANTLE — Manual, Acronyms, Notes, Transition, Logistics, Engagement. Two minutes to set you up."*

Form **Settings** (gear icon, top right):
- *Who can fill out this form*: **Only people in my organization can respond**
- **Record name**: ON (this captures submitter email automatically — the script keys on it)
- **One response per person**: OFF (a PC may revisit on a new assignment)

Build the questions in the order below. After all questions exist, set up branching at the end.

### Q1 — Mode (Choice, Required) — asked of EVERYONE

Title: **What brings you here today?**
Choices:
- `I'm starting a new role`
- `I'm wrapping up my role`

**Required**: ON. This is the branching pivot.

### Q2 — Confirm name (Short text, Optional) — asked of EVERYONE

Title: **Your name**
Subtitle: *"Auto-filled — edit if needed."*
Type: Short text. Required: OFF. (The auto-recorded responder name from M365 is the source of truth; this is a confirmation field.)

---

#### INCOMING branch (asked when Q1 = "I'm starting a new role")

### Q3 — Start date in your NEW role (Date, Optional) — asked of INCOMING PC

Title: **Start date in your new role**
Subtitle: *"Default is today. Skip if you don't know yet."*
Type: Date. Required: OFF.

### Q4 — Program you are JOINING (Choice, Optional) — asked of INCOMING PC

Title: **Which program are you joining?**
Subtitle: *"Pick the program you're being assigned to. If you're not sure yet, pick 'Not yet assigned'."*
Type: Choice. **Drop down**: ON.
Required: OFF.

Choices — hardcoded, one per current program plus the two catch-alls:
- `[Program A]`
- `[Program B]`
- `[Program C]`
- *(... one entry per row in the `Programs` List where `Status = Active`)*
- `Not yet assigned`
- `Other`

**Maintenance pattern (don't skip this):** This Form is NOT dynamically bound to the `Programs` List — Microsoft Forms cannot pull choices from SharePoint. When a program is added to `Programs`, you MUST update this Form by hand:
1. Open the Form in `forms.office.com` → click Q4 → add the new choice (drag to position above `Not yet assigned`).
2. Note the change in the `Decisions Log` so the next admin knows when the choice list last drifted from `Programs`.
3. The script's program-resolution step matches the response string against `Programs.Title`, so the spelling on the Form must match the List exactly.

If a submitter picks `Not yet assigned` or `Other`, the script leaves the Trainee Profile's `Current program` lookup blank.

---

#### OUTGOING branch (asked when Q1 = "I'm wrapping up my role")

### Q6 — Last day in role (Date, Optional) — asked of OUTGOING PC

Title: **Your last day in role**
Type: Date. Required: OFF.

### Q7 — Overlap with replacement (Choice, Optional) — asked of OUTGOING PC

Title: **How much overlap do you have with your replacement?**
Type: Choice. Choices: `None`, `1-2 weeks`, `1+ month`, `Unknown`.
Required: OFF.

---

### What is NOT on this Form (and where it lives instead)

- **Previous tools.** Asked AFTER intake, on the new PC's Trainee Profile, via the live `Tools they came from` Lookup column. See Phase 4.
- **"Anything else"** free-form. Dropped — destination was unclear.

### Branching

In the Form, click `…` (top right) → **Branching**.

Branching map:
```
Q1 ─┬─ "I'm starting a new role"  ─→ Q2 → Q3 → Q4 → END
    └─ "I'm wrapping up my role"  ─→ Q2 → Q6 → Q7 → END
```

Configure:
- On **Q1**: if `I'm starting a new role` → go to **Q2**. If `I'm wrapping up my role` → also go to **Q2** (Q2 is shared; branching diverges after it).
- On **Q2**: leave at default (proceed to Q3) — Forms branching can only branch from one source. To make Q2 route correctly, instead use this pattern: set **Q2's "Go to"** to *Next*, and on **Q3** set its "Go to" to *End of form* if Q1 was outgoing. The simpler equivalent in the Forms UI:
  - On **Q1**: `I'm starting a new role` → **Q2**, `I'm wrapping up my role` → **Q2**.
  - On **Q3**'s settings, leave default. On **Q4**'s settings → **Go to** → *End of form*.
  - On **Q2**'s settings → **Go to** → conditional isn't directly supported; simulate by placing Q6 immediately after Q4 in Form order, and on Q4 → **Go to** → *End of form*. Then on Q2 → **Go to** → *Next* (which is Q3 for incoming). Outgoing flow needs Q2 to skip to Q6 — set a second branching rule on Q1 itself: outgoing → **Q6** (skipping Q2 entirely; Q2 is optional and incoming-favored).

If the Forms branching UI fights you, the cleanest fallback is: **on Q1, route incoming → Q2 (then Q2 → Q3 → Q4 → End) and route outgoing → Q6 (then Q6 → Q7 → End)**. Outgoing PCs simply don't get a name confirmation prompt; the M365-recorded name is enough.

### Publish & share

Click **Collect responses**. Set audience to **Only people in my organization can respond**. Copy the link. On the MANTLE SharePoint home page, paste it as a hero button labeled **Start here**. Optionally embed in the Teams channel via **+ → Forms → Add an existing form → Collect responses**.

---

## 4. Phase 2 — Manual processing via PowerShell (TODAY's flow)

This is the active intake path until Power Automate is unblocked. The script is written separately; this section documents the operating procedure around it.

### Where Form responses live

- **Native:** in the Form itself — `forms.office.com` → MANTLE — Welcome → **Responses** tab.
- **Excel summary (auto-linked):** in **Responses** → click **Open in Excel**. Forms creates a workbook in the OneDrive of the Form's owner at `OneDrive - NASA / Apps / Microsoft Forms / MANTLE — Welcome / MANTLE — Welcome (Responses).xlsx`. New responses append automatically. This file is what the script reads.

Confirm the workbook path the first time you open it; the script's `$ResponsesPath` parameter must match.

### Processing cadence

- Run the script **weekly** (Mondays, mid-morning) and **on-demand** when you know a new PC just submitted (e.g., they Slacked you).
- The script tracks which response IDs it has already processed (in a small state file alongside it) so re-runs are safe and idempotent.

### What the script does (summary — full logic in the script file)

For each new (unprocessed) response:
1. Read the row from the responses workbook.
2. Look up the submitter in `PCs` by email.
   - **If found:** capture the PC's ID.
   - **If not found:** create a new `PCs` row (`Coordinator Name`, `Email`, `Status = Active`, `Contract = CPSS`, `Hire date = today`, `Notes = "Auto-created by Welcome Form — review."`) and capture the new ID.
3. Resolve `Programs.Title` against the Q4 response string. Empty if `Not yet assigned`, `Other`, or outgoing mode.
4. Create a `Trainee Profiles` row:
   - `Profile Name`: `<Display name> — <Program or "Pending">`
   - `PC Id`: from step 2
   - `Current program Id`: from step 3 (or blank)
   - `Start date in current role`: Q3 response, or today if blank
   - `Tools they came from`: **left blank** — filled by the PC themselves in Phase 4
   - `Previous role context`: blank
5. Seed 30-60-90 tasks (sixteen-task starter set defined in the script's task array — first task is the Welcome/setup task; remaining fifteen are the standard onboarding plan).
6. **Best-effort** create a Planner task in the MANTLE Team's `30-60-90` board, `Days 1-30` bucket, assigned to the user. This gives them a Teams notification AND introduces Planner. If the Planner cmdlets aren't available or the call fails, the script logs a friendly note and continues — the SharePoint welcome task still serves as the in-platform nudge.
7. Append the response ID to the processed-state file.

**Notification design (today, no PA, no email):**
- The user's first 30-60-90 task ("Welcome to MANTLE — review your profile and complete setup") is the persistent in-platform welcome. They see it whenever they open MANTLE.
- The Planner task (best-effort) gives them a Teams "task assigned to you" notification AND surfaces Planner as a tool they can use.
- **Email confirmation is intentionally NOT implemented.** That's a Power Automate enhancement — see Phase 3.

### Script location and parameters

```
C:\Users\cjtucke3\Documents\Personal\Career\MANTLE\scripts\process-welcome-responses.ps1
```

Parameters (defined in the script header — see the script itself for current signatures):
- `-ResponsesPath` — path to the Forms-Excel workbook
- `-SiteUrl` — `https://nasa.sharepoint.com/teams/PCTransitionSandbox`
- `-StateFile` — path to the processed-IDs state file
- `-DryRun` — preview without writing

Run it from a PowerShell prompt with the SharePoint site already authenticated (`Connect-PnPOnline -Url <SiteUrl> -Interactive`).

### Operational hygiene

- After each run, scan the `PCs` list filtered to `Notes contains "Auto-created"` and reconcile any new auto-created rows (correct the contract field, confirm the email, etc.).
- If the script errors on a row, fix the underlying data (e.g., a typo in the Q4 program string vs. the `Programs.Title`) and re-run. The state file ensures already-processed rows aren't re-created.

---

## 5. Phase 3 — Future Power Automate replacement (when PA is enabled)

Preserved as design reference. When IT enables Power Automate on this tenant — or the user moves to a tenant that allows it — the script-based flow can be replaced by a real cloud flow. A future admin should be able to read this section and build the flow without redesigning.

### Trigger

`make.powerautomate.com` → **+ Create** → **Automated cloud flow**.
Name: **MANTLE — Welcome Form Intake**. Trigger: **When a new response is submitted** (Microsoft Forms). Form Id: **MANTLE — Welcome** (pick from dropdown — don't paste an ID).

### Step 1 — Get response details

**Microsoft Forms → Get response details.** Form Id: **MANTLE — Welcome**. Response Id: dynamic content `Response Id` from trigger.

### Step 2 — Resolve submitter to a PC row

**Office 365 Users → Get user profile (V2).** User: dynamic content `Responder's Email`.

**SharePoint → Get items.** Site: `…/PCTransitionSandbox`. List: **PCs**. Filter Query: `Email eq '@{triggerOutputs()?['body/responder']}'`. Top Count: `1`.

**Initialize variable** `varPcId` (Integer) at the top of the flow.

**Condition:** `length(outputs('Get_items')?['body/value'])` is equal to `0`.
- **Yes:** SharePoint → Create item on `PCs` (Coordinator Name = displayName, Email = responder, Status = Active, Contract = CPSS, Hire date = utcNow(), Notes = "Auto-created by Welcome Form intake — please review."). Set `varPcId` from `body('Create_item')?['ID']`.
- **No:** Set `varPcId` from `first(outputs('Get_items')?['body/value'])?['ID']`.

### Step 3 — Resolve Program lookup

**SharePoint → Get items.** List: **Programs**. Filter Query: `Title eq '@{body('Get_response_details')?['<Q4 questionId>']}'`. Top Count: `1`.

**Initialize variable** `varProgramId` (Integer). Set from `first(outputs('Get_items_2')?['body/value'])?['ID']`. Empty if `Not yet assigned`, `Other`, or outgoing mode.

### Step 4 — Create the Trainee Profile

**SharePoint → Create item.** List: **Trainee Profiles**.
- `Profile Name`: `concat(outputs('Get_user_profile_(V2)')?['body/displayName'], ' — ', coalesce(body('Get_response_details')?['<Q4 questionId>'], 'Pending'))`
- `PC Id`: `variables('varPcId')`
- `Current program Id`: `variables('varProgramId')` (leave blank if null)
- `Start date in current role`: `body('Get_response_details')?['<Q3 questionId>']` with `utcNow()` fallback
- `Tools they came from`: **leave blank** — the PC fills this themselves in Phase 4. Do not try to build a multi-lookup from a Form question; that whole branch was the original blocker.

Save profile ID into `varProfileId`.

### Step 5 — Seed 30-60-90 starter tasks

**Initialize variable** `varStarterTasks` (Array) with the fifteen-task JSON from the script.

**Apply to each** over `variables('varStarterTasks')` → SharePoint → Create item on `30-60-90 Tasks` (Task = title, PC Id = varPcId, Phase = phase, Lane = lane, Status = `Not Started`, Due date = `addDays(<startDate or utcNow>, offsetDays)`, Notes = notes).

### Step 6 — Confirmation email

**Office 365 Outlook → Send an email (V2).** To: Responder's Email. Subject: `Welcome to MANTLE — your space is ready`. HTML body with deep links to Teams channel, Trainee Profile (`DispForm.aspx?ID=@{variables('varProfileId')}`), and the 30-60-90 list.

### Notes for the future admin

- Lookup column internal names use `Id` suffix and `_x0020_` for spaces (`Current_x0020_programId`).
- The Forms connection must be signed in to the same NASA work account that owns the Form — check the connection in the trigger card's bottom-right.
- Branch on Q1 mode if you want to skip task seeding for outgoing PCs (the script does seed them; the rationale is that the fifteen tasks double as a wrap-up checklist).
- **Decommissioning the script:** flip the script's state file to mark all PA-processed responses as already-done so the script doesn't double-create.

---

## 6. Phase 4 — After intake: completing the Trainee Profile

The new PC has a Trainee Profile, but the `Tools they came from` field is intentionally blank from intake. They fill it in themselves — once — using the live `Tools` Lookup. This is what removes the dynamic-options problem from the Form.

This is also seeded as the **first task** in the 30-60-90 plan ("Open your Trainee Profile and fill in your previous tools"), so it appears in the new PC's task list automatically.

### Step-by-step for the new PC

1. Open the MANTLE Teams channel → **Trainee Profiles** tab (or the SharePoint List directly).
2. Find your row (search by your name or filter on `PC = [Me]`).
3. Click your `Profile Name` to open the item.
4. Click **Edit**.
5. **Tools they came from** — multi-select from the dropdown. Pick every tool you used in your previous role. The dropdown lists every row in the live `Tools` List, so when admins add a new tool, it shows up here automatically — no Form maintenance, ever.
6. **Previous role context** — optional free-form. One paragraph on what your previous role looked like, if useful to your replacement-of-replacement someday.
7. **Save**.

This unlocks the **For Me** view of the `Equivalency Map` (filtered to `From-Tool ∈ your previous tools` AND `To-Tool ∈ your current program's tools`).

---

## 7. Phase 5 — Test the flow

1. From the Form's **Collect responses** link, submit a test response as yourself. Pick `I'm starting a new role`, fill all fields, submit.
2. Confirm the response appears in the Form's **Responses** tab and in the auto-linked Excel workbook (refresh Excel if needed).
3. Run `process-welcome-responses.ps1 -DryRun` first; review the planned actions in the console output.
4. Run it for real (drop `-DryRun`). Confirm the console reports a Trainee Profile created, fifteen tasks seeded, and an email sent.
5. Open **Trainee Profiles** — your new row should exist with name, program, start date, and `Tools they came from` blank.
6. Open **30-60-90 Tasks** filtered by `PC = [your name]`. Fifteen rows should exist, three phases, due dates spread from your start date.
7. Check your inbox for the confirmation email. Click both deep links.
8. Submit a second response with outgoing-mode answers. Re-run the script. Confirm a Trainee Profile + tasks were still created (the tasks double as a wrap-up checklist).
9. Submit a third response from a test account whose email is **not** in the `PCs` list. Re-run. Confirm a new `PCs` row was auto-created with `Notes = "Auto-created by Welcome Form — review."`
10. Walk Phase 4 yourself: open the Trainee Profile, fill in `Tools they came from`, save. Confirm the **For Me** view of `Equivalency Map` now shows relevant rows.

---

## 8. Troubleshooting

**Q4 program choice doesn't match a `Programs` row.** The Form's choice string drifted from `Programs.Title`. Either rename the program in `Programs` to match, or update the Form's choice to match the List exactly. The script will leave `Current program` blank when it can't resolve.

**Submitter's email not captured (`Responder's Email` blank).** Form Settings → ensure **Record name** is ON and audience is restricted to the org. Anonymous responses don't include identity, and the script keys on the email column.

**Auto-created PCs accumulating.** Add a view to `PCs` filtered to `Notes contains "Auto-created"` and review weekly. Edit each row to confirm contract details, then clear the auto-create flag from `Notes`.

**Script can't find the responses workbook.** Forms saves the auto-linked Excel under the **Form owner's** OneDrive, not necessarily yours. If the Form is co-owned, only the original creator's OneDrive holds the file. Confirm the path with a fresh **Open in Excel** click and update `-ResponsesPath`.

**SharePoint lookup column won't accept a value from the script.** Lookups need the **ID**, not the display string. Field names are the lookup name plus `Id` (e.g., `PCId`, `Current_x0020_programId` — spaces become `_x0020_`). Check the column's internal name in List settings.

**`addDays` errors on a null start date.** The script wraps the start date with a `?? (Get-Date)` fallback before computing offsets. If you see the error, the fallback path got skipped — log the offending row and patch.

**Email send fails ("REST API is not yet supported for this mailbox").** The mailbox the script is sending from is a service principal or unlicensed shared mailbox. Run the script as your own NASA mailbox, or switch to `Send-MgUserMail` with a delegated Graph permission.

**Forms branching skips a question that should appear.** Forms branching only fires when explicitly configured per-question. After every edit to question order, click `…` → **Branching** and re-verify the routing matches the map in Phase 1.

**Power Automate is now enabled — what now?** Build the Phase 5 flow. Then in the script, mark all currently-pending responses as processed (so they don't get double-handled), and disable the script's scheduled run. Keep the script in source control as the documented fallback if PA is ever re-blocked.

---

That's the whole feature today: one Form (two questions for everyone, two more on either branch), one PowerShell script run weekly, fifteen seeded tasks, one self-service tools-fill step on the Trainee Profile, one confirmation email. Ship it, then iterate on what real submissions reveal — and keep Phase 5 alive for the day Power Automate is unblocked.
