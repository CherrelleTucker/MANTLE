# Design Decisions Log

Captures the *why* behind MANTLE's choices, so future maintainers (including future-self) don't relitigate settled questions.

---

## D1 — Platform lives entirely inside SharePoint / M365

**Decision:** No GitHub distribution, no AppSource, no external hosting. The runtime is SharePoint Lists, Teams channels, Power Automate flows, Power BI dashboards — all inside the NASA tenant.

**Why:** Stays inside NASA's authorized M365 boundary (no ATO/FISMA conversation). Discoverable across NASA via SharePoint search. No friction for any NASA employee or contractor to use — they're already authenticated.

**Trade-off accepted:** No portability outside NASA tenant. If the contract relationship ends, the platform doesn't follow.

---

## D2 — Build the schema for scale, populate for one

**Decision:** Multi-tenant data model from day one (Programs catalog, PCs catalog, junction tables for many-to-many relationships). Today only one PC's data populates it.

**Why:** Expectation is single-user. Hope is the platform proves itself at handoff and a sponsor (likely Daris or higher) decides to scale. If that happens, the schema doesn't need redesign — just more rows. Design lift now is small; redesign lift later would be massive.

**Trade-off accepted:** Slightly more schema complexity than a strict single-user tool would need. Worth it for the optionality.

---

## D3 — AI is a build-time tool, never a runtime component

**Decision:** Copilot, Claude, and any other LLM are used to accelerate building MANTLE (generate JSON formatters, draft Power Automate flow steps, summarize source documents). They are never embedded as a feature users have to trust.

**Why:** AI output is non-deterministic. Making a platform's functionality depend on an LLM means the platform breaks when the LLM hallucinates, the license is revoked, or the model changes behavior. Users of MANTLE need deterministic answers from their own data.

**Trade-off accepted:** Platform feels less "magic." Replaced by good IA, native filtering, and dashboards.

---

## D4 — Cookbook Export is the centerpiece feature

**Decision:** The platform's defining output is a Word document indistinguishable in style from the cookbooks Project Coordinators already write by hand.

**Why:** Validation comes at handoff. The replacement needs an artifact that looks familiar, not a tool they have to log into and learn. If they later ask *"how did you produce something this thorough?"*, that's the moment the platform reveals itself. The artifact sells the platform; the platform doesn't have to sell itself.

**Trade-off accepted:** Significant engineering investment in document generation. Worth it because nothing else delivers the same handoff experience.

---

## D5 — Never frame MANTLE as a replacement for cookbooks

**Decision:** External communication, both written and verbal, never positions MANTLE as replacing cookbooks. It produces them.

**Why:** Many PCs have invested significant work in their cookbooks and feel ownership over them. Suggesting replacement creates resistance. Framing as production keeps the cookbook artifact sacred and lets each PC retain authorial pride. If Barrios eventually decides to standardize and replace, that is their decision to make and announce.

**Trade-off accepted:** Slightly muddier value prop ("but isn't it just a fancier cookbook generator?"). Acceptable.

---

## D6 — Equivalency Map is a 3-axis catalog, not a 2-column table

**Decision:** Each row maps Category × From-Tool × To-Tool, with notes on what's the same and what differs. This generalizes beyond a single ecosystem migration (Google → Microsoft) to any tool transition (Slack → Teams, Asana → Planner, etc.).

**Why:** Different PCs come from different prior stacks. The map needs to scale across all of them, not just one pair.

---

## D7 — Asynchronous design, not synchronous handoff

**Decision:** MANTLE supports two independent user modes (incoming, outgoing) that do not require coordination between the two parties. An outgoing PC can populate the platform with no successor identified; an incoming PC can use the platform with no predecessor available.

**Why:** Real-world transitions rarely have clean overlap. The platform's value is *persistent role knowledge that survives turnover*, not *a tool for outgoing-meets-incoming dialogue*.

---

