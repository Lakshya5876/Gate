# 08 — Known Issues and Debt

_What this covers: the honest list of fragile edges, gaps, and thin spots. Each entry: **impact · location · suggested fix.** A blank version of this section would be a lie — this is a real system with real limits, several of which the repo itself discloses._

Entries are grouped by severity of surprise to a new owner, not by likelihood.

## Maintainer's parting notes — knowingly-open gaps (by design or by nature)

_These are the departing maintainer's own words on what is **deliberately not closed**. Read them first: they're the "I know, and here's why" list, and each is grounded in the code. Where they overlap the numbered entries below, the cross-reference is noted._

- **Org policies stored in S3 is not a finished feature.** The gate has a latent path to fetch `org_policy.json` from S3 at gate time (`gate.sh:393-441`), but nothing installs or wires it end-to-end. It's a half-built idea, not a shipped one. → see #9, #10, and roadmap P1.3.
- **Branch-guard on protected branches is a client-side-hooks limitation by nature — not fixable from the machine.** It was made *much harder to miss* (CODEOWNERS + a loud install-time reminder at `install.sh:1201-1213` + the existing CI backstop), but it still depends on a human actually flipping the GitHub branch-protection setting. Nothing running on your machine can force that. → see #4; roadmap P0.1 (`verify-governed`) detects it but still can't set it.
- **The layer scanner is still grep-based.** An HTTP/ORM import re-exported through an intermediate module still evades it. This is documented as a known limitation, **not fixed** — closing it would need real AST / import-graph analysis (the `code-review-graph` server is the natural vehicle). Location: `gate.sh:1096-1183`, `.pylintrc.layer-boundary`, disclosed `docs/SECURITY_POSTURE.md:134`. → see #6; roadmap P2.2.
- **The `cd`-guard fix has its own documented limit.** The trust-root Bash guard added a `cd`-tracking pass to close the `cd .githooks && sed -i … gate.sh` bypass, but it is a **lexical scanner, not a real shell interpreter**: variable expansion such as `D=.githooks; cd "$D"` still evades it (as does `~`/command substitution in a `cd` target). This is stated up front in the guard itself (`templates/pre_bash_trust_root_guard.sh:118-125`) — the same fundamental class of non-closable gap as client-side agent detection (`gate.sh` `_is_claude_agent_process`). It closes the realistic, demonstrated bypass, not every conceivable one. → related to #5.

## Security-model limits (disclosed by the repo — internalize these)

These are in `docs/SECURITY_POSTURE.md:126-137`. They are *by design*, but you own explaining them.

