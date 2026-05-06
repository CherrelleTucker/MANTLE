# Working Style Discovery

A methodology for new Project Coordinators landing on MANTLE: a 21-question Working Styles Matrix to learn how each stakeholder actually likes to be worked with, why each question matters, and how to capture the answers so the next PC doesn't have to start from zero.

---

## 1. Why this matters

Almost every friction point in a PC role traces back to an unstated working preference. The scientist who goes quiet on Teams but answers email within ten minutes. The branch chief who hates being CC'd but expects to be looped in. The PM who treats your tracked-changes as an insult because she wanted comments instead. None of this is in anyone's position description, and none of it shows up until you've already gotten it wrong two or three times.

The traditional fix is pattern-matching: spend six months absorbing tells, getting corrected, and slowly building an internal model of how each person likes to be worked with. That works, but it's slow, it's invisible, and it leaves with you the day you rotate off the contract.

Asking discovery questions in your first 1:1 collapses those six months into one conversation. Capturing the answers in the Stakeholders list makes the knowledge portable — your replacement inherits it, your platform aggregates it, and you stop relearning the same lessons across customers.

A note on length: this matrix is 21 questions across four categories. **Don't try to ask all 21 in the first 1:1.** A first sit-down should cover the Communication block and the working-hours pieces — maybe 8 questions, 10 minutes. The rest are captured opportunistically: a Thinking-Styles answer falls out of a brainstorming session; an Interpersonal answer surfaces the first time feedback gets exchanged. The matrix is the destination, not the first-meeting agenda.

## 2. When to ask

Your first 1:1 with a new stakeholder is the right moment for the core block. Both of you are in introduction mode, expectations aren't set yet, and asking is read as professionalism rather than presumption.

Frame it lightly. Something like:

> "I want to be useful to you faster than the usual ramp-up. Can I ask you a few questions about how you like to work? It'll save us both some friction."

Almost no one says no. Most people are flattered to be asked, and many will volunteer answers to questions you didn't think to ask.

**A tiered approach for which questions to ask first:**

- **Tier 1 — first 1:1 (must-ask, ~10 min):** Q1 Primary Channel, Q2 Secondary Channel, Q5 Decision Timing (self), Q6 Decision Timing (others), Q8 Working Hours Start, Q9 Working Hours End, Q11 Inclusion Preference, Q12 Status Update Cadence.
- **Tier 2 — first month (ask in context):** Q3 Edits-Leave, Q4 Edits-Receive, Q7 Decision Format, Q10 Deep Work, Q16 Receive Feedback, Q17 Give Feedback.
- **Tier 3 — opportunistic (capture as it surfaces):** Q13 Processing Style, Q14 Thinker Type, Q15 Rabbit Trails, Q18 Receive Recognition, Q19 Give Recognition, Q20 Conflict Default, Q21 Comments.

If a stakeholder is generous with time, keep going. If not, get Tier 1 captured and pick the rest up across the next few weeks.

## 3. The discovery questions

### Communication Styles (8 questions)

#### 1. Primary preferred channel

> *"When you have a thirty-second question for me, what's the best way to reach you? And the reverse — when I have one for you?"*

**Why it matters:** The single most common source of friction. Email-people experience Teams pings as interruptions; Teams-people experience email as a black hole. Get this wrong and every interaction has a small tax on it.

**Stakeholders field:** `PreferredChannel` — Choice. Options: Email · Teams chat · Slack · In person · Phone call · Text · Walk-over · Varies by topic.

**Listening for:** "Teams chat is fine for quick stuff" — capture Teams in the dropdown, any nuance in Quirks.

#### 2. Secondary preferred channel

> *"And if I can't reach you on Teams — what's your fallback?"*

**Why it matters:** People rarely live on one channel exclusively. The secondary tells you what to escalate to when the primary goes quiet, and it prevents the awkward "I sent you a Teams message three days ago" moment.

**Stakeholders field:** `SecondaryChannel` — Choice. Same options as Primary.

