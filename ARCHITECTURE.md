# Architecture

MANTLE is organized as a three-tier knowledge model implemented across a small set of related SharePoint Lists. The model is multi-tenant from day one (one row in the PCs catalog today, room for thousands tomorrow) but the deployment is single-user.

---

## Three tiers of content

| Tier | Scope | Examples | Who fills it |
|------|-------|----------|--------------|
| **Tier 1 — Universal PC knowledge** | Applies to every Project Coordinator regardless of program | Job duty baseline, travel process, monthly reporting templates, agency-wide acronyms, tool equivalencies, meeting-scheduling best practices, badging procedures | Anyone, accumulates over time |
| **Tier 2 — Program/customer-specific** | Applies to everyone supporting one program/customer | Project portfolio, meeting catalog, Slack/Teams channels, PI planning cadence, program stakeholders | Whoever currently coordinates that program; inherited at handoff |
| **Tier 3 — Personal** | Applies only to one PC | Personal task rhythms, in-flight commitments, candid annotations on official material, personal stakeholder relationships | The individual; leaves with them when they depart |

The cookbook artifact each PC eventually produces is roughly the *union* of their Tier 3 + their assigned Tier 2 + selected Tier 1 content.

---

## Sitemap

```
🏠 HOME
   ├─ Where I am (visual journey progress)
   ├─ Quick actions
   ├─ This week
   └─ Recently changed

📋 LEARN (incoming PC mode)
   ├─ Welcome / setup form
   ├─ Day-1 essentials checklist
   └─ Knowledge wiki

📊 OPERATE (daily work surface)
   ├─ Stakeholder map
   ├─ Meetings inventory
   ├─ Tools & access tracker
   ├─ Acronyms glossary
   ├─ Equivalency map
   └─ Decisions log

🎯 ALIGN (leadership-facing)
   ├─ 30-60-90 plan
   ├─ Supervisor 1:1 notes
   └─ Weekly pulse form

📈 GROW (skills + development)
   ├─ Skills matrix
   └─ Training tracker

🔁 HANDOVER (continuous + outgoing PC mode)
   ├─ Living handover
   ├─ Quick capture prompts (small daily chunks)
   └─ Cookbook export (the centerpiece feature)
```

---

## Data entities

| Entity | Purpose | Key relationships |
|--------|---------|-------------------|
| **PCs** | Every Project Coordinator (active or past) | many-to-many → Programs (via PC↔Program History) |
| **Programs** | NASA programs/customers being supported | many-to-many → PCs; many-to-many → Tools |
| **Meetings** | Recurring meeting catalog | many-to-one → Programs |
| **Stakeholders** | People the role touches | many-to-many → Programs (people often span multiple) |
| **Acronyms** | Glossary | optional categorization → Program / NASA-wide |
| **Tools** | Catalog of tools used across NASA | many-to-many → Programs |
| **Equivalency Map** | Cross-tool mappings (e.g., Slack ↔ Teams) | references Tools |
| **30-60-90 Tasks** | Personal onboarding/transition tasks | many-to-one → PCs; optional lookup → Stakeholders |
| **Decisions Log** | What was decided, by whom, when, why | many-to-one → Programs |
| **Trainee Profile** | Per-PC personalization (start date, tools they came from, current program assignment) | one-to-one → PCs |

### Junction tables (for many-to-many relationships)

- **PC ↔ Program History**: PC, Program, start date, end date, role
- **Program ↔ Tool**: Program, Tool, last verified date

---

## Capability map (Microsoft 365 native components)

| Need | Component |
|------|-----------|
| Portal home | SharePoint Communication Site (provisioned via Team creation) |
| Channel hub | Microsoft Teams private channel |
| Structured data | Microsoft Lists (with multiple views, JSON column formatters) |
| Task board | Planner |
| Forms | Microsoft Forms |
| Notebook | OneNote |
| Calendar | Outlook recurring events |
| Automation | Power Automate flows |
| Dashboards | Power BI (Pro license required for embed) |
| Document export | Power Automate flow that generates a Word document from List data (the Cookbook Export) |

---

## Cookbook export (the centerpiece feature)

The platform's defining output is a Word document that resembles a traditional NASA Project Coordinator cookbook in style and structure — but is assembled from structured List data rather than typed by hand.

The export flow:
1. PC opens MANTLE and clicks "Export my cookbook"
2. Power Automate flow queries: their Trainee Profile + assigned Program(s) + Meetings + Stakeholders + Decisions + their personal annotations + relevant Tier 1 content
3. Word document is composed from a template, with sections matching the conventions seen in existing cookbook examples (role description, recurring tasks, meeting catalog, project portfolio, resources, acronyms, personal annotations)
4. Document is delivered to the PC's OneDrive

The replacement reads what they think is a polished cookbook. The platform's existence is invisible until the outgoing PC chooses to reveal it.

---

## What's deliberately not in the architecture

These are scope decisions, not omissions:

- **No multi-user permission complexity** — the schema supports it; the deployment doesn't configure it. Future scale problem.
- **No approval flows on shared catalogs** — same reason.
- **No aggregate analytics dashboards** ("X% of programs use Slack") — meaningful only at scale; future problem.
- **No GitHub/AppSource distribution** — platform lives entirely in NASA's M365 tenant.
- **No Copilot/AI as runtime component** — AI is a build-time tool only.
- **No custom code beyond what Lists/Power Automate/JSON formatters provide** — keeps the platform within the no-code/low-code envelope a future maintainer can support.
