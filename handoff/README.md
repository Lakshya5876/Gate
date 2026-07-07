# Engineer Handoff Package — `Gate`

_What this covers: your starting point for owning this repository end-to-end. Read this first, then follow the reading order below._

You are the new owner of `Gate`. The previous maintainer is leaving. Everything you need to run, extend, defend, and evolve this project is in this `handoff/` directory. Every factual claim here is grounded in the actual code; where a claim could not be verified it is marked `UNVERIFIED:`.

## The mental model in 5 lines

1. `Gate` is a **stack-agnostic governance framework** that forces engineering discipline onto AI coding agents (and humans) at the **git + CI layer**, not inside the agent's prompt.
2. The enforcement is a single deterministic bash script, `gate.sh`, run by **git hooks** (`pre-commit`, `pre-push`) locally and by a **CI workflow** (`gate.yml`) as the un-bypassable backstop.
3. It is **not** an app you run. It is an **installer** (`install.sh`) that copies governance files (from `templates/` and `v1_release/`) into *your target repo*, plus a one-time `/init-governance` Claude Code command that tailors them to your stack.
4. Because agents cannot be trusted to police themselves, the framework **locks down its own control files** (the "trust root") with a deny-list, a Bash-command guard hook, a content-hash integrity manifest, and CODEOWNERS + branch protection.
5. Enforcement is **mechanical and honest about its limits**: local hooks are bypassable (that's why CI exists), the secrets scan is keyword+format not entropy, and agent-vs-human detection is a client-side signal, not a cryptographic one. The docs never oversell this.

## If you only read one thing

Read [`02-ARCHITECTURE.md`](02-ARCHITECTURE.md). It walks a single commit through the entire gate end to end and cites the exact code for every step. If you understand that walk-through, you understand 80% of the system.

## Recommended reading order

| # | Doc | Why / when |
|---|-----|-----------|
| 0 | [`00-ONBOARDING-CHECKLIST.md`](00-ONBOARDING-CHECKLIST.md) | Day-1 / Week-1 tick-box list. Do this first, hands-on. |
| 1 | [`01-WHAT-IS-THIS.md`](01-WHAT-IS-THIS.md) | The problem, the thesis, and what it is NOT. |
| 2 | [`02-ARCHITECTURE.md`](02-ARCHITECTURE.md) | **The one to read.** One commit through the gate, end to end. |
| 3 | [`03-REPO-MAP.md`](03-REPO-MAP.md) | Annotated index of every important file: what/who-owns/safe-to-edit. |
| 4 | [`04-RUNBOOK.md`](04-RUNBOOK.md) | Install, init, upgrade, uninstall, release, branch strategy. |
| 5 | [`05-DEV-SETUP.md`](05-DEV-SETUP.md) | Developing ON the framework: bats suite, safe `gate.sh` changes. |
| 6 | [`06-GLOSSARY.md`](06-GLOSSARY.md) | Every term of art defined once. Keep it open while reading. |
| 7 | [`07-DESIGN-DECISIONS.md`](07-DESIGN-DECISIONS.md) | Why it's built this way (documented vs. inferred). |
| 8 | [`08-KNOWN-ISSUES-AND-DEBT.md`](08-KNOWN-ISSUES-AND-DEBT.md) | The honest list: fragile edges, gaps, thin tests. |
| 9 | [`09-FUTURE-ROADMAP.md`](09-FUTURE-ROADMAP.md) | Staff-level strategy memo: where to take this next. |
| 10 | [`10-COMPETITIVE-LANDSCAPE.md`](10-COMPETITIVE-LANDSCAPE.md) | Honest comparison vs. gstack, ECC, rea, Claude Code native. |
| 11 | [`11-PITCH-ASSETS.md`](11-PITCH-ASSETS.md) | Inventory of the in-repo demo/pitch HTML. |
| 12 | [`12-FAQ.md`](12-FAQ.md) | 15 real questions a new owner asks, answered from the code. |
| 13 | [`13-OWNERSHIP-AND-CONTACTS.md`](13-OWNERSHIP-AND-CONTACTS.md) | What/whom to transfer now the author is leaving. |

## A note on `ultimate_harness.md`

[`ultimate_harness.md`](ultimate_harness.md) (moved here from the repo root as part of this handoff) is a ~5,000-line **complete engineering curriculum** titled _"From Absolute Zero to the Level of the Engineer Who Built It."_ It teaches every mechanism in the framework from Unix first principles up through `gate.sh`, the receipt system, and the security posture. It is **legacy/reference material**: extremely valuable for deep learning, but it was written against an earlier commit (`a7d3c04` per its own header, `ultimate_harness.md:9`) and is not kept in lockstep with the code the way `docs/` is. Treat it as a textbook, not a spec. When it disagrees with the actual code, the code wins — verify against the files cited in this handoff.

There is also a `handoff_cursor.md` at the repo root — a **prior, Cursor-focused** handoff document from an earlier point in the project's life (it references branch `init_release` and framework "V1"). It overlaps heavily with this package and is a candidate for consolidation, but it is referenced by the protected `README.md` and was **not** modified or moved by this handoff. See [`03-REPO-MAP.md`](03-REPO-MAP.md) for details.

---

next: [`00-ONBOARDING-CHECKLIST.md`](00-ONBOARDING-CHECKLIST.md)
