# 00 — Onboarding Checklist

_What this covers: a hands-on Day-1 / Week-1 tick-box list to get from "never seen this repo" to "confidently made a safe change." Do these in order._

Every command below is copy-pasteable. Paths are relative to the framework repo root (`Gate/`) unless stated otherwise.

## Day 1 — Get oriented and green

- [ ] **Clone and look around.**
  ```bash
  git clone <repo-url> Gate && cd Gate
  git branch --show-current          # note the branch you're on
  git log --oneline -15              # skim recent history
  ls -la                             # note: NO .githooks/ here — that's created in TARGET repos
  ```
  Do not expect a `.githooks/` directory in this repo. This is the *framework* repo; `.githooks/` only exists in repos the framework has been *installed into*. See [`01-WHAT-IS-THIS.md`](01-WHAT-IS-THIS.md).

- [ ] **Confirm prerequisites are on your PATH** (`README.md:9-18`):
  ```bash
  git --version        # any recent git
  bash --version       # 3.2+ is fine (macOS default works — nothing needs bash 4)
  python3 --version    # 3.8+; stdlib only, no pip packages required by the framework
  bats --version       # for running the test suite (brew install bats-core)
  ```
  Optional: `pipx` (only for the MCP graph server), `claude` (Claude Code CLI, for the init step).

- [ ] **Read the two source-of-truth docs, in this order:** [`01-WHAT-IS-THIS.md`](01-WHAT-IS-THIS.md) then [`02-ARCHITECTURE.md`](02-ARCHITECTURE.md). Keep [`06-GLOSSARY.md`](06-GLOSSARY.md) open in a second tab.

- [ ] **Run the test suite** (the framework's own CI runs exactly this — `.github/workflows/framework-tests.yml:22-23`):
  ```bash
  ./tests/gate/run_tests.sh
  # or, per-file if the full run hangs on your machine:
  AI_DEV_WORKFLOW_SKIP_STALENESS_CHECK=1 bats tests/gate/<file>.bats
  ```
  Expect the large majority to pass. Two files can misbehave *locally* (not in Linux CI): `graph_watchdog.bats` leaves background processes that keep bats from exiting cleanly, and `uninstall_completeness.bats` needs a real pty (it drives interactive prompts). One test in `uninstall_bash_compat.bats` ("warns when the local clone is behind its upstream") is network/environment-sensitive. See [`05-DEV-SETUP.md`](05-DEV-SETUP.md) and [`08-KNOWN-ISSUES-AND-DEBT.md`](08-KNOWN-ISSUES-AND-DEBT.md). Treat Linux CI as the authoritative signal.

## Day 2–3 — Install into a scratch repo and watch the gate work

- [ ] **Create a throwaway target repo and install the framework into it** (never run `install.sh` from inside `Gate` itself — it refuses, `install.sh:780-784`):
  ```bash
  mkdir /tmp/scratch-gov && cd /tmp/scratch-gov
  git init && git commit --allow-empty -m "chore: repository birth"
  git checkout -b chore/claude-init
  AI_DEV_WORKFLOW_SKIP_STALENESS_CHECK=1 ~/…/Gate/install.sh   # choose [g] greenfield
  ```
  Inspect what landed: `.githooks/` (gate.sh, pre-commit, pre-push, verify_governance_integrity.sh), `.claude/` (gate_state.json, settings.json, hooks/, checkpoint_tool.py, gate_integrity.sha256), `.github/workflows/gate.yml`, `.github/CODEOWNERS`, `.mcp.json` (if the graph server installed), and `~/.claude/org_policy.json`.

- [ ] **Trigger the gate as a human.** Make a trivial change on a feature branch and commit:
  ```bash
  echo "x" > note.txt && git add note.txt
  git commit -m "test: watch the gate run"
  ```
  Read the `GATE: …` lines on stderr. Then try to commit directly on `main` and watch it get blocked (`templates/gate.sh:360-365`).

- [ ] **Trigger a real block.** Stage a fake secret and watch STEP 5 stop you:
  ```bash
  echo 'aws_access_key_id = AKIA1234567890ABCDEF' > leak.py && git add leak.py
  git commit -m "test: secrets scan"   # expect GATE BLOCK: Potential secret detected
  ```

- [ ] **Exercise the audited bypass** (from a real terminal, not an IDE panel):
  ```bash
  SKIP_GATE=1 git commit -m "test: emergency bypass"   # type a reason when prompted
  git log --show-notes=bypasses -1                       # see the audit note
  ```

## Week 1 — Make a safe change and cut a dummy release

- [ ] **Read the safe-change procedure** in [`05-DEV-SETUP.md`](05-DEV-SETUP.md) before touching `templates/gate.sh`.

- [ ] **Make a trivial, safe gate change** (e.g. reword one `echo` message in `templates/gate.sh`), then:
  ```bash
  bats tests/gate/            # the tests deploy the REAL templates, so they cover your edit
  ```
  Re-installing into the scratch repo will re-pin `.claude/gate_integrity.sha256` for that repo; the framework repo itself has no pin to update. Understand why the integrity manifest exists ([`02-ARCHITECTURE.md`](02-ARCHITECTURE.md), "Trust-root lockdown").

- [ ] **Practice the upgrade path** against your scratch repo:
  ```bash
  cd /tmp/scratch-gov
  ~/…/Gate/install.sh --upgrade
  ```
  Read `docs/UPGRADE.md` and confirm what it overwrites vs. preserves.

- [ ] **Cut a dummy release** — this framework has no build artifact; a "release" is a version bump + branch/tag flow. Bump `FRAMEWORK_SEMVER` in `install.sh:24` on a branch, run the suite, and open a PR into the integration branch. See [`04-RUNBOOK.md`](04-RUNBOOK.md) "Release process" and confirm the active branch first (`git branch --show-current`), because the repo has a documented branch-name inconsistency (see [`04-RUNBOOK.md`](04-RUNBOOK.md)).

- [ ] **Skim** [`08-KNOWN-ISSUES-AND-DEBT.md`](08-KNOWN-ISSUES-AND-DEBT.md) and [`13-OWNERSHIP-AND-CONTACTS.md`](13-OWNERSHIP-AND-CONTACTS.md) so you know the gaps and what external access you must get transferred.

---

next: [`01-WHAT-IS-THIS.md`](01-WHAT-IS-THIS.md)
