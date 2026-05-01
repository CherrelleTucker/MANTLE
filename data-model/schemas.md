# Data Model

All data lives in SharePoint Lists within a single Communication Site (provisioned via Team creation). Lists are typed, support multiple views, and are joined by Lookup columns to form a small relational model.

---

## List inventory

| List | Purpose | Tier |
|------|---------|------|
| `Programs` | NASA programs/customers being supported | 2 |
| `PCs` | Every Project Coordinator (active or past) | 1 (catalog) |
| `Trainee Profiles` | Per-PC personalization (start date, tools, current assignment) | 3 |
| `Meetings` | Recurring meeting catalog per program | 2 |
| `Stakeholders` | People the role touches | 2-3 (mostly shared, some private) |
| `Acronyms` | Glossary | 1-2 |
| `Tools` | Catalog of tools used across NASA | 1 |
| `Equivalency Map` | Cross-tool mappings (Slack ↔ Teams, etc.) | 1 |
| `30-60-90 Tasks` | Personal onboarding/transition tasks | 3 |
| `Decisions Log` | What was decided, by whom, when, why | 2 |
| `PC↔Program History` | Junction: PC + Program + dates + role | 1 |
| `Program↔Tool` | Junction: which programs use which tools | 1-2 |

---

## Schema details

### `Programs`
| Field | Type | Notes |
|-------|------|-------|
| Title | Single line of text | Program name |
| Customer | Single line of text | Sponsor / customer org |
| Center | Choice | MSFC, GSFC, JPL, ARC, LaRC, GRC, JSC, KSC, SSC, AFRC, WFF, MAF, HQ |
| Status | Choice | Active, Inactive, Sunset |
| Description | Multiple lines of text | Public-facing description |
| Lead | Person or Group | Civil servant lead |
| PM | Person or Group | Project Manager |
| Tools used | Lookup → Tools (multi) | Maintained as the program adopts/sunsets tools |
| Last verified | Date | When the record was last reviewed |

### `PCs`
| Field | Type | Notes |
|-------|------|-------|
| Title | Single line of text | Full name |
| Email | Single line of text | NASA email |
| Status | Choice | Active, Departed |
| Employer | Choice | Barrios, ASRC Federal, BAH, SSAI, USRA, Other |
| Hire date | Date | When they joined the contract |

### `Trainee Profiles`
| Field | Type | Notes |
|-------|------|-------|
| PC | Lookup → PCs | One-to-one |
| Current program | Lookup → Programs | |
| Start date in current role | Date | Anchors the 30-60-90 |
| Tools they came from | Lookup → Tools (multi) | Drives Equivalency Map filter |
| Previous role context | Multiple lines of text | Optional free-form |

### `Meetings`
| Field | Type | Notes |
|-------|------|-------|
| Title | Single line of text | Meeting name |
| Program | Lookup → Programs | |
| Cadence | Choice | Daily, Weekly, Bi-weekly, Monthly, Quarterly, Annual, Ad hoc |
| Day & time | Single line of text | Free-form, e.g., "Wednesdays 2-3 PM CT" |
| Type | Choice | Internal, External, Reporting, Informational |
| Owner | Person or Group | Meeting owner (not necessarily the PC) |
| PC role | Choice | Lead, Co-lead, Participant, Observer, Optional |
| PC responsibilities | Multiple lines of text | What the PC does for this meeting |
| Resources | Multiple lines of text | Links and notes location |
| Last verified | Date | |

### `Stakeholders`
| Field | Type | Notes |
|-------|------|-------|
| Title | Single line of text | Full name |
| Role | Single line of text | |
| Org / Team | Single line of text | |
| Programs | Lookup → Programs (multi) | A stakeholder may touch multiple programs |
| Influence | Choice | High, Medium, Low |
| Interest | Choice | High, Medium, Low |
| Relationship status | Choice | Strong, Neutral, Strained, Unknown |
| First met | Date | |
| Last contact | Date | Drives stale view |
| Cadence | Choice | Weekly, Bi-weekly, Monthly, Quarterly, Ad hoc |
| Sensitive? | Yes/No | Flagged with red formatting; restricts visibility |
| Notes | Multiple lines of text | Personal annotations from each PC who knows them |
| Owner | Person or Group | The PC who owns this entry |

### `Acronyms`
| Field | Type | Notes |
|-------|------|-------|
| Title | Single line of text | The acronym (indexed for search) |
| Expansion | Single line of text | What it stands for |
| Context | Choice | Agency, Center, Program, Project, Industry |
| Programs | Lookup → Programs (multi) | Optional — for program-specific acronyms |
| Source | Single line of text | Who/where the acronym came from |
| Notes | Multiple lines of text | Disambiguation if multiple meanings |

