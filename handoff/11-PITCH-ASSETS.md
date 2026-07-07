# 11 — Pitch Assets

_What this covers: an inventory of the in-repo pitch/demo material — three standalone HTML decks at the repo root — what each is, who it's for, its status, and an important honesty caveat about the numbers in them._

There is **no video script** in the repo. A search for a script/storyboard file turned up only shell-script matches; the pitch material is entirely the three HTML files below. If someone refers to "the video," it does not exist in this repository (UNVERIFIED: confirm with the departing author whether a script lives outside the repo).

All three are **self-contained single-file HTML** (inline CSS/JS, no build step, no external assets) — open directly in a browser. They are marketing/demo artifacts, **not** part of the framework's runtime, and nothing in `install.sh`/`gate.sh`/`docs/` references them. They are safe to keep, edit, or delete without affecting the framework (though this handoff did **not** touch them — they're on the protect-list per the task).

## The assets

### `presentation.html` (52 KB — the main deck)
- **Title:** _"Gate — Structural AI Governance"_
- **Audience:** leadership / decision-makers. The section headings are pitch-shaped: _"The Prompt Compliance Paradox," "The Enforcement Engine," "Pre-emptive Leadership Q&A," "The Bottom Line: Scalable Isolation," "Get Started in Under Five Minutes."_
- **Purpose:** the flagship narrative deck — problem framing (why prompting fails), how the enforcement engine works, an objection-handling Q&A for leaders, and a call to action.
- **Status:** the largest and most recently edited (Jul 3, 2026), so treat it as the current/canonical deck.

### `presentation_2.html` (26 KB — the technical/demo deck)
- **Title:** _"Gate — a better way to ship with AI"_
- **Audience:** engineers / technical evaluators. It's structured as sequential `<section>` slides (`#s1`, `#s2`, …) and leans on concrete, code-true talking points: _"Why prompting fails," "Clean human commit / Agent mistakes blocked," "Status becomes a free-text string," "Payment SDK leaks into the view," "Checks only in CI → Deterministic checks at the \[gate]," "It knows the agent from you," "Big changes need a plan."_
- **Purpose:** a more mechanism-focused walkthrough that maps closely to what the gate actually does (agent-vs-human detection, layer-boundary leak example, TIER-3/plan gating) — most of these map to real behavior in `templates/gate.sh` (see [`02-ARCHITECTURE.md`](02-ARCHITECTURE.md)).
- **Status:** older (Jun 25, 2026); likely an earlier/alternate deck. Overlaps with `presentation.html`. Candidate for consolidation, but harmless.

### `impact_metrics.html` (6 KB — the metrics one-pager)
- **Title:** _"Gate — What Changes"_
- **Audience:** leadership / budget owners. A single-screen grid of "before vs. after" metric cards across Speed / Safety / Cost.
- **Purpose:** a quick, punchy value dashboard. Example cards (hard-coded in the inline `CARDS` array, `impact_metrics.html:88+`): "Time wasted picking up where you left off — 87% (22 min → 2–3 min)," "Security hole undetected — 100% (days/weeks → caught before saving)," "Monthly AI tool bill for a 10-person team — 47% (~$1,080 → ~$567)," "Review time per change — 50% (~60 min → ~30 min)."

## Honesty caveat (important — read before reusing these)

**The numbers in `impact_metrics.html` are illustrative marketing figures, not measured results.** They are hard-coded in the deck's JavaScript and are **not** derived from anything in the codebase — there is no telemetry, benchmark harness, or data pipeline in this repo that produces them (grep confirms nothing computes these values). Several map loosely to real mechanisms — e.g. "caught before saving" reflects the pre-commit gate, and the checkpoint system genuinely targets restart-time (see [`02-ARCHITECTURE.md`](02-ARCHITECTURE.md), checkpoint memory) — but the specific percentages and dollar amounts are **UNVERIFIED**. Do not present them as empirical without either (a) sourcing them from the author, or (b) running a real before/after study. The framework's honest, code-grounded claims live in [`01-WHAT-IS-THIS.md`](01-WHAT-IS-THIS.md) and [`02-ARCHITECTURE.md`](02-ARCHITECTURE.md); lead with those in any technical audience.

## Suggested handling for the new owner

- Keep `presentation.html` as the primary deck; fold anything unique from `presentation_2.html` into it and retire the duplicate to reduce drift.
- Before any external use of `impact_metrics.html`, either substitute real measurements or relabel the figures as illustrative.
- These are outside the trust root and outside the framework's runtime — edit freely; just keep them consistent with the code-true story in this handoff.

---

next: [`12-FAQ.md`](12-FAQ.md)