**Listening for:** "Email if it's not urgent, text if it is."

#### 3. How you prefer to leave YOUR edits in shared files

> *"When you're editing a draft I sent you, what's your default — direct edits, suggestions, or comments?"*

**Why it matters:** Tells you what to expect when a draft comes back from them. If they make direct edits and you're a tracked-changes person, you'll be reverse-engineering their thinking from a clean document forever.

**Stakeholders field:** `EditsLeaveStyle` — Choice. Options: Direct edits · Suggestions/track changes · Comments only · Mix depending on doc · Verbal feedback in meeting.

**Listening for:** "I just fix it. If I have a question I'll comment, but mostly I edit."

#### 4. How you prefer OTHERS to leave shared file edits

> *"And when I'm editing something of yours — same approach, or different?"*

**Why it matters:** This is the one that creates landmines. A scientist may consider direct edits to their writing a violation; a branch chief may consider comments on a one-pager an annoyance. Same action, opposite reactions. Asking explicitly removes the guesswork.

**Stakeholders field:** `EditsReceiveStyle` — Choice. Same options as EditsLeaveStyle.

**Listening for:** "Suggest mode in Google Docs, but for SharePoint just leave comments — I'll handle the changes."

#### 5. Decision timing (self)

> *"When something lands in your inbox that needs a decision, how long do you typically want before you respond?"*

**Why it matters:** Some people decide in the moment; others need overnight. Knowing this tells you whether to expect a same-day reply or whether to build in a 48-hour buffer when they're in your critical path.

**Stakeholders field:** `DecisionTimingSelf` — Choice. Options: Immediate · Same day · 24 hours · 2-3 days · Week+ · Depends on weight.

**Listening for:** "I sleep on anything bigger than a quick yes. So usually next morning."

#### 6. Decision timing (others)

> *"And the reverse — when you're waiting on someone else for a decision, how long before it starts to feel slow?"*

**Why it matters:** This sets the tempo you should run at for them. If they're a 24-hour person and you're routinely taking three days, you're losing trust without knowing it.

**Stakeholders field:** `DecisionTimingOthers` — Choice. Same options as DecisionTimingSelf.

**Listening for:** "If I haven't heard back in two business days I assume it's stuck and I start nudging."

#### 7. Decision format

> *"When someone brings you a decision to make, how do you prefer it framed — options laid out, a single recommendation with reasoning, or just a quick verbal walk-through?"*

**Why it matters:** Recommendation-people read a three-option memo as you dodging the work of forming an opinion. Options-people read a single recommendation as you boxing them in. This question saves you from rewriting the same memo twice.

**Stakeholders field:** `DecisionFormat` — Multi-line text. Capture in plain language: "Recommendation up top, alternatives below", "Three options, I'll pick", "Verbal first, document after", etc.

**Listening for:** "Give me your recommendation up top, then the alternatives so I can poke at it."

### Working Styles (5 questions)

#### 8. Working hours start

> *"What's your real working day start time — and I mean the time you're good to work collaboratively, not the time you log in. If you protect 7-9 for deep work, tell me 9."*

**Why it matters:** The honest answer protects their deep-work time and tells you when meeting invites and pings stop being intrusions. The literal-clock answer doesn't.

**Stakeholders field:** `WorkingHoursStart` — Single line text (time + timezone, e.g., "9:00 CT").

**Listening for:** "I'm online at 6:30 but don't book me before 9 — that's writing time."

#### 9. Working hours end

> *"And your end time in the same timezone?"*

**Why it matters:** Distinguishes the person who lives in their inbox at 9pm (and is fine with it) from the person who reads after-hours messages as a boundary violation.

**Stakeholders field:** `WorkingHoursEnd` — Single line text (time + timezone).

**Listening for:** "Hard stop at 4. After that I'm with my kids and I'm not answering."

#### 10. Deep work style

> *"How do you prefer to do deep work that needs both thinking and collaboration — solo first then sync, working session in real time, async over a doc?"*

