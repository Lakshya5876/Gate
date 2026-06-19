# Upgrading the Governance Framework

## When to run

Run `./install.sh --upgrade` when:

- A new version of `ai-dev-workflow` is available and you want its gate.sh enforcement improvements.
- The team lead has announced a framework version bump (e.g. v1.0.0 → v1.1.0).
- `gate_state.json` shows a `framework_version` older than the installer's `FRAMEWORK_SEMVER`.

Do **not** run it for routine development — it only touches framework infrastructure files.

---

## How to run

From inside the governed repository (same directory you originally ran `install.sh` from):

```bash
/path/to/ai-dev-workflow/install.sh --upgrade
```

The script detects `--upgrade`, skips basket selection, and runs a targeted re-copy flow.

---

## What it overwrites

| File | Action |
|------|--------|
| `.githooks/gate.sh` | Replaced with the new template |
| `.githooks/pre-commit` | Regenerated from current heredoc |
| `.githooks/pre-push` | Regenerated from current heredoc |
| `.github/workflows/gate.yml` | Replaced (unlike fresh install, which skips if present) |
| `.claude/gate_state.json` — `framework_version` | Bumped to new semver |
| `.claude/gate_state.json` — `framework_last_upgrade` | Set to current UTC timestamp |

---

## What it never touches

| File / Field | Why preserved |
|---|---|
| `.claude/baseline.json` | Debt ratchet — encodes your team's accepted technical debt; overwriting it would grandfather nothing and block everything |
| `CLAUDE.md` | Repo constitution — team-authored, repo-specific; a framework upgrade has no business changing it |
| `.mcp.json` | Graph server config — tied to the specific binary path pipx installed; regenerating it would break graph mode |
| `gate_state.json — receipts` | Fingerprint cache — losing receipts forces every developer's next push to re-run the full test suite |
| `gate_state.json — token.*` | Budget accounting — clearing it would reset daily spend tracking mid-day |
| `gate_state.json — thresholds` | Human-tuned — your team may have raised coverage_pct or tightened complexity_max; upgrades don't reset those |
| `gate_state.json — core_files` | Architecture-critical file list — team-authored; a framework upgrade cannot know which files your team considers critical |

---

## After the upgrade

The upgrade script prints the exact commit command. Run it:

```bash
git add .githooks/ .github/workflows/gate.yml .claude/gate_state.json
git commit -m 'chore: upgrade governance framework to 1.0.0'
```

Push the commit through your normal PR flow. Every team member who pulls it gets the updated hooks automatically — no per-developer re-run of `install.sh` is needed.

---

## Verifying the upgrade

```bash
python3 -c "import json; d=json.load(open('.claude/gate_state.json')); print(d['framework_version'])"
```

Should print the new semver string.
