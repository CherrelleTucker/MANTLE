# Working Style Discovery

A short methodology for new Project Coordinators landing on MANTLE: eight questions to ask your stakeholders in the first 30 days, why each one matters, and how to capture the answers so the next PC doesn't have to start from zero.

---

## 1. Why this matters

Almost every friction point in a PC role traces back to an unstated working preference. The scientist who goes quiet on Teams but answers email within ten minutes. The branch chief who hates being CC'd but expects to be looped in. The PM who treats your tracked-changes as an insult because she wanted comments instead. None of this is in anyone's position description, and none of it shows up until you've already gotten it wrong two or three times.

The traditional fix is pattern-matching: spend six months absorbing tells, getting corrected, and slowly building an internal model of how each person likes to be worked with. That works, but it's slow, it's invisible, and it leaves with you the day you rotate off the contract.

Asking five to ten minutes of discovery questions in your first 1:1 collapses those six months into one conversation. Capturing the answers in the Stakeholders list makes the knowledge portable — your replacement inherits it, your platform aggregates it, and you stop relearning the same lessons across customers.

## 2. When to ask

Your first 1:1 with a new stakeholder is the right moment. Both of you are in introduction mode, expectations aren't set yet, and asking is read as professionalism rather than presumption.

Frame it lightly. Something like:

> "I want to be useful to you faster than the usual ramp-up. Can I ask you a few questions about how you like to work? It'll save us both some friction."

Almost no one says no. Most people are flattered to be asked, and many will volunteer answers to questions you didn't think to ask. If a stakeholder seems too busy for the full set, prioritize questions 1, 3, and 7 — channel, meeting notice, and escalation — and pick up the rest as opportunities arise.

## 3. The discovery questions

### 1. Communication channel for quick questions

> *"When you have a thirty-second question for me, what's the best way to reach you? And the reverse — when I have one for you?"*

**Why it matters:** The single most common source of friction. Email-people experience Teams pings as interruptions; Teams-people experience email as a black hole. Get this wrong and every interaction has a small tax on it.

**Stakeholders field:** `Preferred channel` — Choice with fill-in. Options: Email · Teams chat · In person · Phone call · Slack · Walk-over · Whatever's easiest · Varies by topic.

**Listening for:** "Teams chat is fine for quick stuff, email if it needs a paper trail" — capture the dominant channel in the dropdown, the nuance in Quirks.

### 2. Document review preference

> *"When I send you a draft, do you want me to suggest edits, make direct edits, or leave comments?"*

**Why it matters:** Some people want a clean document with a comment thread to negotiate. Others want you to just fix it and move on. A scientist may consider direct edits to their writing a violation; a branch chief may consider comments on a one-pager an annoyance. Same action, opposite reactions.

**Stakeholders field:** `Editing preference` — Choice. Options: Suggestions only · Direct edits welcome · Comments only · Either fine · Track changes · Unknown.

**Listening for:** "Suggest mode in Google Docs, but for SharePoint just leave comments — I'll handle the changes."

### 3. Meeting notice preference

> *"How much lead time do you want on meeting requests, and is there a time of day you protect?"*

**Why it matters:** Some leads will accept a same-day invite without complaint; others view anything under 48 hours as a fire drill. Knowing the threshold prevents a lot of polite-but-cold "Decline" responses.

**Stakeholders field:** `Notice preference` — Choice. Options: Same day OK · 1-2 days · 3-5 days · Week+ · Unknown. Capture protected-hours info in `Working hours / time zone`.

**Listening for:** "I block mornings for writing — afternoons are fine. Give me 48 hours unless it's actually urgent."

### 4. Working hours and time zone

> *"What are your real working hours, and is it ever okay to reach out outside of them?"*

**Why it matters:** Distinguishes the person who lives in their inbox at 9pm (and is fine with it) from the person who reads after-hours messages as a boundary violation. Also flags time-zone realities for the JSC / Greenbelt / contractor mix.

**Stakeholders field:** `Working hours / time zone` — Single line text. Capture both the typical hours and the after-hours rule together (e.g., "Central, 7-4. After hours only if on fire — text, don't email."). Schema doesn't break this into separate fields; the combined free-form is more flexible.

