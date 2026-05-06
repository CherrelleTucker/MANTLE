# PA Replacement: Stale Stakeholder Check

Companion to `scripts/check-stale-stakeholders.ps1`. This describes the scheduled Power Automate flow that would replace the script when PA is available.

## 1. What the script does today

A PC runs `check-stale-stakeholders.ps1` (optionally with `-PCName` and `-OutputFormat Console|File|OneNote`). The script:

1. Resolves the owning PC: from `-PCName` arg, or via the logged-in user's UPN matched against the `PCs.Email` column.
2. Pulls all `Stakeholders` and filters to those whose `Owner` field matches.
3. For each, computes `daysSince = today - LastContact` (or 99999 if never contacted).
4. Looks up `maxDays` from the Cadence: `Weekly=7`, `Bi-weekly=14`, `Monthly=30`, `Quarterly=90`, `Ad hoc=999` (i.e., never auto-stale).
5. Marks stakeholders where `daysSince > maxDays` as stale, sorts by `DaysOverdue` desc.
6. Outputs to console (formatted table), to a markdown file under `reports/`, or — once implemented — to OneNote.

The intent is a recurring health check: "Who am I overdue with?"

## 2. Power Automate equivalent

This is the cleanest of the three to migrate — the flow is naturally scheduled, easy to design, and has no premium-connector dependencies.

**Trigger:** **Recurrence** — weekly, Monday 7:00 AM local time.

**Action sequence:**

1. **SharePoint — Get items** on `Stakeholders` with no filter (or filter by `Owner` display name to scope to a specific PC; for an org-wide flow, leave unfiltered).
2. **Initialize variable** `varStale` (Array).
3. **Apply to each** stakeholder:
   - **Compose** `maxDays` via a `switch` expression on Cadence (or a chained `if`):
     `if(equals(item()?['Cadence/Value'], 'Weekly'), 7, if(equals(...), 14, if(...)))`
   - **Compose** `daysSince` = `div(sub(ticks(utcNow()), ticks(if(empty(item()?['LastContact']), '1900-01-01', item()?['LastContact']))), 864000000000)`.
   - **Condition** if `daysSince > maxDays`: **Append to array variable** `varStale` with name, org, cadence, days overdue.
4. **Condition** if `length(varStale) > 0`:
   - **Create HTML table** from `varStale`.
   - **Office 365 Outlook — Send an email (V2)** to the Owner (or to each Owner via grouping; for a per-PC flow, simplify and email a single recipient).
5. *(Optional)* **OneNote (Business) — Create page in a section** to log the report into the PC's KITCHEN notebook.
6. *(Optional)* **Microsoft Teams — Post a message in a chat or channel** to ping the PC.

**Connector requirements:** SharePoint, Office 365 Outlook, OneNote (Business), Teams — all standard.

**Premium connectors needed:** None.

## 3. Migration steps (script -> flow)

1. Build the flow per the action sequence. Test by setting `LastContact` on one record to 200 days ago and triggering the flow manually.
2. Confirm the email arrives with the right rows.
3. Set the recurrence to weekly.
4. Stop running the script (or keep it as an ad-hoc tool for "show me right now").
5. To support multiple PCs cleanly, either:
   - Create one flow per PC with the recurrence and the Owner filter baked in, or
   - Create one flow that reads all stakeholders, groups by Owner, and sends one email per Owner using **Apply to each** over a `Select` of distinct owners.

Per-PC flows are simpler to author and own (each PC owns their own); a fan-out flow is more efficient at scale but harder to debug.

## 4. Trade-offs

| Dimension | Script | Flow |
|-----------|--------|------|
| Cadence | Manual ("did I run it this week?") | Automatic, never forgotten |
| Notification surface | Console / file | Email, OneNote, Teams ping — pushable |
| Per-PC personalization | One run per PC, with `-PCName` | One flow per PC, or fan-out |
| Owner filter logic | PowerShell objects, easy to reason about | `item()?['Owner/EMail']` expressions, fiddlier |
| Cost | Zero | Zero (no premium connectors) |
| Visibility for the rest of the team | None unless shared | Email/Teams makes it social |

The flow is the obvious right answer for this one: it's free, scheduled, and notifies. The only reason to keep the script is for ad-hoc "show me the stale list right now" without waiting for the next Monday email — and that's a real enough use case to keep the script in the repo even after the flow is live.