## D8 — Welcome flow uses soft choice, not hard gate

**Decision:** Landing page presents two large primary cards (incoming / outgoing). It is not a modal that blocks access until a selection is made.

**Why:** Edge cases exist (consultants, returning users, exploratory visitors). Hard gates feel like walls; soft choice feels like an invitation.

---

## D9 — Cookbook content NEVER lives in the public GitHub repo

**Decision:** This repository contains design only. Real cookbook content (with NASA people's names, contact info, internal URLs, customer-specific details) lives only in SharePoint with appropriate access controls.

**Why:** Public repo + government context + identifiable individuals = a phishing dataset waiting to happen.

---

## D11 — Lookup → Tools, not Choice, for any column referencing tools

**Decision:** `From-Tool` and `To-Tool` columns in Equivalency Map (and any future "which tool" column anywhere) are Lookup → Tools, not Choice columns. The Tools list is the canonical tool catalog.

**Why:** Choice columns that duplicate values from a catalog list create two sources of truth that drift. A new tool added to the Tools list should automatically appear everywhere it might be referenced. Manually maintaining parallel choice options is anti-pattern, doesn't scale, and is the kind of overhead that makes maintenance miserable.

**General principle:** If the values are themselves *richer entities* (have their own attributes — Category, Vendor, Description, etc.) → use Lookup. If they're just labels (Status, Maturity, Center) → Choice is fine.

**Trade-off accepted:** Two-step workflow when adding a tool that doesn't exist (must add to Tools list first, then reference in Equivalency Map). Worth it for data integrity. Prevents typos and "Microsoft Teams" vs "MS Teams" vs "Teams" fragmentation.

**Caught when:** First user populating Equivalency Map columns by hand realized the Choice options didn't auto-populate from the Tools list and that maintaining them in parallel would be unsustainable. Schema corrected before scale.

---

## D12 — Provision Lists via PnP scripts, not Excel import, to control column internal names

**Decision:** New SharePoint Lists are provisioned via PnP PowerShell (`Add-PnPField`), not via the SharePoint "From Excel" import path.

**Why:** When a List is created via "From Excel", custom column internal names are auto-generated as `field_1`, `field_2`, `field_3`, etc., regardless of the display name. This forces every script that touches those columns to reference generic internal names and breaks readability for anyone reading the schema later.

**Trade-off accepted:** Existing Lists provisioned via Excel import (`Equivalency Map Real`, `Tools`, etc.) keep their generic `field_N` internal names — re-provisioning would lose data. The mapping from internal name to intended display name is documented in `data-model/schemas.md`. New Lists going forward use PnP-provisioned, human-readable internal names.

---

## D13 — ASCII-only PowerShell scripts; Unicode constructed at runtime

**Decision:** All `.ps1` files in `scripts/` are kept ASCII-only. Any Unicode characters needed at runtime (e.g., `→` arrow, middle dots, em-dashes) are constructed via `[char]0xXXXX` rather than embedded in source.

**Why:** PowerShell 5.1 reads UTF-8-without-BOM files as Windows-1252, which mangles Unicode chars on load (the `→` arrow becomes `â†'`, etc.). Saving with a BOM works on 5.1 but is brittle across editors and git checkouts. Building Unicode at runtime (`[char]0x2192` for `→`) sidesteps the encoding question entirely.

**Trade-off accepted:** Slightly less readable string literals in scripts. Worth it for portability across PowerShell 5.1 / 7+, Notepad / VS Code, and any future contributor's editor settings.

---

## D10 — Naming: MANTLE

**Decision:** The platform is named MANTLE — a backronym for **M**anual, **A**cronyms, **N**otes, **T**ransition, **L**ogistics, **E**ngagement.

**Why:** "Passing the mantle" is the cultural phrase for handoff. The name does communication work the moment someone hears it. Avoids collision with NASA mission names. See `naming/backronym-history.md` for alternatives considered.
