# CLAUDE CODE — WORKSPACE INITIALIZATION PACKAGE
## Edition: NEW PROJECTS (Greenfield)

**Companion document:** `claude_code_development_guide_new.md` (the Guide)
**Time required:** ~12 minutes, once at project birth
**Outcome:** A repository born governed — prescriptive architecture, hook-enforced
gates from commit #1, zero debt ever.

> **Status: specification verified through 3 audit rounds. Pending first live
> init validation.** If you are the first team to run this package, expect to
> confirm two things on the verification commit (Phase C) and report back:
> (1) `gate.sh` does NOT crash on the `last_pass_sha: null` cold start — it
> takes the all-files branch, never `git diff null..HEAD`; (2) the pre-push
> hook refuses a dry-run push to a protected branch. If both fire cleanly,
> the hook wiring is sound end-to-end and this banner can be removed.

---

## STEP 1 — PRE-FLIGHT (human developer action)

1. Create the repository and make an initial commit (even an empty README is
   fine): `git init && git commit --allow-empty -m "chore: repository birth"`
2. Create a setup branch: `git checkout -b chore/claude-init`
3. Decide three things BEFORE running the init (the prompt will ask):
   - **Stack:** language + framework (e.g. Python/FastAPI, TS/Node/Express,
     Go/chi)
   - **Persistence:** database/store, if known (it can be added later via the
     hard-stop process)
   - **Test framework + linter + type checker** for that stack
4. Copy `claude_code_development_guide_new.md` (the Guide) into the repository
   root. The init prompt reads it from disk — do NOT attach it.
5. **Permission-mode check:** never run the init (or any session in a governed
   repo) with `--dangerously-skip-permissions`. The generated settings pin
   `defaultMode: "default"`; that pin only protects you if you don't override
   it at the CLI.

## STEP 2 — INITIALIZATION (paste the master prompt)

Open Claude Code at the repository root. Paste the entire prompt below verbatim.

Unlike the brownfield edition there is no discovery report — there is nothing to
discover. The prompt asks ONE consolidated question (your stack choices), then
deploys everything without further conversation.

---------------------------------- PROMPT START ----------------------------------

Read the file `claude_code_development_guide_new.md` in this repository's root.
It is the engineering standard this initialization implements — internalize
Sections 2 (configuration), 4 (stateful layer + enforcement hooks), 5 (gates),
and 6 (testing discipline) before doing anything.

You are initializing a NEW repository. The prime directive: the constitution you
generate PRESCRIBES the ideal architecture, and enforcement is total from commit
#1. There is no legacy to accommodate, no baseline to ratchet — any finding is a
new finding and blocks. This is the one moment architecture is free; encode it.

PHASE A — STACK DECLARATION (one question, then zero conversation)

Ask me ONE consolidated question covering:
  1. Language + framework
  2. Persistence layer (or "none yet")
  3. Test framework, linter, type checker (propose stack-standard defaults
     I can accept with one word)
Wait for my answer. Everything after this runs without questions.