**Why it matters:** Some people need to chew alone before they can talk; others can only think out loud with someone. Match their mode and you get their best work; mismatch it and you get watered-down versions of both.

**Stakeholders field:** `DeepWorkStyle` — Multi-line text. Capture mode and any rituals: "Solo draft, then 30-min sync to refine", "Whiteboard session, no docs until after", etc.

**Listening for:** "I write a bad first draft alone, then I want to sit with you for an hour and tear it apart."

#### 11. Inclusion preference

> *"When something I'm working on has a direct impact on you, when do you want to be looped in — at the idea stage, at the draft stage, or just at the decision point?"*

**Why it matters:** Early-inclusion people experience late inclusion as being managed; late-inclusion people experience early inclusion as having their time wasted. Both reactions are real and both are legitimate.

**Stakeholders field:** `InclusionPreference` — Choice. Options: Idea stage · Draft stage · Decision point · FYI when done · Depends on impact.

**Listening for:** "Don't loop me in until you have a draft. Half-formed ideas aren't useful to me yet."

#### 12. Status update cadence

> *"What's your preferred routine status update cadence — weekly, biweekly, monthly, or only when something changes?"*

**Why it matters:** No-news-is-good-news people resent the weekly check-in; weekly-rhythm people experience silence as the project drifting. Set the cadence once and stop guessing.

**Stakeholders field:** `StatusUpdateCadence` — Choice. Options: Daily · Weekly · Biweekly · Monthly · Exception-only · On-demand.

**Listening for:** "Weekly is too much. Monthly written summary, and ping me if anything actually moves."

### Thinking Styles (3 questions)

#### 13. Processing style

> *"How do you process new information best — talk it out, write it down, sit with it alone first, or some combination?"*

**Why it matters:** If you walk a talk-it-out person into a meeting cold with a 12-page memo, you'll get a stalled conversation. If you walk a sit-with-it person into the same meeting without sending the memo first, same result.

**Stakeholders field:** `ProcessingStyle` — Choice. Options: Talk it out · Write it down · Think alone first · Combination.

**Listening for:** "Send me the doc 24 hours ahead so I can mark it up. Then we can actually have a conversation."

#### 14. Thinker type

> *"What kind of thinker do you see yourself as — big picture, detail-oriented, creative, pragmatic, synthesizer, process-oriented, something else?"*

**Why it matters:** Tells you what register to brief them in. A big-picture thinker glazes over at row 47 of a spreadsheet; a detail thinker distrusts a one-pager that doesn't show its work.

**Stakeholders field:** `ThinkerType` — Choice. Options: Big picture · Detail-oriented · Creative · Pragmatic · Synthesizer · Process or sequential · Other.

**Listening for:** "Mostly synthesizer — I like seeing how the pieces connect. Spare me the pure-detail dumps."

#### 15. Rabbit trails

> *"Do you find yourself easy to distract with rabbit trails, or pretty good at staying on the main thread?"*

**Why it matters:** A self-aware rabbit-trailer wants you to gently steer back; a focused thinker wants you to follow the tangent because they only go off-topic when it matters. Same behavior from you, opposite reads.

**Stakeholders field:** `RabbitTrails` — Choice. Options: Yes, steer me back · Yes, but the tangents matter · No, I stay on thread · Depends on energy.

**Listening for:** "Oh god yes. If I'm 90 seconds into something unrelated, just say 'back to the agenda.'"

### Interpersonal Styles (5 questions)

#### 16. Receive corrective feedback

> *"How do you prefer to receive corrective feedback — direct in the moment, scheduled 1:1, in writing, with context first?"*

**Why it matters:** Mismatched feedback delivery is one of the fastest ways to break trust with someone otherwise willing to hear hard things. The content lands or doesn't depending almost entirely on the channel.

**Stakeholders field:** `ReceiveFeedback` — Multi-line text. Capture mode and any framing preferences: "Direct, in the moment, no preamble", "Schedule a 1:1, written summary after", etc.

