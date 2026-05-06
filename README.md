# KITCHEN

**K**nowledge - **I**nterviews - **T**ransitions - **C**ookbooks - **H**andoffs - **E**quivalencies - **N**etwork

*Let's get Cooking.*

A SharePoint-native knowledge platform for NASA Project Coordinators. Captures the working styles, stakeholders, meetings, contract context, and tool equivalencies that make a working team actually work — and produces a Word "cookbook" handoff document when a PC transitions out.

---

## What KITCHEN is

KITCHEN is a personal-scale platform that lives entirely inside Microsoft 365 (SharePoint Lists + native pages, with a PowerShell-driven build pipeline). It is the structured memory of a Project Coordinator role: who the stakeholders are, how each one prefers to be worked with, what meetings recur, which contract each artifact belongs to, and which tools the team uses (and what they map to in the tools the next PC came from). On request, it assembles that structured data into a Word document indistinguishable in style from the cookbooks NASA Barrios PCs write by hand.

## Why it exists

Institutional knowledge vanishes when Project Coordinators rotate off a contract. Six months of pattern-matching — *"the branch chief hates being CC'd but expects to be looped in"*, *"this PI answers email in ten minutes but goes silent on Teams"* — leaves with the person who learned it. The replacement starts cold and relearns the same lessons.

KITCHEN captures the relationships, decisions, and unwritten rules in structured form so they survive turnover. The platform is invisible to the replacement until the outgoing PC chooses to reveal it; what they hand over looks like a polished cookbook.

## Architecture (high level)

Nine active SharePoint Lists form the data layer:

| List | Purpose |
|------|---------|
| **PCs** | Project Coordinators (active and past) |
| **Stakeholders** | People the role touches, with full Working Styles Matrix per person |
| **Contracts** | Contract / customer scope each artifact attaches to |
| **Tools** | Catalog of tools used across the program |
| **Equivalency Map** | Cross-tool mappings (Slack to Teams, Asana to Planner, etc.) |
| **Acronyms** | Glossary, optionally scoped to a contract |
| **Meetings** | Recurring meeting catalog |
| **30-60-90 Tasks** | Personal onboarding/transition task plan |
| **Trainee Profile** | Per-PC personalization (start date, prior tools, current assignment) |

Plus an `[ARCHIVED]` set of legacy lists (`Equivalency Map`, `Program-Tool`) retained for history and hidden from navigation.

Three guided SharePoint pages sit on top of the data:

- **Home** — landing page, where-am-I orientation, quick actions
- **Onboarding** — incoming PC mode (welcome, day-1 essentials, knowledge wiki)
- **Update / Offboarding** — outgoing PC mode (living handover, quick capture, cookbook export)

A Word **Cookbook Export** assembles structured List data into a PC-style cookbook document at handoff. Today this is driven by a PowerShell generator (`scripts/generate-cookbook.ps1`); previous Power-Automate-based prototypes are documented in `design/pa-replacement-*.md`.

## Working Styles Matrix