PHASE B — SCAFFOLD DEPLOYMENT (write everything)

  CRITICAL EXECUTION ORDER: Write .claude/settings.json LAST in Phase B, only
  after all other governance files (CLAUDE.md, .githooks/, quarantine.txt) have
  been fully written to disk. Once settings.json is written, these files are
  completely agent-immutable by design. Re-running initialization or repairing
  these files is a human-only action (hand-edit + PR); the agent cannot
  self-repair.

  B1. Directory scaffold per Guide §2.1:
      src/domain/, src/application/, src/infrastructure/, src/presentation/,
      tests/ mirroring src/ exactly, each with a placeholder module proving
      the import path works. Adapt directory idiom to the stack (e.g. Go:
      internal/domain etc.) while preserving the four-layer model and the
      mirror rule for tests.

  B2. CLAUDE.md at the root — the PRESCRIPTIVE constitution, containing:
      - The four-layer architecture enforcement section from Guide §2.2
        verbatim, with directory paths matching the scaffold
      - Naming contracts from Guide §2.2 (repositories fetch_*/find_*/
        persist_*/remove_*, Execute*/Query* use cases, PascalCase entities,
        past-tense events, tests/<layer>/test_<module> mirror rule)
      - The universal security invariants (Guide §2.2.1) verbatim, including
        the single-config-module rule
      - Hard stops (Guide §2.2.2 — the full table, which includes
        permission-mode/settings changes, CORE_FILES edits, and
        quarantining a test that covers a CORE_FILES module)
      - The boundary caveats P1–P3 from Guide §2.3 (permission mode pinned;
        git push ALWAYS standalone, never inside &&, ;, or | chains;
        refspec-force banned in text and refused by the pre-push hook)
      - The CORE_FILES constitution element per Guide §2.2.3, seeded with:
        the config module, src/domain/**, DI wiring, and test fixtures —
        maintained as the dependency graph grows (any module imported by
        >5 others joins it; editing the list is a hard stop)
      - Testing rules N1–N5 (Guide §6.1) plus the full §6.2 scaling block
        verbatim: the 60-second tier trigger, transitive closure for
        CORE_FILES, grep-is-a-lower-bound escalation (T4), committed
        quarantine.txt with the core-coverage hard stop (T2), and
        ledger-enforced tier transition (T5) — with this stack's exact
        test commands
      - The auto-pipeline (recon -> contract -> execute -> output) and the
        commit/push gate INCLUDING mandatory push confirmation (Guide §5.3)
      - Checkpoint trigger rules C1–C5, the schema, and the resume protocol
        (Guide §4.1)
      - A governance note (Guide §2.2.3): CLAUDE.md, the CORE_FILES list,
        settings, hooks, and baseline change ONLY via human-authored PR, never
        via agent edit; the agent never self-maintains the constitution

  B3. .claude/settings.json per Guide §2.3:
      - "defaultMode": "default" pinned at the top of permissions
      - Allow: read-only commands + this stack's exact test/lint/typecheck/
        build commands + git add/commit/diff/status/log/update-index
      - Deny: git reset --hard, git rebase, git clean, rm -rf, sudo, raw DDL,
        nc/ssh/scp, ALL force-push variants ("git push --force",
        "git push -f", "git push --force-with-lease", "git push --mirror",
        "git push --delete"),
        HOOK-EVASION variants ("git commit --no-verify*", "git commit -n *",
        "git push --no-verify*", "git -c core.hooksPath*") — without these,
        the allow-listed git commit is a silent back door around the entire
        enforcement layer,
        "Bash(SKIP_GATE=*)" (verify the matcher catches env-prefixed
        commands; if it does not, the pre-commit hook must refuse SKIP_GATE
        when agent-environment markers like $CLAUDECODE are present),
        and credential reads:
        "Read(.env)", "Read(**/.env)", "Read(**/.env.*)", "Read(**/*.pem)",
        "Read(**/id_rsa*)", "Read(**/.aws/credentials)" plus equivalent
        Bash cat patterns,
        and TRUST-ROOT writes (the agent must be mechanically blocked from
        editing the files that constrain it): "Write(.githooks/**)",
        "Edit(.githooks/**)", "Write(.claude/settings.json)",
        "Edit(.claude/settings.json)", "Write(.claude/baseline.json)",
        "Edit(.claude/baseline.json)", "Write(CLAUDE.md)", "Edit(CLAUDE.md)",
        "Bash(git notes*remove*)", "Bash(git update-ref -d*)",
        and PERSISTENT-HOOK-DISABLE + UNTRACKED-COMMIT variants:
        "Bash(git config core.hooksPath*)",
        "Bash(git config --add core.hooksPath*)", "Bash(git commit -a*)",
        "Bash(git commit -am*)", "Bash(git commit --amend*)" — the persistent
        git config form disables hooks for the whole clone, and -a/-am/--amend
        break the index-equals-commit-tree guarantee the gate relies on
      - git push in NEITHER list (it must prompt interactively)

  B4. .claude/commands/ — four files with this stack's real commands in every
      verification block:
      - feature.md: Phases 0–5 per Guide §3.2 — pre-flight, recon, design
        declaration, stubs-first (mandatory at 3+ files), implementation in
        strict layer order (Domain -> Infra -> App -> Presentation -> Tests),
        three-strike verification with the corrected index protocol before
        every re-run (git update-index -q --refresh; git diff --no-ext-diff —
        refresh reconciles stat metadata ONLY and must be paired with a
        content-level check), checkpoint evaluation at phase boundaries,
        full suite at the end (cheap while young), and COST-WARNING FIRING
        per Guide §7.1.1 (alert when a task iteration or phase exceeds ~40,000
        context tokens or history-retransmission waste crosses 50%)
      - audit.md: scoped to the gate script's change set (changed + staged +
        unstaged + untracked files); greenfield rule: ANY finding blocks
        (CRITICAL/HIGH await human; MEDIUM/LOW auto-fix then re-verify);
        checks: secrets patterns, injection vectors, bare excepts, missing
        auth on routes, layer violations.
        SEVERITY NORMALIZATION TABLE: generate a mapping from each chosen
        scanner's NATIVE levels (error/warning, E/W codes, HIGH/MEDIUM/LOW)
        to the gate actions {block-await-human, auto-remediate,
        record-only} and embed it in audit.md — "CRITICAL/HIGH blocks" is
        undefined for linters that only emit error/warning.
      - review.md: ledger-aware pre-PR gate — recompute the FULL fingerprint
        (Guide §4.2, including untracked files) and compare against
        gate_state.json; SKIP loudly only on exact match, printing the
        script-generated GATE REPORT verbatim (never a model-composed one).
        Otherwise: diff inventory, lockfile assertion (lockfile diff without
        approved dependency = HARD STOP), per-file layer compliance,
        secrets-in-diff grep, coverage check (every new function has a named
        test), quarantine report (a quarantined test covering CORE_FILES =
        HARD STOP), conventional-commit check, PR body generation; finish by
        having the gate script write the new receipt atomically
      - prep.md: natural language -> SCOPE/OBJECTIVE/CONSTRAINTS/VERIFY/
        OUTPUT contract, zero implementation, hard stops flagged at top

  B5. THE ENFORCEMENT LAYER — .githooks/ (Guide §4.4; this is what makes
      every "blocks" in the constitution mechanical rather than volunteered):
      - .githooks/gate.sh — the shared gate script. Its contract has exactly
        one correct implementation; encode ALL of the following:
          * TWO FINGERPRINT FORMS (Guide §4.2): the working-tree fingerprint
            (tree hash + pinned-config staged/unstaged diffs + sorted
            shasums of untracked files) keys ONLY the in-session ledger
            SKIP. Pre-commit receipts are keyed by the COMMIT TREE
            (git write-tree on the index being committed, via a temp
            index); pre-push matches git rev-parse 'HEAD^{tree}' against
            that key. Conflating the two makes pre-push block every
            legitimate push.
          * SCAN TARGET in pre-commit context = the index tree, never the
            working tree (git commit -a / git add -p make them differ).
          * COLD START: if last_pass_sha is null, the change set is ALL
            tracked + untracked files; on first pass set
            last_pass_sha = HEAD. (git diff null..HEAD is a fatal error —
            without this branch the gate crashes on the init verification
            commit itself.)
          * Audit + review checks with the severity normalization table.
          * Test execution: full suite until the 60s threshold; record
            full-suite wall time and emit TIER TRANSITION REQUIRED per
            Guide §6.2 T5 when exceeded twice. After the transition, the
            tier-2 algorithm per Guide §4.4: impact tooling first;
            degraded fallback (naming-contract tests + transitive
            CORE_FILES dependents, labeled as degraded) only while small;
            grep is never the selector.
          * IMPORT GRAPH (greenfield): build it at the first tier transition,
            or have gate.sh construct it live from the naming-contract layout.
            Until the graph exists, Tier-2-degraded falls back entirely to a
            full suite run to avoid coverage blind spots.
          * Atomic receipt writes (write tmp + rename) to gate_state.json.
          * GATE REPORT emission to stdout.
      - .githooks/pre-commit:
          * if SKIP_GATE is set: apply Guide §4.3 K1 — deny-first, then
            confirmation + reason via read -p from /dev/tty (a human-
            presence backstop, not a categorical guarantee); on success
            write the bypass as a git note (git notes --ref=bypasses add)
            on the commit and exit 0
          * else delegate to gate.sh; exit nonzero on any block
      - .githooks/pre-push:
          * refuse pushes to main/master/develop
          * refuse any refspec beginning with '+'
          * refuse any refspec containing a deletion semicolon targeting the
            bypass trail (echo "$@" | grep -qE ":refs/notes/bypasses" must
            return exit code 1)
          * recompute git rev-parse 'HEAD^{tree}' and require a passing
            receipt keyed by that commit-tree hash (never the working-tree
            fingerprint)
          * fetch refs/notes/bypasses, then enforce the bypass 24h deadline
            using COMMITTER DATES, never ledger timestamps
      - Per-clone activation (also wrapped in cc-init-hooks):
          git config core.hooksPath .githooks
          git config --add remote.origin.push  'refs/notes/bypasses:refs/notes/bypasses'
          git config --add remote.origin.fetch '+refs/notes/bypasses:refs/notes/bypasses'
        The notes refspecs are NOT optional: git does not push refs/notes/*
        by default — without them the bypass audit trail never leaves the
        laptop and CI cannot enforce the deadline.
      - Add a CI job, after git fetch origin 'refs/notes/*:refs/notes/*',
        so a hook-stripped clone still cannot merge unverified code. CI MUST
        NOT run the PR branch's gate.sh. It must execute a copy fetched from
        protected main to verify the PR's committed .githooks/ against a
        hash recorded on main; a mismatch triggers an immediate CI failure.
        CI parity is only authoritative if CI's gate script cannot be edited
        by the change under review.
        GOVERNANCE EVOLUTION PATH: governance and hook modifications are
        strictly gated by CODEOWNERS and required human review on a protected
        branch. The authoritative hash is updated by a privileged post-merge
        job or derived from the merge commit on origin/main, NOT a
        self-referential file inside the PR under review. CI compares against
        origin/main's hooks after an approved merge, establishing the new
        baseline.

  B6. Stateful-layer bootstrap:
      - .claude/gate_state.json with empty receipts and last_pass_sha: null
        (written only by gate.sh from here on)
      - .claude/checkpoints/ with README.md stating the schema (Guide §4.1)
        and the 10-file retention rule
      - quarantine.txt (empty, committed) with a header comment explaining
        Guide §6.2 T2

  B7. Project hygiene files:
      - .gitignore: stack-standard ignores + .env + .env.worktree +
        .claude/gate_state.json + .claude/checkpoints/
      - .env.example with placeholder keys only (never real values)
      - Dependency manifest with EXACT pinned versions for the minimal
        stack (framework, test runner, linter, type checker) — nothing
        speculative; additional dependencies arrive via the hard-stop process
      - A config module (single source of truth for env access) matching the
        security invariant — feature code never reads the environment
        directly
      - README.md: project name placeholder, quickstart including
        `cc-init-hooks`, and a pointer to CLAUDE.md as the constitution

  B8. .team_aliases at the root: write APPENDIX B of this document VERBATIM,
      substituting only the <source-dirs> placeholder with the scaffold's
      source and test directories (e.g. "src/ tests/", or the stack idiom
      chosen in B1). Beyond that substitution the file is byte-identical to
      Appendix B. Do not invent, add, or omit functions — security-relevant
      shell is never generated from memory.

PHASE C — VERIFICATION AND MANIFEST

  C1. Prove the scaffold is alive: run the test suite (placeholder tests
      pass), the linter, and the type checker — all exit 0.
  C2. Make a no-op commit on the setup branch to prove the pre-commit hook
      fires and emits a GATE REPORT; then verify the pre-push hook refuses
      a dry-run push to a protected branch name.
  C3. Output a manifest table: File | Purpose | Key rules encoded.
  C4. Output the three-line team summary: what was installed, that the
      baseline is zero-and-stays-zero, what changes about daily workflow
      (type intent; hooks and the pipeline handle the rest).
  C5. Remind me to commit everything EXCEPT .claude/gate_state.json and
      .claude/checkpoints/ (gitignored), and to open a PR so the team
      approves the constitution like any code.

----------------------------------- PROMPT END -----------------------------------

## STEP 3 — ACTIVATION (human developer action)

1. Review the generated CLAUDE.md end to end — it governs every future session.
2. Verify hooks are active: `git config core.hooksPath` must print `.githooks`.
3. Commit and PR the governance + scaffold:
   `git add -A && git commit -m "chore(claude): initialize governed greenfield environment"`
   (`git add -A` is acceptable ONLY for this birth commit — the constitution
   you just installed bans it from here on. The pre-commit hook fires on this
   very commit — that's the system working.)
4. Activate aliases: `source .team_aliases`, then lock in:
   `echo "source $(pwd)/.team_aliases" >> ~/.zshrc`
5. Every teammate, after cloning: `cc-init-hooks` (one time).

## STEP 4 — DAILY WORKFLOW (from now on)

The mental model to internalize: **you talk to Claude normally.** You do not write
execution contracts by hand — the auto-pipeline (CLAUDE.md §9) derives one from any
code-change message, and the git hooks enforce the gate mechanically no matter what
the session does. Your only standing jobs are: use `/prep` for non-trivial work,
answer hard-stop questions, confirm pushes, and start a fresh session per task.

The loop is identical in both environments; only the surface differs. Read the
section for the client you use.

### 4A. CLAUDE CODE — CLI (terminal)

One-time, per clone (DO THIS FIRST or the local hooks never fire):

```
source .team_aliases                 # or rely on the ~/.zshrc line from STEP 3
cc-init-hooks                         # sets core.hooksPath + bypass-note refspecs
```

Then, end to end:

1. **Start a task.** `cc-feature "add the payments endpoint"` — the wrapper refuses
   to launch on main/master/develop ("create a feature branch first") before Claude
   even starts. For a small, well-scoped change this is all you type.
2. **Scope something bigger first.** `/prep <description>` inside the session →
   review the SCOPE/OBJECTIVE/CONSTRAINTS contract → correct it in plain English →
   it executes. Use `cc-scope <symbol>` to see a change's impact radius first.
3. **Answer hard stops.** When the agent hits a new dependency, schema change,
   auth change, a CORE_FILES edit, or a governance file, it STOPS and asks. Reply
   with the decision. It cannot edit CLAUDE.md / settings.json / .githooks — those
   are human-PR-only, and it will say so if you ask.
4. **Commit + push.** Say `commit and push`. The model runs audit → review →
   tests and prints a GATE REPORT. In a greenfield repo there is no baseline —
   ANY finding blocks. It then states the branch + remote and waits for your `yes`
   (Gate Step 4). The pre-commit / pre-push hooks fire mechanically regardless.
   - Prefer `cc-push`: it prints branch + remote and makes you **type the branch
     name** at the terminal (`/dev/tty`) to confirm — a fourth, model-independent
     human gate. The `git push` permission prompt appears as a terminal y/n.
5. **Next task = new session.** One task per session. A new session auto-resumes
   from `.claude/checkpoints/LATEST.md`; `cc-checkpoint` writes one by hand before
   you stop. Heed the §7.1.1 cost warning — `/compact` or restart.
6. **Emergency only.** `SKIP_GATE=1 git commit ...` typed BY YOU in a plain
   terminal (never through the agent — it's deny-listed). The hook demands a typed
   reason via `/dev/tty`, records a git note, and starts the 24h re-run clock.

### 4B. CLAUDE CODE — Desktop app

One-time, per clone (DO THIS FIRST or the local hooks never fire). The app has no
shell aliases, so run the activation directly in the repo, or use the setup target:

```
git config core.hooksPath .githooks
git config --add remote.origin.push  'refs/notes/bypasses:refs/notes/bypasses'
git config --add remote.origin.fetch '+refs/notes/bypasses:refs/notes/bypasses'
```

Then, end to end:

1. **Start a task.** Type the request in chat in plain English, or use `/feature
   <description>`. There is no `cc-feature` branch-guard wrapper here — instead the
   pipeline's Phase 0 pre-flight checks the branch and refuses to proceed on
   main/master/develop. Same protection, enforced inside the pipeline.
2. **Scope something bigger first.** `/prep <description>` → review the contract in
   chat → correct it → it executes. Recommended for anything multi-file or touching
   shared/core modules.
3. **Answer hard stops.** Same as CLI — the agent stops and asks on new deps,
   schema, auth, CORE_FILES, or governance files, and cannot edit the trust-root
   files.
4. **Commit + push.** Say `commit and push`. Same GATE REPORT (greenfield: any
   finding blocks), same hooks. The difference: **the `git push` permission prompt
   is a UI approval card**, not a terminal y/n, and there is no `cc-push` "type the
   branch" step — so the **Gate Step 4 chat confirmation is your primary human
   gate.** Actually read the branch + remote line before clicking Allow.
5. **Next task = new conversation.** Start a new conversation for an unrelated
   task. Checkpoints are written automatically at phase boundaries; say "write a
   checkpoint" if you want one before stopping. Heed the §7.1.1 cost warning.
6. **Emergency only.** Same rule: `SKIP_GATE=1 git commit ...` is typed BY YOU in a
   real terminal outside the app — the agent is deny-listed from forming it, and
   the hook's `/dev/tty` reason prompt cannot be answered by the app's subprocess.

## WHAT SUCCESS LOOKS LIKE (first two weeks)

| Signal | Expected |
|---|---|
| Birth commit | Suite, linter, type checker all exit 0; pre-commit hook emits its first GATE REPORT |
| First feature | Stubs compiled before implementation; one commit per layer |
| Any lint/security finding | Hook BLOCKS — there is no baseline to absorb it |
| Brand-new untracked file with a finding | Gate runs (fingerprint includes untracked files) and BLOCKS |
| `SKIP_GATE=1` from a Claude session | Blocked by settings deny; TTY adds human-presence assurance where the agent has no terminal |
| Session killed mid-task, reopened | Resume from checkpoint in under a minute |
| Suite runtime | Recorded by gate.sh every run; TIER TRANSITION REQUIRED fires automatically at the 60s threshold |

---

## APPENDIX B — CANONICAL .team_aliases (written verbatim by init step B8)

```bash
#!/usr/bin/env bash
# Claude Code team aliases — generated by the init package, edited only via PR.
# Source in ~/.zshrc:  echo "source $(pwd)/.team_aliases" >> ~/.zshrc

# One-time activation per clone: hooks + bypass-note propagation.
# (git does not push refs/notes/* by default — without the refspecs the
#  bypass audit trail never leaves this machine.)
cc-init-hooks() {
    git config core.hooksPath .githooks
    git config --add remote.origin.push  'refs/notes/bypasses:refs/notes/bypasses'
    git config --add remote.origin.fetch '+refs/notes/bypasses:refs/notes/bypasses'
    echo "Hooks active: .githooks (bypass-note refspecs configured)"
}

# Branch-guarded feature entry point — the standard way to start any task.
cc-feature() {
    [ -z "$1" ] && echo "Usage: cc-feature <description>" && return 1
    local branch=$(git branch --show-current)
    case "$branch" in
        main|master|develop)
            echo "ERROR: on protected branch '$branch'. Create a feature branch first."
            return 1;;
    esac
    claude "/feature $*"
}

# Scoped audit of current changes (full repo only if no changes).
cc-audit() {
    local changed=$(git diff main...HEAD --name-only | tr '\n' ' ')
    [ -z "$changed" ] && claude "/audit" || claude "/audit Scope: $changed"
}

cc-review() { claude "/review"; }

# Impact radius for a symbol before touching it.
# <source-dirs> is substituted at init with the scaffold's source and
# test directories (e.g. "src/ tests/").
cc-scope() {
    [ -z "$1" ] && echo "Usage: cc-scope <symbol>" && return 1
    echo "=== Impact radius for '$1' (grep lower bound — see Guide §6.2 T4) ==="
    grep -rn "$1" <source-dirs> 2>/dev/null | head -30
}

# cc-checkpoint — the STANDARD manual checkpoint command. Run it on demand to
# write the Guide §4.1 state schema straight to .claude/checkpoints/ (state,
# not conversation), refresh LATEST.md, and enforce 10-file retention. Use it
# before /compact, before a restart, or whenever a resumable snapshot is wanted.
cc-checkpoint() {
    mkdir -p .claude/checkpoints
    local ts=$(date +%Y%m%d-%H%M)
    local f=".claude/checkpoints/${ts}-manual.md"
    {
        echo "# CHECKPOINT"
        echo "phase:        manual"
        echo "git_sha:      $(git rev-parse HEAD)"
        echo "branch:       $(git branch --show-current)"
        echo "dirty_files:  $(git status --porcelain | wc -l | tr -d ' ') uncommitted"
        echo "timestamp:    ${ts}"
        echo ""
        echo "## FILES MODIFIED THIS SESSION"
        git diff --name-only HEAD
        echo ""
        echo "## RESUME INSTRUCTION"
        echo "<fill in before closing the session>"
    } > "$f"
    cp "$f" .claude/checkpoints/LATEST.md
    # Retention: keep the 10 most recent checkpoint files.
    find .claude/checkpoints -name '2*.md' -type f 2>/dev/null | sort -r | tail -n +11 | while read -r f; do rm -f "$f"; done
    echo "Checkpoint: $f"
}

# Model-independent human-in-the-loop push. The pre-push hook still runs.
# Confirmation reads /dev/tty directly: piped stdin cannot auto-confirm
# (printf 'branch\n' | cc-push fails by design).
cc-push() {
    local branch=$(git branch --show-current)
    case "$branch" in
        main|master|develop)
            echo "ERROR: direct push to '$branch' is forbidden."
            return 1;;
    esac
    # Resolve the remote the way git push would — never "first remote
    # alphabetically", which silently picks 'fork' over 'origin'.
    local remote=$(git config --get "branch.${branch}.pushRemote" \
                || git config --get remote.pushDefault \
                || echo origin)
    echo "About to push: branch '$branch' -> remote '$remote'"
    printf "Type the branch name to confirm: "
    local confirm
    read -r confirm < /dev/tty || { echo "No TTY — aborted."; return 1; }
    [ "$confirm" != "$branch" ] && echo "Aborted (input did not match)." && return 1
    git push "$remote" "$branch"
}

# Auto-loaded CLAUDE.md token cost per project.
cc-context-size() {
    find . -name "CLAUDE.md" -not -path "*/node_modules/*" | while read -r f; do
        local chars=$(wc -c < "$f")
        echo "  $f: $chars chars (~$((chars/4)) tokens auto-loaded)"
    done
}
```

Notes on the appendix:
- There is deliberately NO cc-hotfix: emergencies go through `cc-feature` on a
  `hotfix/*` branch (full gate — the suite is fast in a young repo) or, for true
  production-down moments, the human-typed `SKIP_GATE=1` path with its TTY
  confirmation and git-note audit trail. A separate alias invoking a command
  that may not exist is how phantom workflows are born.
- `cc-push` complements, never replaces, the pre-push hook and the Gate Step 4
  chat confirmation — three independent layers.