**Listening for:** "Just tell me. Don't soften it, don't sandwich it. Direct is respect."

#### 17. Give corrective feedback

> *"And when you're giving someone else corrective feedback, what's your default style?"*

**Why it matters:** Tells you what to expect when feedback is coming at you, and helps you read it accurately. A blunt giver who is also a blunt receiver isn't being harsh — they're being consistent.

**Stakeholders field:** `GiveFeedback` — Multi-line text.

**Listening for:** "I'm direct. If I'm not saying anything, you're fine."

#### 18. Receive recognition

> *"How do you prefer to be recognized when something goes well — public callout, private note, in front of leadership, no fuss?"*

**Why it matters:** Public-recognition people feel invisible without it; private-recognition people feel exposed by it. Both responses are sincere.

**Stakeholders field:** `ReceiveRecognition` — Choice. Options: Public callout · Private note · Mention to leadership · No fuss · Depends on what.

**Listening for:** "A private 'thanks, that was good work' means more than a Teams shout-out. Please don't @ me in a channel."

#### 19. Give recognition

> *"And how do you tend to recognize others?"*

**Why it matters:** Calibrates how you read their recognition of you and your team. Someone who rarely gives public praise but sends thoughtful private notes isn't withholding — they're using their channel.

**Stakeholders field:** `GiveRecognition` — Multi-line text.

**Listening for:** "I send notes to people's supervisors when they do well. They don't always know I do it."

#### 20. Conflict default

> *"When something goes sideways between you and a colleague, what's your default first move — direct conversation, give it time, loop in a third party, write it out?"*

**Why it matters:** Tells you how to repair friction with them when (not if) it happens. Direct-conversation people read silence as avoidance; give-it-time people read immediate confrontation as escalation.

**Stakeholders field:** `ConflictDefault` — Multi-line text.

**Listening for:** "I sleep on it for a day. Then I want a real conversation, not email, not Teams."

### Free-form

#### 21. Additional comments

> *"Anything else I should know about how you like to work that I didn't ask?"*

**Why it matters:** This is the question that gets you the gold. People will tell you things here they wouldn't volunteer to any of the structured questions — the specific phrasing they hate, the cc behavior that annoys them, the meeting habit that wastes their time. Ask it last, after they're warmed up.

**Stakeholders field:** `WorkingStyleComments` — Multi-line text.

**Listening for:** "Don't put me on a recurring meeting without asking. Don't reply-all to confirm receipt. And please, please don't send me a 'just checking in' email."

## 4. After the conversation

Within a day of the meeting — while you can still hear the person's voice in your head — open the Stakeholders list, find their row, and fill in the working-style fields you covered. Use the dropdown values where they exist; use Comments for anything nuanced. If a stakeholder said "Teams for quick stuff but email for anything formal," capture both: the dropdown for the dominant channel, the nuance in WorkingStyleComments.

Update the `Last Contact` date while you're in the row. It's a small habit that compounds — a quick scan of the list a month later tells you who you've gone quiet on.

If you got partial answers — which you will, because nobody answers all 21 in one sitting — mark the unanswered fields as `(ask next 1:1)` rather than leaving them blank. Blank reads as "never asked." A note reads as "in progress."

Finally: if anything the stakeholder said contradicts what's already in the row from a previous PC, don't overwrite without thinking. Preferences shift, but they shift slowly. A contradiction is usually a signal worth a quick second check before you change the record.

## 5. The aggregate value

Each capture is, first and foremost, for you and your stakeholder — it makes your day-to-day work smoother. But because the Stakeholders list lives on the platform, every capture also feeds the bigger picture. Across PCs and customers, MANTLE starts to see real patterns: which orgs run on email vs Teams, which leaders want recommendations vs options, which thinker-types cluster in which branches, where escalation paths are fragile, where training would actually move the needle. Barrios gets staffing intelligence. Onboarding gets sharper. The next PC who lands on your customer inherits a working model instead of a blank slate. You're solving today's problem and building tomorrow's institutional knowledge in the same conversation.
