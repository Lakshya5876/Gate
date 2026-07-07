# 13 — Ownership and Contacts

_What this covers: who/what owns the trust root today, the external dependencies and services that must be transferred now that the author is leaving, and the concrete "assign a human before day 30" list. No secrets appear here — everything is referenced by name and by where it's managed._

This is the doc that keeps the framework alive after the handoff. Everything below is grounded in the repo; where an owner is a **person** rather than a file, it's marked **UNVERIFIED: assign a human** because the repo can't tell you who.

## 1. Trust-root ownership (per CODEOWNERS)

The framework's protected files are meant to require human review on change. `.github/CODEOWNERS` assigns them all to a single GitHub team: **`@platform-security-leads`** (`.github/CODEOWNERS:6-30`).

- **UNVERIFIED: does `@platform-security-leads` resolve to a real, staffed GitHub team in the `BankofLoyal` org?** Confirm at `github.com/orgs/BankofLoyal/teams`. If the departing author was its only member, **this is the single most urgent transfer** — an empty/last-member Code Owner team means trust-root PRs effectively have no required reviewer.
- **Known CODEOWNERS gap (fix during transfer):** in *this* framework repo, the CODEOWNERS entries point at *installed-target* paths (`.githooks/`, `.claude/gate_integrity.sha256`, `.github/workflows/gate.yml`, `.claude/baseline.json`, `.mcp.json`) that **don't exist here** — so they're inert. The framework's *actual* sensitive files (`templates/`, `install.sh`, `uninstall.sh`, `v1_release/**`) are **not** covered. Add entries for those (see [`08-KNOWN-ISSUES-AND-DEBT.md`](08-KNOWN-ISSUES-AND-DEBT.md) #16). This is safe to do — CODEOWNERS is not on the protected list for the framework repo… but note this handoff did **not** modify it; it's a recommendation for the new owner.

## 2. GitHub org / remote

- **Remote:** `https://github.com/BankofLoyal/Gate` (origin, fetch + push).
- **Org:** `BankofLoyal`.
- **What must transfer:**
  - Repo **admin** rights (to manage branch protection, which is load-bearing for the whole trust model — [`12-FAQ.md`](12-FAQ.md) #3).
  - **Branch protection settings** on the integration/release branch(es). **UNVERIFIED: confirm branch protection + "Require review from Code Owners" is actually enabled** — the installer can't set it and nothing verifies it (roadmap P0.1). Check at repo → Settings → Branches.
  - Ownership/membership of the `@platform-security-leads` team (see §1).
  - The **git notes refspecs** for the bypass audit trail: `refs/notes/bypasses` is configured for push+fetch on `origin` (`install.sh:953-954`). If a new remote or fork is used, re-run those `git config --add remote.origin.{push,fetch}` lines or the bypass trail won't replicate.

## 3. Pinned external package (supply-chain dependency)

- **`code-review-graph==2.3.6`** — the MCP code-index server, installed via **`pipx`** (`install.sh:34`, `981-1015`).
- **What to transfer / verify:**
  - Where does this package come from (PyPI? a private index?) and **who publishes it?** **UNVERIFIED: confirm the publisher and that the pin `2.3.6` is still installable.** If the departing author maintains it, publishing rights are a critical transfer.
  - Its CLI flags have drifted before and the installer degrades silently on mismatch (`install.sh:1046-1078`) — treat future version bumps as a reviewed change, and consider hash-pinning (roadmap P1.5).
  - `pipx` itself is a host dependency the installer will auto-install if missing (`install.sh:984-988`).

## 4. Org-level token policy

- **File:** `~/.claude/org_policy.json` (`install.sh:35`, created at `957-976`).
- **Contents (no secrets):** `WEEKLY_LIMIT` (default `1,250,000`) and `DAILY_BUDGET_PCT` (default `20`) → daily cap `250,000` tokens (`install.sh:36-38`, `966-973`).
- **What to transfer / decide:** this is a **per-machine, per-user** file, not a centrally managed policy (`docs/SECURITY_POSTURE.md:118`). There is no shared source of truth today. The new owner must decide whether to (a) formalize a real central policy channel (roadmap P1.3) or (b) document that the budget is a local deterrent. Note the fallback mismatch: `gate.sh` falls back to 200,000/day when no policy is present (`gate.sh:470-472`), so "the default" differs depending on whether `org_policy.json` exists.

## 5. CI / platform dependencies

- **This repo's CI:** `.github/workflows/framework-tests.yml` runs the bats suite (triggers on `init_release`/`develop`/`main`). Requires GitHub Actions to be enabled on the repo.
- **The CI gate installed into target repos:** `templates/ci-gate.yml` → deployed as `.github/workflows/gate.yml`. This is the un-bypassable backstop; its correct functioning depends on the target repo having Actions enabled and (for provenance/signing improvements) any org keys.
- **Claude Code platform:** the `.claude/` hooks, `settings.json`, and `.mcp.json` templates assume a Claude Code install on developer machines. Enterprise controls (server-managed settings, sandboxing) are org-console features — see [`09-FUTURE-ROADMAP.md`](09-FUTURE-ROADMAP.md).

## 6. Escalation path

**UNVERIFIED: the repo does not encode a human escalation path.** Establish and document, during the transfer:

- **Trust-root incident** (someone weakened/bypassed the gate, tampered with the audit trail, or the integrity manifest failed in CI): who is paged? Today the only "owner" is `@platform-security-leads`.
- **Framework bug** (gate false-positive blocking legitimate work, install/upgrade failure): who triages? Where do users file issues (GitHub Issues on `BankofLoyal/Gate`?).
- **Dependency incident** (a `code-review-graph` CVE or a bad publish): who owns the pin bump and re-verification?

## 7. Transfer checklist — assign a NEW human owner before day 30

Ordered by urgency. Each is **UNVERIFIED: assign a human** unless it's a pure config action.

1. **Owner of `@platform-security-leads`** — staff the Code Owner team; without it the trust root is unguarded. (§1)
2. **Repo admin** on `BankofLoyal/Gate` and confirmation that **branch protection + Code Owner review** are enabled. (§2)
3. **Publisher/maintainer of `code-review-graph`** and confirmation the `2.3.6` pin is installable. (§3)
4. **Decision owner for the token-policy story** (central vs. local, and the S3 half-feature's fate — [`08-KNOWN-ISSUES-AND-DEBT.md`](08-KNOWN-ISSUES-AND-DEBT.md) #9). (§4)
5. **CI / GitHub Actions owner** (secrets, any signing keys for roadmap P1.1). (§5)
6. **Incident escalation owner(s)** documented and reachable. (§6)
7. **Resolve the canonical branch** and fix the cross-repo inconsistency so releases have a home ([`04-RUNBOOK.md`](04-RUNBOOK.md), [`08-KNOWN-ISSUES-AND-DEBT.md`](08-KNOWN-ISSUES-AND-DEBT.md) #15).

## 8. Deletion candidate to adjudicate (ownership decision)

- **`handoff_cursor.md`** (repo root) — a prior, Cursor-focused handoff document referenced by the protected `README.md:60`. It overlaps heavily with this package and is likely superseded, but it was **not** deleted or modified (it's linked by a protected file). The new owner should decide: retire it and update `README.md`, or keep it. See the closing chat summary and [`03-REPO-MAP.md`](03-REPO-MAP.md).

---

You've reached the end of the handoff package. Start back at the [`README.md`](README.md) if you need the map, or jump to [`00-ONBOARDING-CHECKLIST.md`](00-ONBOARDING-CHECKLIST.md) to begin hands-on.

next: [`README.md`](README.md)
