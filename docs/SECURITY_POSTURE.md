# Security Posture — Claude Code Governance Framework v1

This document describes what the framework touches, what it never reads, and how it satisfies the controls auditors ask about most. It is written for a security reviewer, not a developer.

---

## 1. Data flows

### What the framework reads

| Source | Read by | Purpose |
|--------|---------|---------|
| Staged file contents | `gate.sh` (via `git diff --cached`) | Lint, type-check, complexity, layer-boundary scan |
| `.claude/gate_state.json` | `gate.sh`, `install.sh` | Token budget, coverage thresholds, receipts, core_files |
| `.claude/baseline.json` | `gate.sh` | Identity-based lint debt ratchet |
| `refs/notes/bypasses` | `pre-push` hook | Bypass clock enforcement |
| `~/.claude/org_policy.json` | `gate.sh` | Per-developer token budget ceiling (local file, not centrally enforced — see §6, CC6.6) |

### What the framework writes

| Destination | Written by | Content |
|-------------|-----------|---------|
| `.claude/gate_state.json` | `gate.sh` | Receipt fingerprints, token spend, pass/fail ledger |
| `.claude/session_spend.tmp` | `gate.sh` | Per-session token accumulator (deleted after each run) |
| `refs/notes/bypasses` | `pre-commit` hook (bypass path only) | Audit record: timestamp + human-typed reason |
| `.claude/git_cache.json` | `gate.sh` | Short-lived git metadata cache (TTL: 60 s, gitignored) |

### What the framework never reads

- Source code outside the current git working tree.
- Credentials, `.env` files, shell history, or SSH keys. The `.gitignore` additions written by `install.sh` explicitly exclude `.env` and `.env.*`.
- Browser data, clipboard contents, or network requests from developer machines.
- Claude Code's own `settings.json` — the framework writes `.mcp.json` (project-scoped MCP config) but never reads `~/.claude/settings.json`.

---

## 2. External network calls

**The framework makes zero external network calls at gate time.**

- `gate.sh` is a pure local bash script. It calls only: `git`, `python3`, and the configured lint/type/test commands (all local binaries).
- The MCP graph server (`code-review-graph`) runs locally via `pipx`. It reads the local repository graph; it does not phone home.
- `install.sh` calls `pipx install code-review-graph==2.3.6` once at install time to fetch the pinned package. This is the only outbound call, and it is install-only, not gate-time.

---

## 3. Claude Code `denyRead` scope

Claude Code's file-access controls are configured in `.claude/settings.json` (per-repo) or `~/.claude/settings.json` (global). The framework does not write these files; they remain under human control.

**Recommended `denyRead` entries for governed repos** (add to `.claude/settings.json`):

```json
{
  "denyRead": [
    ".env",
    ".env.*",
    "**/*.pem",
    "**/*.key",
    "**/*.p12",
    "~/.ssh/**",
    "~/.aws/credentials"
  ]
}
```

These ensure Claude Code cannot read secrets even if instructed to by a malicious prompt.

---

## 4. Bypass audit trail

Every gate bypass is cryptographically linked to the git history.

**How it works:**

1. Developer runs `SKIP_GATE=1 git commit -m "..."` in an interactive terminal.
2. `pre-commit` hook prompts for a typed reason (required; empty string is rejected).
3. Hook writes a git note to `refs/notes/bypasses` on the current HEAD:
   ```
   BYPASS | date=<unix-epoch> | reason=<human-typed text>
   ```
4. `pre-push` hook reads the note and enforces the 24-hour resolution window:
   - Active bypass (< 24 h): warns, allows push, audit trail intact.
   - Expired bypass (≥ 24 h): **blocks push** until the underlying issue is fixed or a new bypass window is opened.
5. Bypass notes travel to the remote via:
   ```
   remote.origin.push  refs/notes/bypasses:refs/notes/bypasses
   remote.origin.fetch +refs/notes/bypasses:refs/notes/bypasses
   ```
   Both refspecs are written by `install.sh`. They cannot be stripped by a force-push (tampering with the bypass refspec is itself a block condition in `pre-push`).