1. **Local hooks are bypassable; CI is the real gate.**
   - *Impact:* a compromised/uncooperative shell can edit `.githooks/gate.sh` or `git commit --no-verify`. Local enforcement is advisory-strength against a determined actor.
   - *Location:* `docs/SECURITY_POSTURE.md:128`; mitigated by `templates/ci-gate.yml`.
   - *Fix:* ensure CI + branch protection are on (see #4). There is no local-only fix — this is the threat model.

2. **The integrity manifest has no external trust anchor.**
   - *Impact:* one PR can edit `gate.sh` **and** regenerate `.claude/gate_integrity.sha256` to match; CI passes. Self-consistency ≠ trust.
   - *Location:* `docs/SECURITY_POSTURE.md:131`; manifest logic `install.sh:296-332`.
   - *Fix:* CODEOWNERS + branch protection requiring Code Owner review (see #4). Longer-term: sign the manifest against an org-held key or attest it in CI (roadmap P1, [`09-FUTURE-ROADMAP.md`](09-FUTURE-ROADMAP.md)).

3. **Secrets scan is keyword+format, not entropy.**
   - *Impact:* a bare opaque token from an unlisted vendor, or a value split across string concatenation, is not caught.
   - *Location:* `gate.sh:736-763`, disclosed `docs/SECURITY_POSTURE.md:132`.
   - *Fix:* run gitleaks/trufflehog in CI *in addition*; consider adding one to `ci-gate.yml` as a standard step.

4. **The strongest guarantee depends on a manual GitHub step.**
   - *Impact:* if a team never replaces `@your-org/platform-team` in CODEOWNERS and never enables "Require review from Code Owners," the entire trust root is unprotected against PR-level tampering, and a hookless branch (fresh clone before the governance commit) is completely ungoverned.
   - *Location:* `install.sh:920-950`, `1201-1213`.
   - *Fix:* the installer cannot do this (no repo-admin creds). Add a `verify-governed` script/CI check that fails if branch protection isn't detected (needs the GitHub API + a token) — roadmap item.

5. **Agent detection is a client-side signal.** `env -i`/`env -u CLAUDECODE` defeats it. *Location:* `gate.sh:280-319`, `docs/SECURITY_POSTURE.md:133`. *Fix:* none client-side; lean on managed Claude Code settings / sandboxing (roadmap).

6. **Layer-boundary and lint supplements can't see through cross-file indirection.** A re-export shim (`from myapp.http_shim import …` where `http_shim` imports fastapi) passes. *Location:* `gate.sh:1096-1183`, `.pylintrc.layer-boundary`, disclosed `docs/SECURITY_POSTURE.md:134`. *Fix:* use the graph server's resolve tooling; the ESLint rule also misses CommonJS `require()`.

## Platform / portability gaps

7. **No Windows-native path.** *Impact:* Windows users must use WSL2; `install.sh`/`uninstall.sh` "fail or behave unpredictably" in cmd/PowerShell. *Location:* `README.md:11-13`. *Fix:* none planned for V1; a PowerShell port is a large effort (roadmap "explicitly not worth doing" candidate — see [`09-FUTURE-ROADMAP.md`](09-FUTURE-ROADMAP.md)).

8. **bash 3.2 / BSD-userland assumptions are a recurring bug source.** *Impact:* every GNU-ism (`${var,,}`, `sort -V`, `timeout`, GNU `date`) is a latent macOS crash; the codebase hand-rolls around each. *Location:* `install.sh:75-92`, `452-476`; `uninstall.sh:59-71`; `gate.sh:257`, `546-547` (GNU-vs-BSD `date` fallbacks). *Fix:* keep the discipline; a shellcheck + a macOS CI matrix leg would catch regressions earlier (see #16).

## Correctness / robustness edges

9. **The S3 org-policy fetch path is latent and under-integrated.** *Impact:* `gate.sh:393-441` will try `aws s3 cp s3://company-config/org_policy.json` at gate time (skipped in CI), defaulting to `TOKEN_BUDGET=0` (fail-safe = blocks agents) if unreachable and uncached. Nothing in `install.sh` sets `S3_ORG_POLICY_URI` or documents this, so it's easy to be surprised by. *Location:* `gate.sh:393-441`. *Fix:* either document/wire it as a real feature (with the bucket configurable at init) or remove it; today it straddles "half-built." This also contradicts the "zero network at gate time" claim in the narrow case where `aws` is present and the file is stale (see #10).

10. **"Zero network calls at gate time" has one asterisk.** *Impact:* the doc claim (`docs/SECURITY_POSTURE.md:43`) is true for the normal path but the S3 fetch above *can* make a network call locally. *Fix:* reconcile the doc and the code — either gate the S3 path behind an explicit opt-in env var, or soften the doc claim.

11. **Graph build depends on an exact pinned CLI whose flags have drifted before.** *Impact:* a `code-review-graph` release renaming `--include`/`--exclude` already crashed the build once; the retry-with-default-scope fallback (`install.sh:1046-1078`) degrades to reduced domain coverage rather than failing loudly. Graph mode can silently be "installed but not built." *Location:* `install.sh:34`, `1032-1099`. *Fix:* add a post-install assertion that the graph actually has nodes; consider vendoring or a compatibility shim for the include flags.

12. **Budget-vs-org-default mismatch.** *Impact:* installer default daily budget is 250,000 (`WEEKLY_LIMIT=1,250,000 × 20%`, `install.sh:37-38`), but `gate.sh`'s fallback when no org policy is present is 200,000/day (`gate.sh:470-472`). Not a bug, but two different "defaults" that can confuse. *Fix:* document the precedence (org policy wins) prominently, or unify the numbers.

13. **`checkpoint_tool.py` Stop-hook contract is unverified against a live session.** *Impact:* the block/continue behavior is only tested standalone; a Claude Code version that changes the Stop-hook JSON contract would silently stop enforcing checkpoint pressure. *Location:* `checkpoint_tool.py:23-31`, disclosed `docs/SECURITY_POSTURE.md:137`. *Fix:* add an integration check against current Claude Code hook docs on each Claude Code bump; treat it as a "confirm before depending on it" item.

14. **Checkpoints have no automatic rotation.** *Impact:* `index.jsonl` grows unbounded (dated `.md` files are pruned to 10, but the index is not). *Location:* `checkpoint_tool.py` (prune only covers dated md, `_prune_dated_checkpoints`), `docs/SECURITY_POSTURE.md:28` ("size-bounded only by manual pruning"). *Fix:* add index rotation/compaction.

## Documentation / consistency debt

15. **Branch-name inconsistency across the repo.** *Impact:* `README.md:22` says `develop`; `framework-tests.yml` watches `init_release`/`develop`/`main`; `handoff_cursor.md` says `init_release`; the working tree is on `feat/token-budget-limits`. A new owner can't tell which branch is canonical. *Location:* `README.md:20-23`, `.github/workflows/framework-tests.yml:4-7`, `handoff_cursor.md:4`. *Fix:* pick one integration branch, make `framework-tests.yml` and both `README`s agree, and delete/redirect the stale references.

16. **CODEOWNERS in *this* repo lists paths that only exist in installed repos.** *Impact:* `.github/CODEOWNERS` assigns `.githooks/`, `.claude/gate_integrity.sha256`, `.github/workflows/gate.yml`, etc. to `@platform-security-leads`, but those paths don't exist in the framework repo — so those entries are inert here, and the *framework's own* `templates/` (the real sensitive files) are **not** listed. *Location:* `.github/CODEOWNERS`. *Fix:* add a CODEOWNERS entry covering `templates/`, `install.sh`, `uninstall.sh`, `v1_release/**` (the actual trust root *of the framework repo*), and confirm `@platform-security-leads` resolves to a real team (see [`13-OWNERSHIP-AND-CONTACTS.md`](13-OWNERSHIP-AND-CONTACTS.md)).

17. **The framework's own CI runs the test suite but not the gate on itself.** *Impact:* `framework-tests.yml` runs bats; there's no dogfooding of `gate.sh`/CODEOWNERS on the framework repo's own PRs, so the framework isn't governed by its own rules. *Location:* `.github/workflows/framework-tests.yml`. *Fix:* consider installing a lightweight self-gate, or at least CODEOWNERS+branch-protection on `templates/`.

18. **`refs/notes/bypasses` vs `refs/notes/gate-bypasses` naming drift.** *Impact:* code uses `refs/notes/bypasses` everywhere (`pre-commit`, `pre-push`, `install.sh:952-955`), but `v1_release/README.md:48-51` describes the refspec as `refs/notes/gate-bypasses`. A reader following the marketing README would configure the wrong ref. *Location:* `v1_release/README.md:48-51` vs. the code. *Fix:* correct the README to `refs/notes/bypasses`.

## Thin test areas

19. **Interactive/pty and network paths are hard to test and flaky locally.** `uninstall_completeness.bats` and the staleness test in `uninstall_bash_compat.bats` are pty/network-dependent and don't run cleanly on a dev macOS box (see [`05-DEV-SETUP.md`](05-DEV-SETUP.md)). *Fix:* isolate network-touching tests behind a marker; ensure CI has a real TTY (bats + `script`/`unbuffer`); add a fast, hermetic subset target for local dev.

20. **`graph_watchdog.bats` leaves live background processes.** *Impact:* makes a full-suite `bats tests/gate/` appear to hang at the end; can leak processes on a dev machine. *Location:* the watchdog spawns `code-review-graph`-style children (`gate.sh:171-177`). *Fix:* ensure the test stubs fully reap their children in teardown.

21. **Multi-language maturity is uneven.** *Impact:* Python is first-class (lint/type/complexity defaults are ruff/mypy/radon, `gate.sh:995-1017`); JS/TS, Go, Rust, Java/Kotlin are inferred for *tests* (`gate.sh:845-923`) but the auto lint/type/complexity fallbacks are Python-only — other stacks must set `LINT_CMD`/`TYPE_CMD` at init or those checks silently no-op (they're guarded by `HAS_BACKEND` + non-empty cmd). *Fix:* add inferred lint/type defaults for at least Node/Go, or make "no lint configured for a changed-source language" a visible warning.

## Setup friction

22. **Notes refspecs, `org_policy.json`, and `pipx` are quiet dependencies.** *Impact:* bypass audit only replicates if the refspecs stuck (`install.sh:952-955` uses `|| true`); the token ceiling silently depends on a global `~/.claude/org_policy.json`; graph mode silently depends on `pipx` + network at install. Any of these failing degrades a feature without a loud error. *Fix:* a `doctor`/`verify-governed` command that checks all of these and reports pass/fail (roadmap P0-ish; complements the runbook checklist in [`04-RUNBOOK.md`](04-RUNBOOK.md)).

---

next: [`09-FUTURE-ROADMAP.md`](09-FUTURE-ROADMAP.md)
