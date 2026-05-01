# MANTLE

**M**anual · **A**cronyms · **N**otes · **T**ransition · **L**ogistics · **E**ngagement

A SharePoint-native knowledge platform for Project Coordinators. Built so the next coordinator never starts cold.

---

## What this is

A personal Project Coordinator platform that lives entirely inside Microsoft 365 (SharePoint Lists, Teams, Power Automate, Power BI). It captures the role's institutional knowledge — meetings, stakeholders, acronyms, recurring tasks, tool tips, decisions — in a structured, searchable, dashboardable form. When the coordinator transitions out, MANTLE produces a complete cookbook document for their replacement.

The name comes from the phrase *"passing the mantle"* — what happens at every PC handoff.

## What this is *not*

- **Not a replacement for cookbooks.** It produces them. The cookbook artifact survives; MANTLE is the engine.
- **Not a Barrios-sanctioned product.** Personal project. May be sponsored later if it proves valuable.
- **Not AI-dependent.** Copilot and other LLMs are tools used to *build* MANTLE; they are never runtime components users have to trust.
- **Not multi-tenant in deployment** (one user today). But the data schema is built for scale, so adding more PCs requires no redesign.

## What lives where

| Where | What |
|-------|------|
| **Microsoft 365 / SharePoint (NASA tenant)** | The actual platform — Lists, Teams, Power Automate flows, Power BI dashboard. The runtime. |
| **This GitHub repo** | Design documentation, schemas, mockups, naming history, decision log. The blueprint. |
| **Local working folder (private)** | Personal cookbook content with NASA-specific names, links, and details. Never committed here. |

## Repository contents

```
MANTLE/
├── README.md                          ← you are here
├── ARCHITECTURE.md                    ← three-tier model, data entities, IA
├── DECISIONS.md                       ← key design decisions and their rationale
├── design/
│   ├── welcome-flow.md                ← incoming/outgoing PC entry-point flows
│   └── home-mockup.html               ← visual mockup of the SharePoint home page
├── data-model/
│   ├── schemas.md                     ← Lists, columns, types, relationships
│   └── equivalency-map-seed.csv       ← starter data for the Equivalency Map List
└── naming/
    └── backronym-history.md           ← MANTLE etymology, alternatives considered
```

## Status

Early. Foundation Team + first Lists in active build.

## Privacy note

This is a public repo containing **design only**. It does not contain personally identifiable information, internal contact details, internal URLs, customer-specific cookbook content, or any other material that should remain inside the NASA tenant. The actual populated platform lives in SharePoint with the appropriate access controls.
