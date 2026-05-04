# PA Replacement: Process Welcome Responses

Companion to `scripts/process-welcome-responses.ps1`. This document captures the Power Automate flow that *would* run today if Power Automate were available on this tenant. The script is a temporary stand-in; nothing about MANTLE's data model changes when we swap.

## 1. What the script does today

The script reads an Excel export of Microsoft Forms responses (the user manually exports from `forms.office.com` and saves to a known inbox path), then for each row:

1. Checks whether a `Trainee Profile` already exists for that responder's email — if so, skips (idempotent).
2. Looks up the responder in the `PCs` list by email; if missing, auto-creates the row with `Status = Active`, `Contract = CPSS`.
3. Resolves the program name against the `Programs` list; if no match, auto-creates one with `Status = Pending Review` so an admin can clean it up later.
4. Creates a `Trainee Profile` linking PC + Program + start date + previous role context. `Tools they came from` is left blank — the user fills it in themselves from the live Lookup column on their profile (their first onboarding step).
5. Seeds 16 starter `30-60-90 Tasks`, due dates offset from the start date. The first task is "Welcome to MANTLE — review your profile and complete setup" (1-day offset). The remaining 15 are the standard onboarding plan.
6. **Best-effort:** creates a Planner task in the MANTLE Team's `30-60-90` board, `Days 1-30` bucket, assigned to the user. Triggers the user's Teams "task assigned to you" notification AND introduces Planner as a tool. Wrapped in try/catch — on failure, the SharePoint welcome task still serves as the in-platform nudge.
7. **Email confirmation is intentionally NOT sent.** That's a PA-only enhancement (see below) — SMTP/Send-MailMessage was removed from the script to avoid half-built email config that's fragile and tenant-specific.
8. Prints a `Processed / Skipped / Failed` summary.

The user runs this on demand (e.g., once a week, or after every batch of new submissions).

## 2. Power Automate equivalent

**Trigger:** Microsoft Forms — *When a new response is submitted*. Form Id = "MANTLE — Welcome".

**Action sequence:**

1. **Microsoft Forms — Get response details** (using the trigger's Response Id).
2. **Office 365 Users — Get user profile (V2)** — resolves submitter to display name, mail, job title.
3. **SharePoint — Get items** on `PCs`, filter `Email eq '{responder}'`, top 1.
4. **Condition** — if `length(items) == 0`, **Create item** in `PCs` (auto-create branch). Either way, end with a `Compose` named `pcId` so downstream steps reference one variable.
5. **SharePoint — Get items** on `Programs`, filter on Title. If empty, **Create item** with `Status = Pending Review`.
6. **SharePoint — Get items** on `Tools`, then **Apply to each** to build `varToolIds` array of matching IDs from the multi-select previous-tools answer.
7. **SharePoint — Create item** in `Trainee Profiles`, populating PC, Current program, Start date, Tools they came from (multi-lookup as `{ "results": [...] }`), Previous role context.
8. **Initialize variable** `varStarterTasks` with the same 16-task JSON array used in the script (first task = welcome/setup, remaining 15 = standard onboarding plan).
9. **Apply to each** over `varStarterTasks` → **SharePoint — Create item** in `30-60-90 Tasks` with `Due date = addDays(startDate, offsetDays)`.
10. **Planner — Create a task** in the MANTLE Team's `30-60-90` plan, `Days 1-30` bucket, assigned to the responder. Title: "Welcome to MANTLE — complete your profile setup." (Reliable in PA — no try/catch wrapping needed unlike the script version.)
11. **Office 365 Outlook — Send an email (V2)** to the responder with deep links to the new Trainee Profile and the 30-60-90 Tasks list. **This is the PA-only enhancement** — the script does NOT send email; PA does.

**Connector requirements:** Microsoft Forms, SharePoint, Office 365 Users, Office 365 Outlook — all standard connectors. **No premium connectors required.**

## 3. Migration steps (script -> flow)

The two are functionally equivalent in their effect on SharePoint, so swap is low-risk:

1. Build the flow following `design/welcome-form-build-guide.md`.
2. Test it end-to-end with one or two submissions. Verify Trainee Profile + 15 tasks appear.
3. Re-run the script one final time against the inbox xlsx to drain any backlog the flow didn't catch.
4. Disable the script (move to `scripts/_archive/`) and stop exporting from Forms manually.
5. Keep the auto-create-PC and auto-create-Program patterns identical — both flow and script tag auto-created rows with a `Notes` flag so an admin can review weekly.

The Trainee Profile uniqueness check (existing-profile-by-email) prevents double-processing if the script and flow are ever run in parallel during transition.

## 4. Trade-offs

| Dimension | Script | Flow |
|-----------|--------|------|
| Latency | Manual / batched (whenever user runs it) | Real-time on submit |
| Tenant requirements | None beyond SharePoint + Excel | Power Automate license |
| Visibility into failures | Console output, ad-hoc | Run history, retry, owner notifications |
| Maintenance | Edit a `.ps1` in git | Edit in browser, less version control |
| Observability | None until next run | Built-in flow analytics |
| Cost | Free | Per-flow license depending on plan |

The script wins on tenant-portability and version control; the flow wins on responsiveness and operational visibility. The right move is to keep the script as a backstop even after the flow ships, in case the flow is ever deactivated by tenant policy.
