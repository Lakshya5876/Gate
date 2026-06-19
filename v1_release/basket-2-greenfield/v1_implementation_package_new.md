# CLAUDE CODE — WORKSPACE INITIALIZATION PACKAGE
## Edition: NEW PROJECTS (Greenfield)

**Companion document:** `v1_claude_code_development_guide_new.md` (the Guide)
**Time required:** ~12 minutes, once at project birth
**Outcome:** A repository born governed — prescriptive architecture, hook-enforced
gates from commit #1, zero debt ever.

> **Status: V1 production-ready.** Specification verified through 3 audit rounds and mechanically tested: pre-commit fingerprint receipts, coverage gate, CORE_FILES tier-3 escalation, identity-based debt ratchet, CI backstop, and IDE extension crash guard all confirmed functional. Install and proceed.

---

## STEP 1 — PRE-FLIGHT (human developer action)

1. Create the repository and make an initial commit (even an empty README is
   fine): `git init && git commit --allow-empty -m "chore: repository birth"`
2. Create a setup branch: `git checkout -b chore/claude-init`
3. Ensure you have executed the installer script (`/path/to/ai-dev-workflow/install.sh`) from within this repository's root.
4. Decide three things BEFORE running the init (the prompt will ask):
   - **Stack:** language + framework (e.g. Python/FastAPI, TS/Node/Express,
     Go/chi)
   - **Persistence:** database/store, if known (it can be added later via the
     hard-stop process)
   - **Test framework + linter + type checker** for that stack
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

Read the file `v1_claude_code_development_guide_new.md` in this repository's root.
It is the engineering standard this initialization implements — internalize
Sections 2 (configuration), 4 (stateful layer + enforcement hooks), 5 (gates),
6 (testing discipline), and SECTION 2.5 (cognitive routing + execution gates)
before doing anything.

CRITICAL: SECTION 2.5 rules are NON-NEGOTIABLE and fire on EVERY task in this
governed repository, starting immediately after initialization:

SECTION 2.5 — COGNITIVE ROUTING & EXECUTION GATES (Always Active)

  2.5.1 — MODEL INTERCEPT (Cognitive Routing)
    Every task triggers automated model selection logic BEFORE execution:
    - Analyze task type: (architecture | security | performance | test | deploy)
    - Route to appropriate model if available; fallback to primary if not
    - This routing is NON-BYPASSING — the agent cannot override it
    - Task routing decisions are logged in gate_state.json ledger

  2.5.2 — EXECUTION MODE DECLARATION (Menu Gate)
    Before ANY file is written, the agent MUST declare ONE of:
      [ ] MUST OUTPUT: task is design/analysis/report — no code changes, only text
      [ ] HARD STOP: task requires human approval before proceeding (new dep,
          auth change, schema change, CORE_FILES edit, settings change)
      [ ] EXECUTE: task is code change — proceed with full pipeline
    Wrong declaration blocks the task. The agent cannot change mode mid-task.

  2.5.3 — GRAPH MEMORY PROTOCOL (Tool Invocation Rules)
    Every tool call is context-aware and logged:
    - Read tools: logged once per file per session (avoid re-reads)
    - Bash commands: cached stdout for 5-minute reuse window
    - Edit/Write tools: require prior Read call (trust-root rule)
    - Web/External tools: only after exhausting local codebase tools
    - If tool call is repetitive (same call within 10 mins): STOP and analyze
    - Graph memory (what the agent knows about the codebase) expires at
      session boundary; new session = fresh recon

  2.5.4 — GITFLOW BRANCH ENFORCEMENT (Hard Block on Protected Branches)
    These rules are MECHANICAL, never conditional:
    - BLOCK HARD: any git push to main / master / develop (pre-push hook refuses)
    - BLOCK HARD: git commit on main / master / develop (feature branch mandate)
    - Feature branch naming: feature/*, fix/*, docs/*, chore/* only
    - Pre-push hook verifies branch protection BEFORE auth/network checks
    - User cannot override; no --force, no --no-verify, no exceptions
    - Protected-branch bypass requires human-authored PR + code review
    - Protected branch = main, master, develop, production, release/*

  2.5.5 — TOKEN HARNESS & COST AWARENESS (Hard Blocks at Budget Thresholds)
    Token budgets are PER-TASK, non-negotiable:
    - Task token budget: 200,000 tokens (default, specified in system prompt)
    - Soft warning at 70% (140,000 tokens): agent must summarize & checkpoint
    - Hard block at 100% (200,000 tokens): execution STOPS immediately
    - History retransmission waste (repeated passages) hard block at 50%
      - If retransmitted content exceeds 50% of budget, task halts
    - When hard block fires: state what is known, what remains unfinished,
      write all checkpoints, then exit (never continue on next token window)
    - Token budget resets per task; cannot carry over or negotiate up
    - Cost warnings MUST be emitted to user at 80%, 90%, 100%

  2.5.6 — EXECUTION PIPELINE INVARIANTS (Always Fire, Never Bypass)
    Every code-change task auto-triggers this pipeline without confirmation:
    Step 1: RECON (read-only) — grep, locate, scope the change
    Step 2: CONTRACT (internal) — SCOPE/OBJECTIVE/CONSTRAINTS/VERIFY/OUTPUT
    Step 3: EXECUTE — write code, run tests, verify gates
    Step 4: OUTPUT — change manifest, test results, commit message
    
    Hard stops within pipeline: new dependency, auth change, schema change,
    CORE_FILES edit, settings change, permission-mode change, hook modification.
    Agent states the hard stop, waits for human approval, cannot self-resolve.

  2.5.7 — VS CODE / IDE EXTENSION CRASH GUARD (Non-Bypassing Environment Rule)
    Before outputting the Execution Mode Menu (2.5.2/2.5.3) or blocking execution
    on an interactive human choice, the agent MUST check whether it is running
    inside a non-TTY or IDE-extension terminal wrapper (e.g. `[ -t 0 ]` is false,
    or extension env flags such as TERM_PROGRAM=vscode, VSCODE_PID,
    VSCODE_GIT_IPC_HANDLE, CURSOR_*, or a JetBrains terminal marker are present).
    Sequential interactive dialog loops choke the extension's sub-process pipeline
    and crash the editor window. If an extension / non-interactive environment is
    detected:
      1. DO NOT launch an interactive choice loop or call AskUserQuestions
         sequentially.
      2. EXECUTION MODE MENU: automatically select option [1] DIRECT as the safe
         default, log the auto-selection to .claude/session_state.json
         (mode=DIRECT, reason=extension_crash_guard, timestamp), and output the
         high-visibility line:
         "[CRASH GUARD] VS Code/IDE extension detected. Suppressing interactive
          menu and defaulting to Option 1 (DIRECT) to prevent UI crash."
      3. HARD STOPS: do NOT stall on an un-answerable prompt loop. State the
         hard-stop parameters clearly in plain text, emit a clean one-line
         warning, write a checkpoint file under .claude/checkpoints/ capturing the
         pending decision, and halt execution awaiting the human's next message —
         never a blocking interactive read.
    This rule is environment-detection only; it never weakens a hard stop's
    requirement for human approval — it changes HOW approval is solicited (async
    text + checkpoint) so the editor cannot freeze. In a real TTY (CLI / desktop
    app) the normal interactive menu and prompts apply unchanged.

You are initializing a [NEW | EXISTING] repository. The prime directive: [the
constitution you generate PRESCRIBES the ideal architecture | the constitution
you generate DESCRIBES the architecture that actually exists]. Every rule you
write will be enforced by mechanical gates and SECTION 2.5 cognitive routing
on every future task. A rule that doesn't match the repo (new projects) or
contradicts reality (existing projects) creates permanent noise.

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

  B3. [DEFERRED — written LAST per CRITICAL EXECUTION ORDER above]
      .claude/settings.json per Guide §2.3:
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
        "Write(v1_claude_code_development_guide_new.md)",
        "Edit(v1_claude_code_development_guide_new.md)",
        "Write(v1_implementation_package_new.md)",
        "Edit(v1_implementation_package_new.md)",
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
        declaration (Phase 2), stubs-first (mandatory at 3+ files), implementation
        in strict layer order (Domain -> Infra -> App -> Presentation -> Tests),
        three-strike verification with the corrected index protocol before
        every re-run (git update-index -q --refresh; git diff --no-ext-diff —
        refresh reconciles stat metadata ONLY and must be paired with a
        content-level check), checkpoint evaluation at phase boundaries,
        full suite at the end (cheap while young), and COST-WARNING FIRING
        per Guide §7.1.1 (alert when a task iteration or phase exceeds ~40,000
        context tokens or history-retransmission waste crosses 50%).
        PHASE 2 (Design Declaration): the agent must programmatically deduce
        the testing architecture from repository roots (§6.0 Dynamic Stack
        Inference) — inspect package.json, requirements.txt, pyproject.toml,
        go.mod, or CI config; never assume a fixed runner. If a frontend or
        proxy layer is present, declare Playwright E2E user journeys implicitly
        (web-first async assertions, network contract checks) — zero prompts
        seeking human instruction on test paths.
        PHASE 3 (Implementation): execute all inferred test suites completely
        autonomously using the deduced runner engine(s). When UI/routing/rendering
        paths change, auto-generate and run Playwright specs (*.spec.ts or stack
        equivalent). Sequence backend + E2E runners; both must exit 0. No
        conversational filler or prompts asking the developer for test
        specifications are permitted.
      - audit.md: scoped to the gate script's change set (changed + staged +
        unstaged + untracked files); greenfield rule: ANY finding blocks
        (CRITICAL/HIGH await human; MEDIUM/LOW auto-fix then re-verify);
        checks: secrets patterns, injection vectors, bare excepts, missing
        auth on routes, layer violations.
        SEVERITY NORMALIZATION TABLE: generate a mapping from each chosen
        scanner's NATIVE levels (error/warning, E/W codes, HIGH/MEDIUM/LOW)
        AND test-runner output formats (JUnit XML, JSON reporters, Playwright
        HTML/matrix/JSON reporters, Go test -json, pytest exit codes) to the
        gate actions {block-await-human, auto-remediate, record-only} and embed
        it in audit.md — "CRITICAL/HIGH blocks" is undefined for linters that
        only emit error/warning or for test suites that emit structured reports
        without severity labels.
        SELF-HEALING FAILURE BRANCH: if an auto-remediation attempt
        (MEDIUM/LOW) does not eliminate the finding on re-verify, treat
        it as a hard block and report to the human — do not retry. Apply
        the §3.3 three-strike rule to any auto-fix attempt: three failed
        fix-and-re-verify cycles on the same finding → STOP, report
        verbatim, await human.
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

  B5. THE ENFORCEMENT LAYER:
      Do NOT generate or modify `.githooks/gate.sh`, `.githooks/pre-commit`, or `.githooks/pre-push`. These files have already been placed in the repository by the installation script. Leave them untouched. You must only verify that the `.githooks/` directory exists.

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

  B8. .team_aliases at the root: Read v1_claude_code_development_guide_new.md
      from disk and copy APPENDIX B (the section headed "APPENDIX B —
      CANONICAL .team_aliases") VERBATIM into .team_aliases, substituting
      only the <source-dirs> placeholder with the scaffold's source and test
      directories (e.g. "src/ tests/", or the stack idiom chosen in B1).
      Beyond that substitution the file is byte-identical to Appendix B.
      Do not invent, add, or omit functions — security-relevant shell is
      never generated from memory.

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

> Appendix B (CANONICAL .team_aliases) has moved to
> `v1_claude_code_development_guide_new.md`. Step B8 reads it from that
> file on disk — single source of truth, no truncation risk.