**Listening for:** "I'm Central, generally 7 to 4. After hours only if something's actually on fire — and even then, text me, don't email."

### 5. Decision-making style

> *"When you need to make a decision, do you prefer to see options laid out, or a single recommendation with the reasoning?"*

**Why it matters:** Recommendation-people read a three-option memo as you dodging the work of forming an opinion. Options-people read a single recommendation as you boxing them in. This question saves you from rewriting the same memo twice.

**Stakeholders field:** `Decision style` — Multi-line text (free-form, not a fixed dropdown). Capture the mode in plain language: "Options first, recommendation last", "Wants my recommendation up top", "Decides in real time", etc.

**Listening for:** "Give me your recommendation up top, then the alternatives so I can poke at it."

### 6. Document and format standards

> *"Are there formatting standards or templates you want me to default to? Anything I should never do?"*

**Why it matters:** Surfaces the unwritten rules — the org chart that has to use a specific color palette, the status report that has to be a one-pager, the deck template the front office expects. Catches preferences that look like nitpicks but signal sloppiness if you miss them.

**Stakeholders field:** `Document style` — Multi-line text. Capture template links, font/color rules, layout expectations, and "never do this" items together.

**Listening for:** "Always use the official Branch template for status. Never send a deck without slide numbers. And no Comic Sans, ever."

### 7. Escalation path

> *"When something's actually urgent, how do you want me to escalate? And who's your backup if you're unreachable?"*

**Why it matters:** The question that pays for itself the first time you need it. Most stakeholders have a different protocol for "urgent" than for normal traffic, and most have a deputy or peer they trust to cover. Knowing both before you need them is the difference between a clean handoff and a scramble.

**Stakeholders field:** `Quirks / things to know` — Multi-line text. Schema doesn't have dedicated fields for escalation path or backup contact (yet); fold them into Quirks with clear labels: "Escalation: text first, then call. Backup: [Name], deputy, full authority."

**Listening for:** "Text me. If you can't reach me in 30 minutes, go to my deputy [Name] — she has authority to act on my behalf."

### 8. Pet peeves

> *"What drives you nuts? What do PCs or coordinators do that makes your life harder?"*

**Why it matters:** This is the question that gets you the gold. People will tell you things here they wouldn't volunteer to any of the other questions — the specific phrasing they hate, the cc behavior that annoys them, the meeting habit that wastes their time. Ask it last, after they're warmed up.

**Stakeholders field:** `Quirks / things to know` — Multi-line text.

**Listening for:** "Don't put me on a recurring meeting without asking. Don't reply-all to confirm receipt. And please, please don't send me a 'just checking in' email."

## 4. After the conversation

Within a day of the meeting — while you can still hear the person's voice in your head — open the Stakeholders list, find their row, and fill in the new working-style fields. Use the dropdown values where they exist; use Quirks for anything nuanced. If a stakeholder said "Teams for quick stuff but email for anything formal," capture both: the dropdown for the dominant channel, the nuance in Quirks.

Update the `Last Contact` date while you're in the row. It's a small habit that compounds — a quick scan of the list a month later tells you who you've gone quiet on.

If you got partial answers, mark the unanswered fields as `(ask next 1:1)` rather than leaving them blank. Blank reads as "never asked." A note reads as "in progress."

Finally: if anything the stakeholder said contradicts what's already in the row from a previous PC, don't overwrite without thinking. Preferences shift, but they shift slowly. A contradiction is usually a signal worth a quick second check before you change the record.

## 5. The aggregate value

Each capture is, first and foremost, for you and your stakeholder — it makes your day-to-day work smoother. But because the Stakeholders list lives on the platform, every capture also feeds the bigger picture. Across PCs and customers, MANTLE starts to see real patterns: which orgs run on email vs Teams, which PMs want recommendations vs options, where escalation paths are fragile, where training would actually move the needle. Barrios gets staffing intelligence. Onboarding gets sharper. The next PC who lands on your customer inherits a working model instead of a blank slate. You're solving today's problem and building tomorrow's institutional knowledge in the same five minutes.
