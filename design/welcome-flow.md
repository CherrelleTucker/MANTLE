# Welcome Flow

Two user modes — incoming and outgoing — share a common landing page and diverge based on user choice. Both flows assume the user is already authenticated to M365 (no separate sign-in).

---

## Shared landing page

Calm, single hero message. *"Welcome. You're in the right place."*

Subtitle: *"KITCHEN — Knowledge, Interviews, Transitions, Cookbooks, Handoffs, Equivalencies, Network. Knowledge collected by every coordinator who's done this role before you, so you don't have to start cold."*

Two large primary cards (soft choice — not a hard modal):
- 🚀 **I'm starting a new role** → Scenario A
- 📦 **I'm wrapping up my role** → Scenario B

Subtle third option:
- *Returning user — take me to my dashboard* (auto-detected if a Trainee Profile exists for this user)

---

## Scenario A — Incoming PC

### A1 — Intake (90 seconds, all fields skip-able)

Auto-fills Name + Email from M365 sign-in. Asks:
- Start date *(default = today)*
- Program/customer *(dropdown of known programs; "Not yet assigned" option)*
- Your previous tools *(multi-select: Slack, Google Workspace, Asana, Teams, Notion, Mattermost, Discord, etc.)*

Submit → routes to A2.

### A2 — Welcome

> *"Welcome to [Program]. Here's what's waiting for you."*

Branches based on platform state:

- **Predecessor populated content exists:** *"Your predecessor [Name] left you N stakeholders, M meetings, and K sections of cookbook content. Walk through it now or save for later?"*
- **No predecessor / empty:** *"No predecessor handed off — that's normal at NASA. Here's what every coordinator has access to anyway,"* and surfaces shared Tier 1 content (NASA acronyms, travel SOP, equivalency map, meeting scheduling best practices).

Three primary actions:
- **Take a 5-minute tour** *(interactive checklist, not video)*
- **Show me my Day-1 Essentials** *(recommended — bold)*
- **Let me explore on my own**

### A3 — Day-1 Essentials checklist (interactive)

Five cards, each a clickable action that navigates somewhere useful:
1. Read your role baseline *(1 min)* → opens role doc
2. Open the meeting catalog *(5 min)* → opens Meetings List
3. Browse the NASA acronyms *(2 min)* → opens Acronyms List with prominent search
4. Add your first stakeholder *(5 min)* → opens Stakeholders List with quick-add modal
5. Schedule your 30-day supervisor check-in *(1 min)* → opens Outlook with template

Each completed → green ✓, progress bar fills. The platform learns you by doing the platform.

---

## Scenario B — Outgoing PC

### B1 — Intake (60 seconds, all fields skip-able)

Auto-fills Name + Email. Asks:
- Last day in role *(date picker)*
- Overlap with replacement *(radio: None / 1-2 weeks / 1+ month / Unknown)*

Submit → routes to B2.

### B2 — Welcome

> *"Let's make sure your replacement isn't lost."*

Visible progress bar: *"Your handover is X% complete based on what you've already captured."* (First-timers near 0%; returning sessions show accumulated progress.)

Reassurance: *"Small chunks. You don't have to dump everything today."*

Three primary actions:
- **5-minute Quick Capture** *(today's chunk — bold/recommended)*
- **Work on a section** *(longer, ~30 min)*
- **See where my handover stands** *(review what's there)*

### B3a — Quick Capture (small daily chunk)

Three short prompts, surfaced one at a time:
1. *"Name one stakeholder your replacement needs to know about. (Name + one sentence on why.)"*
2. *"Name an acronym someone confused could ask you about today."*
3. *"What's one thing you do every Monday that's not in any document?"*

Submit → *"Done. Come back tomorrow for 3 more."* Each answer routes automatically into the matching structured List.

### B3b — Section Work (longer chunk)

Section picker showing visible progress per section:
```
Meetings           ▓▓▓░░░░░  30%
Stakeholders       ▓░░░░░░░  10%
Projects           ░░░░░░░░   0%
Recurring tasks    ▓▓▓▓░░░░  45%
Tools & gotchas    ░░░░░░░░   0%
Personal notes     ▓░░░░░░░  15%
```

Click any section → structured quick-add form for that type. Optimized for adding several entries in one sitting.

---

## Asymmetric data ownership

A core design principle: *what each user supplies depends on what they uniquely know*.

| Data | Who knows it | Where it lives |
|------|--------------|----------------|
| User's previous tools (the "from" side of the equivalency map) | Only the user themselves | Trainee Profile (per user) |
| Program's current tools (the "to" side) | Anyone on the program team | Program record (per program) |
| Stakeholders / meetings / acronyms | Anyone exposed to them | Per-program shared Lists |
| Personal annotations / running notes | Only the individual | Personal Lists (item-level permissions) |

The outgoing PC is *not* asked about their replacement's previous tools — they have no way to know. The replacement supplies that themselves on intake.

---

## Skip is sacred

Every intake field has Skip. Friction kills adoption.

## Returning users

Auto-detect from Trainee Profiles List. If a row exists for the signed-in user, skip intake and go straight to dashboard. No re-onboarding.
