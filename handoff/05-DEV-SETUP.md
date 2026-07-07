# 05 — Dev Setup

_What this covers: developing ON the framework itself — prerequisites, running the bats suite (and its local-run gotchas), the local dev loop, and the SAFE procedure for changing `gate.sh` without breaking CI or the trust root._

## Prerequisites

Same as running it, plus a test runner:
- `git`, `bash` 3.2+ (macOS default is fine — **never** use a bash-4-only construct like `${var,,}`; the codebase is deliberately 3.2-safe, see `install.sh:51-57`, `uninstall.sh:59-71`), `python3` (stdlib only).
- `bats-core` for tests: `brew install bats-core` (macOS) / `apt install bats` (Linux). Confirmed working with **Bats 1.13.0**.
- Optional: `pipx` + the `code-review-graph` package only if you're touching graph code; `shellcheck` if you want to lint bash (not wired into CI today).

## Running the test suite

The suite deploys the **real** `templates/` files into scratch git repos and exercises the actual logic — not mirrors (`tests/gate/uninstall_completeness.bats:3-8` explains this philosophy). Entry point:
```bash
./tests/gate/run_tests.sh          # what CI runs (.github/workflows/framework-tests.yml:22-23)
# equivalently:
bats tests/gate/*.bats
```
Always set `AI_DEV_WORKFLOW_SKIP_STALENESS_CHECK=1` for local runs to avoid the network staleness probe (`install.sh:495`):
```bash
AI_DEV_WORKFLOW_SKIP_STALENESS_CHECK=1 bats tests/gate/secrets_block.bats
```

### Current test status (verified during this handoff, macOS, Bats 1.13.0)
Running each file with a 40s-per-file cap, **all logic tests pass** except these environment/harness artifacts — Linux CI is the authoritative signal:

- **`graph_watchdog.bats`** — its 7 tests pass, but the file leaves background `code-review-graph`-style processes alive (the watchdog spawns them), so `bats` doesn't exit cleanly. This is what makes a naive `bats tests/gate/` run appear to *hang* at the end. Run it in isolation, or let CI (clean Linux runner) handle it.
- **`uninstall_completeness.bats`** — drives `uninstall.sh`'s interactive prompts through a real pty (`run_with_pty`); did not complete within the 40s cap in this local environment. Needs a proper TTY; CI handles it.
- **`uninstall_bash_compat.bats`** — 1 failing test locally: *"_check_framework_staleness warns when the local clone is behind its upstream."* It sets up real local+remote git repos and asserts on fetch/`rev-list` output; it is timing/environment-sensitive. `UNVERIFIED:` whether it fails on a clean Linux CI runner — check the latest `framework-tests` run before treating it as a real regression.

**Takeaway:** develop against per-file `bats` runs; trust the `framework-tests.yml` CI run for the green/red verdict. If you want a reliable local full-suite signal, run files individually and skip `graph_watchdog`/`uninstall_completeness` interactively.

## The local dev loop

1. Edit a `templates/` file (or `install.sh`/`uninstall.sh`).
2. Run the specific bats file that covers it (the file names map to subsystems — see [`03-REPO-MAP.md`](03-REPO-MAP.md)). Add a test *in that file* for new behavior; the suite's convention is to pin every fix to a named test (you'll see this referenced throughout `gate.sh`'s comments, e.g. `gate.sh:606`, `1108-1109`).
3. Optionally install into a scratch repo (`/tmp/...`) and drive a real commit/push to see it end to end (see [`00-ONBOARDING-CHECKLIST.md`](00-ONBOARDING-CHECKLIST.md)).
4. `ReadLints`/`shellcheck` if you have it; keep bash 3.2-safe.

## The SAFE procedure for changing `gate.sh`

`templates/gate.sh` is the single most sensitive file in the repo. In a **governed target repo** it is covered by three protections you must respect (see [`02-ARCHITECTURE.md`](02-ARCHITECTURE.md) → "Trust-root lockdown"):

1. **Content-hash integrity manifest** (`.claude/gate_integrity.sha256`) — CI's `verify_governance_integrity.sh` fails if the deployed `gate.sh` doesn't match its pinned hash.
2. **Claude Code deny-list + Bash guard** — an *agent* cannot Write/Edit it or reference it in Bash.
3. **CODEOWNERS + branch protection** — a human must approve the change.

### In the framework repo (where you develop)
There is no `gate_integrity.sha256` *here* (nothing is installed), so editing `templates/gate.sh` is a normal edit + PR. But because your edit will re-pin every downstream repo's manifest on their next `--upgrade`, follow this discipline:

1. **Branch** off the integration branch. Never edit `gate.sh` on `main`/`develop` directly.
2. **Make the change small and covered.** Add/extend the matching bats test. If you're closing a bug, pin it with a named test the way the existing comments do.
3. **Run the suite green** (`./tests/gate/run_tests.sh`), or the relevant files if you hit the local-hang caveats above.
4. **Preserve the crash-guard invariant:** any new failure path must `exit 1` with a clear message, never fall through to a silent pass (the `ERR` trap at `gate.sh:342-349` is your backstop, not a substitute).
5. **Preserve ledger discipline:** never write `last_pass_sha` or a receipt except at the very end, after all checks pass (`gate.sh:1293-1311`). Writing state early poisons the ledger on a mid-run block.
6. **Keep every GATE_STATE-touching helper guarded** with `[ -f "$GATE_STATE" ] || return 0` — this is why a missing ledger doesn't crash the success path (`gate.sh:82-94` documents a real bug this prevented).
7. **PR with Code Owner review.** Trust-root paths require it (`.github/CODEOWNERS`).

### Then, for downstream repos to get it
They run `install.sh --upgrade`, which re-pins `.claude/gate_integrity.sha256` and **requires the new manifest to be committed with the changed files** or CI fails (`install.sh:732-738`, `docs/UPGRADE.md:41`). This is by design: a human must review both the gate change and its pin in the same PR — you cannot silently move the pin.

### If you add a new governance script
Add it to the `sha256sum` list in **both** branches of `_write_integrity_manifest` (`install.sh:309-331`), deploy it in the right `_write_*` function, add it to the deny-list/Bash-guard `PROTECTED_SUBSTR` if agents must not touch it, and cover it with a bats test. Missing any one of these leaves a hole (the repo's history is largely a series of exactly these holes being found and closed — see the git log).

## Handy one-liners
```bash
# See every trust-root path the installer protects:
grep -n 'REQUIRED_DENY' -A40 install.sh
# See what the integrity manifest covers:
grep -n 'gate_integrity.sha256' -B2 -A12 install.sh
# Which bats file covers subsystem X:
ls tests/gate/ | grep -i <subsystem>
```

---

next: [`06-GLOSSARY.md`](06-GLOSSARY.md)