A 21-question intake across four categories — **Communication**, **Working**, **Thinking**, **Interpersonal** — captured both per-PC (so the PC's own preferences are recorded) and per-Stakeholder (so the next PC inherits the relationship knowledge instead of re-learning it). Tier 1 questions are designed for the first 1:1 (~10 minutes); the remainder are captured opportunistically. Full methodology in `design/working-style-discovery.md`.

## Constraints and context

- Built on a **NASA GCC SharePoint tenant** with restricted permissions.
- **Legacy `SharePointPnPPowerShellOnline` module on Windows PowerShell 5.1** — the only PnP path that authenticates against this tenant. Modern `PnP.PowerShell` is unavailable.
- **No Power Automate, no SPFx, no tenant-admin theming.** Anything that would need those is implemented as scripts run by the PC, JSON column formatters, or a documented manual recipe.
- **No Copilot or AI as a runtime component.** AI is a build-time tool only (used to draft formatters, schema, and prose). The platform must give deterministic answers from its own data.
- Build path: PowerShell scripts bootstrap schema, lists, fields, formatters, and page scaffolding. Day-to-day maintenance is then done through the SharePoint GUI.
- ASCII-only `.ps1` files; runtime Unicode constructed via `[char]0xXXXX` (PowerShell 5.1 mangles UTF-8-without-BOM as Windows-1252). See `DECISIONS.md` D13.

## Status snapshot

- Schema refactored (Wave 1 complete) and stable; bad-schema fields renamed `[DELETE] ...` for owner-driven cleanup.
- CSV import scripts working for Stakeholders, Acronyms, Meetings, and the Working Styles Matrix.
- Guided pages being assembled in the SharePoint GUI from native components, following the recipes in `design/page-recipe-*.md` and visual references in `design/page-build-visuals.html` and `design/onboarding-offboarding-native-mockup.html`.
- Cookbook export functional end-to-end against current schema.
- Barrios brand theme defined and applied via `scripts/apply-barrios-theme.ps1`.

## Repo structure

```
KITCHEN/
├── README.md                     <- this file
├── ARCHITECTURE.md               <- three-tier model, entities, sitemap, capability map
├── DECISIONS.md                  <- design decisions and their rationale (D1-D13)
├── .gitignore
├── cookbooks/                    <- example/exported cookbook artifacts
├── data-model/
│   ├── schemas.md                <- list/column definitions, internal-name mapping
│   ├── build-checklist.md / .html
│   └── equivalency-map-seed.csv
├── naming/
│   └── backronym-history.md      <- KITCHEN etymology, alternatives considered
├── scripts/                      <- PowerShell build/maintenance pipeline
│   │   --- Provision pages ---
│   ├── provision-home-native.ps1
│   ├── provision-onboarding-native.ps1
│   ├── provision-update-offboarding-native.ps1
│   ├── provision-guided-experience-pages.ps1
│   ├── provision-mantle-actions-page.ps1     (filename preserved; provisions the "KITCHEN Actions" page)
│   ├── provision-mission-3-lists.ps1
│   ├── provision-mission-4-lists.ps1
│   ├── refresh-acronym-glossary-page.ps1
│   ├── refresh-meeting-catalog-page.ps1
│   ├── refresh-team-directory-page.ps1
│   ├── cleanup-obsolete-pages.ps1
│   │   --- Refactor schema ---
│   ├── overhaul-mantle-schema-wave1.ps1     (filename preserved; KITCHEN schema overhaul)
│   ├── add-working-styles-matrix-fields.ps1
│   ├── add-stakeholder-working-style-fields.ps1
│   ├── add-missing-admin-tools.ps1
│   ├── remove-duplicate-lookup-columns.ps1
│   ├── hide-backend-lists-from-nav.ps1
│   │   --- Import data ---
│   ├── import-acronyms-from-csv.ps1
│   ├── import-meetings-from-csv.ps1
│   ├── import-stakeholders-from-csv.ps1
│   ├── import-working-styles-matrix.ps1
│   ├── populate-equivalency-lookups.ps1
│   ├── populate-tool-training-resources.ps1
│   ├── backfill-admin-tools-metadata.ps1
│   │   --- Format / theme / layout ---
│   ├── apply-barrios-theme.ps1
│   ├── apply-list-formatters.ps1
│   ├── apply-working-style-form-layout.ps1
│   │   --- Operational ---
│   ├── check-stale-stakeholders.ps1
│   ├── process-welcome-responses.ps1
│   ├── generate-cookbook.ps1
│   └── rename-platform-mantle-to-kitchen.ps1 (one-shot SharePoint display-name rename)
└── design/                       <- mockups, recipes, JSON formatters, methodology
    ├── working-style-discovery.md             (the matrix and how to use it)
    ├── page-recipe-home.md
    ├── page-recipe-onboarding.md
    ├── page-recipe-update-offboarding.md
    ├── manual-paste-home.md
    ├── manual-paste-onboarding.md
    ├── manual-paste-update-offboarding.md
    ├── page-build-visuals.html               (visual reference for page assembly)
    ├── home-mockup.html
    ├── guided-experience-mockup.html
    ├── onboarding-offboarding-native-mockup.html
    ├── form-layout-pcs-header.json
    ├── form-layout-pcs-body.json
    ├── form-layout-stakeholders-header.json
    ├── form-layout-stakeholders-body.json
    ├── build-and-apply-theme.md
    ├── diagnostic-stakeholders-import.md
    ├── welcome-flow.md
    ├── welcome-form-build-guide.md
    ├── cookbook-export.md
    ├── cookbook-export-build-guide.md
    ├── pa-replacement-generate-cookbook.md
    ├── pa-replacement-process-responses.md
    └── pa-replacement-stale-check.md
```

## How to use this repo

This is a **design and provisioning artifact**, not a runnable application. The scripts target a specific SharePoint site URL hardcoded in each file (currently a NASA tenant site); they would need adaptation to run against any other tenant. The design documents, page recipes, JSON form layouts, and the Working Styles Matrix methodology are reusable independently of the provisioning pipeline.

If you are reading this to understand how KITCHEN works, start with `ARCHITECTURE.md`, then `DECISIONS.md`, then `design/working-style-discovery.md`.

If you are reading this to clone the build, expect to: replace site URLs in every script, re-run the provisioning scripts in order (Wave 1 schema -> field additions -> formatters -> page scaffolds), then assemble the guided pages by hand against the recipes in `design/page-recipe-*.md`.

## A note on URLs and filenames

The platform was previously named MANTLE. The rename to KITCHEN is a display-only change — the GitHub repo URL, local working directory, SharePoint site slug, SharePoint page URL slugs (`MANTLE-Home.aspx`, `MANTLE-Actions.aspx`), and several PowerShell filenames retain the old token to preserve bookmark stability and avoid breaking existing references. New documentation, page titles, and prose use KITCHEN.

## Privacy

Public repo, design only. No personally identifiable information, internal contact details, internal URLs, or customer-specific cookbook content is committed here. Real cookbook content lives only in the SharePoint tenant with appropriate access controls (see `DECISIONS.md` D9).