**Non-repudiation:** the note is attached to the git object that was committed, not to a mutable file. `git log --show-notes=bypasses` shows the full trail for any reviewer.

---

## 5. Data retention

| Data | Location | Retention |
|------|----------|-----------|
| Token audit log | `gate_state.json — token.token_audit_log[]` | Rolling 90-day window; gate.sh prunes entries older than 90 days on each write |
| Per-session spend | `.claude/session_spend.tmp` | Deleted by gate.sh at the end of every gate run (gitignored) |
| Fingerprint receipts | `gate_state.json — receipts{}` | Retained indefinitely (small, ~100 bytes/receipt); no PII |
| Bypass notes | `refs/notes/bypasses` | Permanent git history; never auto-purged (audit requirement) |
| Git metadata cache | `.claude/git_cache.json` | TTL 60 s; gate.sh invalidates stale entries on every run (gitignored) |

---

## 6. SOC 2 control mapping

| SOC 2 Control | Framework mechanism |
|---------------|---------------------|
| CC6.1 — Logical access controls | Every Claude Code action gated by `pre-commit`/`pre-push`; no route around gate without audited bypass |
| CC6.6 — Restrict logical access to system boundaries | **Partial control — see caveat below.** Token budget ceiling read from `~/.claude/org_policy.json`, which is a local, per-developer-machine file, not a centrally distributed or tamper-evident policy. `gate.sh` enforces whatever value is present on that machine at gate time; it does not verify the value against an org-issued source of truth, and a developer with shell access can edit their own copy to raise or remove their ceiling. This mechanism deters accidental/unbounded spend (e.g. a runaway agent loop) on a cooperating machine; it is not a control that prevents a developer from unilaterally raising their own limit, and should not be represented to an auditor as centrally enforced without a companion mechanism (e.g. a signed policy file, or a CI/telemetry check that flags local overrides). |
| CC6.8 — Prevent unauthorized changes | Protected branch guard in `pre-push` blocks direct pushes to main/master/develop/production/release/* |
| CC7.2 — Monitor system components | `gate_state.json` token audit log + bypass notes provide a time-stamped record of every gate interaction |
| CC8.1 — Change management | Layer boundary scanner (STEP 6.5) blocks architecture violations at commit time, not code review time |
| A1.1 — Availability commitments | Gate enforces coverage threshold and complexity ceiling to prevent quality regressions that degrade availability |

---

## 7. Threat model — what the framework does not protect against

- **Compromised developer machine:** if an attacker controls the developer's shell, they can modify gate.sh directly or set `SKIP_GATE=1` without the interactive prompt. The CI backstop (`.github/workflows/gate.yml`) is the authoritative enforcement layer — it runs in a clean, audited environment the developer cannot modify.
- **Malicious CI runner:** if the CI runner itself is compromised, all bets are off. Use GitHub's hardened runner images and pin action versions (`actions/checkout@v4` SHA-pinning recommended).
- **Social engineering to extend bypass:** the 24-hour window is a policy control, not a technical one. A developer with shell access can always open a new bypass window. The audit trail makes this visible to reviewers; it does not prevent it.
- **The CI integrity manifest has no external trust anchor.** `.claude/gate_integrity.sha256` is a repo-tracked file — it proves internal self-consistency (the checked-out `gate.sh` matches the checked-out pin), not consistency against an externally-trusted reference. A single PR that edits `.githooks/gate.sh` *and* regenerates the pin to match, via normal git/filesystem access outside Claude Code's tool-mediated hooks, passes CI. This is **not** closable by anything `install.sh` can configure — it requires a human-controlled GitHub setting: a `CODEOWNERS` entry for `.githooks/`, `.claude/gate_integrity.sha256`, `.claude/hooks/`, `.claude/settings.json`, and `.github/workflows/gate.yml`, plus a branch protection rule requiring Code Owner review. The exact `CODEOWNERS` content and branch-protection steps are in each basket's `v1_implementation_package_*.md`, STEP 3/4 — ACTIVATION. Skipping that step leaves this specific gap open regardless of how hardened the rest of the chain is.