### `Tools`
| Field | Type | Notes |
|-------|------|-------|
| Title | Single line of text | Tool name |
| Category | Choice | Chat, Docs, Storage, Project Mgmt, Email, Calendar, Notes, Forms, Automation, Dashboards, Identity, Other |
| Vendor | Single line of text | |
| Description | Multiple lines of text | What it does in plain language |

### `Equivalency Map`
| Field | Type | Notes |
|-------|------|-------|
| Title | Single line of text | "From-Tool → To-Tool" |
| Category | Choice | Same as Tools.Category |
| From-Tool | Lookup → Tools | |
| To-Tool | Lookup → Tools | |
| What's the same | Multiple lines of text | |
| Gotchas | Multiple lines of text | What differs that surprises people |
| Maturity | Choice | High (1:1), Partial, None |

### `30-60-90 Tasks`
| Field | Type | Notes |
|-------|------|-------|
| Title | Single line of text | Task description |
| PC | Lookup → PCs | Owner |
| Phase | Choice | Days 1-30, Days 31-60, Days 61-90, Ongoing |
| Lane | Choice | Relationships, Knowledge, Deliverables, Quick Wins, Improvements |
| Due date | Date | |
| Status | Choice | Not Started, In Progress, Done, Blocked |
| Notes | Multiple lines of text | |
| Linked stakeholder | Lookup → Stakeholders | Optional |

### `Decisions Log`
| Field | Type | Notes |
|-------|------|-------|
| Title | Single line of text | Brief description of the decision |
| Program | Lookup → Programs | |
| Date decided | Date | |
| Decider | Person or Group | |
| Context | Multiple lines of text | Why this came up |
| Decision | Multiple lines of text | What was decided |
| Rationale | Multiple lines of text | Why this choice |
| Linked artifacts | Multiple lines of text | URLs to docs, meeting notes, emails |

### `PC↔Program History` (junction)
| Field | Type | Notes |
|-------|------|-------|
| Title | Single line of text | Auto-composed: "PC Name — Program Name" |
| PC | Lookup → PCs | |
| Program | Lookup → Programs | |
| Start date | Date | |
| End date | Date | Blank = active |
| Role notes | Multiple lines of text | Optional context (e.g., "Backup PC during Q3") |

### `Program↔Tool` (junction)
| Field | Type | Notes |
|-------|------|-------|
| Title | Single line of text | Auto-composed: "Program Name — Tool Name" |
| Program | Lookup → Programs | |
| Tool | Lookup → Tools | |
| Adopted date | Date | When the program started using it |
| Sunset date | Date | When the program stopped using it (blank = active) |
| Notes | Multiple lines of text | Implementation context |

---

## Recommended views (per List)

### `Stakeholders`
- All
- By Influence (grouped)
- Need to Meet (Last Contact = blank)
- Stale (Last Contact > 30 days ago, considering Cadence)
- Sensitive (Sensitive? = Yes)
- My Stakeholders (Owner = [Me])

### `Meetings`
- All
- Daily / Weekly / Monthly / Quarterly (filtered by cadence)
- By Role (grouped by PC role)
- My Meetings (PC = [Me] via Trainee Profile lookup)

### `Equivalency Map`
- All
- By Category (grouped)
- For Me (filtered: From-Tool ∈ current user's previous tools AND To-Tool ∈ current program's tools)
- Gaps (Maturity = None)

### `30-60-90 Tasks`
- All
- My Open Tasks (PC = [Me] AND Status ≠ Done)
- This Phase (filtered to current phase based on days since Trainee Profile.Start date)
- Blocked (Status = Blocked)

---

## Conditional formatting / JSON formatters

Apply column formatting JSON to make Lists feel like dashboards:

| Column | Behavior |
|--------|----------|
| `Stakeholders.Sensitive?` | Red row background when Yes |
| `Stakeholders.Last Contact` | Red text if > 30 days; orange if > 14 days |
| `30-60-90 Tasks.Status` | Colored pills: green (Done), yellow (In Progress), red (Blocked), gray (Not Started) |
| `Equivalency Map.Maturity` | Colored pills: green (High), yellow (Partial), red (None) |
| `Meetings.PC role` | Colored pills: blue (Lead), purple (Co-lead), gray (Participant/Observer/Optional) |

JSON snippets are not stored in this repo (they're applied directly to columns in SharePoint), but each one is straightforward to generate or paste from Microsoft's column formatter samples.
