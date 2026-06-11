# CLAUDE CODE — THE ENTERPRISE EXECUTION STANDARD
## Edition: EXISTING REPOSITORIES (Brownfield)

**Classification:** Internal Engineering Standard
**Audience:** All Engineering Personnel — Junior through Principal
**Applies to:** Any repository with existing code, history, and accumulated debt
**Companion document:** Implementation Package (Existing Repos) — contains the one-time init prompt

> Every section is immediately actionable. The difference between an engineer who uses
> Claude Code and one who is unbeatable with it is not talent — it is methodology.
> This document is that methodology, adapted for the reality of existing codebases:
> legacy debt, enormous file counts, pre-existing test suites, and architecture that
> grew organically rather than by design.

| Section | Title | Core Skill Delivered |
|---|---|---|
| 1 | The Paradigm Shift | Execution contracts vs. conversational chatting |
| 2 | Enterprise Configuration | CLAUDE.md (descriptive), settings.json, skill commands |
| 3 | The Agentic Pipeline | Scanning tiers, stubs-first, self-correction |
| 4 | The Stateful Layer | Checkpoints, gate-state ledger, baseline ratchet |
| 5 | Code Quality Guardrails | Atomic commits, incremental gates, hard stops |
| 6 | Testing at Scale | 3-tier test selection for large suites |
| 7 | Session & Context Management | Budgets, compact vs. restart, XL decomposition |
| 8 | Worktree Isolation | Parallel agentic sessions without contamination |
| 9 | Performance Rubric | Beginner → Expert self-assessment |
| 10 | Quick Reference | Field card |
| A | Onboarding Path | 30-day transition schedule |

---

# SECTION 1 — THE PARADIGM SHIFT

## 1.1 Two Execution Models: One Correct, One Comfortable

Most engineers approach Claude Code like a senior colleague over Slack — ask, receive,
paste, ask again. Wrong mental model. Claude Code is an autonomous execution engine.
Treating it like a chat assistant is hiring a robotics engineer to fetch coffee one cup
at a time.

**Model A — Conversational (the amateur trap):**

```
Engineer                     Claude Code                   Codebase
   |--"add auth to endpoint"----->|                            |
   |                              |--reads 1 file ------------>|
   |<--"here is the middleware"---|                            |
   |--"now add the token check"-->|                            |
   |<--"here is the token logic"--|                            |
   |--"the tests are failing"---->|                            |
   |<--"fix this import path"-----|                            |
   |--"now update the docs"------>|                            |
   |<--"here is the doc block"----|                            |

  [6 round trips | 35k+ tokens | 25 minutes | 6 manual pastes]
  [By turn 6, attention on your CURRENT instruction is diluted
   by 13 prior messages re-read on every turn]
```

**Model B — Agentic Execution Contract (the expert standard):**

```
Engineer                     Claude Code                   Codebase
   |--[single execution contract]>|                            |
   |                              |--grep: locate auth layer-->|
   |                              |--read: handler (targeted)->|
   |                              |--edit: auth handler------->|
   |                              |--bash: run impacted tests->|
   |                              |<--[failure output]---------|
   |                              |--read: root cause--------->|
   |                              |--edit: fix---------------->|
   |                              |--bash: re-run, all pass--->|
   |<--[complete: summary + diff]-|                            |

  [1 round trip | ~7k tokens | 4 minutes | 0 manual pastes]
```

## 1.2 The Token Debt Spiral — Quantified

Every conversational turn carries the full cumulative context as overhead:

```
Turn 1:                                          =  1,280 tokens
Turn 2:  (672 tokens were history — 34% waste)   =  1,950 tokens
Turn 3:  (2,350 tokens were history — 68% waste) =  3,440 tokens
Turn 6:                                          = 14,100 tokens
---------------------------------------------------------------
Total, 6 conversational turns:                   = 35,770 tokens
Same work as a single agentic contract:          =  7,400 tokens
Wasted on context retransmission:                = 28,370 (79%)
```

As history grows, effective attention on your current instruction dilutes. You get less
intelligent output for more tokens.

## 1.3 The Execution Contract — The Fundamental Unit of Work

Stop writing prompts. Write execution contracts — single, complete, machine-executable
specifications that need zero follow-up questions.

| Field | Definition | If Missing |
|---|---|---|
| SCOPE | Explicit list of dirs/files in scope. Everything else is off-limits. | Agent reads unrelated files, wastes tokens |
| OBJECTIVE | The condition that must be TRUE when done — not what to do. | Ambiguous success; agent stops early or overshoots |
| CONSTRAINTS | Rules that cannot be broken: architectural, security, dependency, naming. | Layer violations, security gaps, style drift |
| VERIFY | Exact command(s) producing deterministic pass/fail. | Agent marks complete without evidence |
| OUTPUT | What to produce: diff summary, test results, commit message. | Human cannot quickly validate |

```
# WEAK (forces follow-up, ambiguous success)
"add rate limiting to the API"

# STRONG (self-contained, deterministic, zero follow-up)
Scope:      src/api/handlers/, src/middleware/, tests/unit/middleware/
Objective:  Every public HTTP route handler is protected by per-IP rate
            limiting — 60 req/min. State in process memory only.
            No new infrastructure dependencies.
Constraints:
  - Initialise limiter once at application startup only
  - No business logic inside middleware
  - All existing handler tests pass without modification
Verify:     <test-runner> tests/unit/middleware/test_rate_limiter.py
            Exit code 0. Print full output.
Output:     Table of files touched. Full test output.
            One-line Conventional Commit message.
```

**The Quality Axiom:** Claude Code produces exactly the quality you specify.
The output ceiling is always the prompt floor.

---

# SECTION 2 — ENTERPRISE CONFIGURATION

## 2.1 The Complete Directory Structure

```
your-repository/
|
+-- CLAUDE.md                    <- Constitution (auto-loaded every session)
+-- v1_claude_code_development_guide_existing.md   <- this document (gitignored or docs/)
|
+-- .claude/
|   +-- settings.json            <- Permission boundaries
|   +-- baseline.json            <- Frozen debt identities (BROWNFIELD ONLY — see §4.3)
|   +-- gate_state.json          <- Gate receipts ledger (gitignored — see §4.2)
|   +-- checkpoints/             <- Session state snapshots (gitignored — see §4.1)
|   +-- commands/
|       +-- feature.md           <- /feature  full implementation pipeline
|       +-- audit.md             <- /audit    diff-scoped security + architecture audit
|       +-- review.md            <- /review   pre-PR gate
|       +-- prep.md              <- /prep     natural language -> execution contract
|
+-- .githooks/
|   +-- pre-commit               <- THE GATE, mechanically enforced (see §4.5)
|   +-- pre-push                 <- receipt validation + bypass deadline + force guard
|
+-- quarantine.txt               <- committed flaky-test quarantine (see §6 T4)
+-- src/ ...    (or whatever your repo actually uses — see §2.2)
+-- tests/ ...
```

Add to `.gitignore`:

```
.claude/gate_state.json
.claude/checkpoints/
```

`baseline.json`, `.githooks/`, and `quarantine.txt` ARE committed — the whole team
shares one debt baseline and one gate. Each clone activates the hooks once:
`git config core.hooksPath .githooks` (wrapped as `cc-init-hooks` in .team_aliases).

## 2.2 CLAUDE.md — The DESCRIPTIVE Constitution

**This is the single most important brownfield rule:**

> In an existing repository, CLAUDE.md must DESCRIBE the architecture that actually
> exists — not prescribe a textbook ideal. A constitution that contradicts the real
> codebase causes every gate check to fail on every file, and the entire system
> becomes noise the team learns to ignore within a week.

The constitution is generated by the init prompt (see Implementation Package) AFTER
a staged reconnaissance pass and a human-confirmed discovery report. It codifies:

- The layer names and directories your repo ACTUALLY uses
- The naming conventions ALREADY in your code (discovered, not invented)
- Your real test framework, runner commands, and linter
- Security invariants (these ARE universal — see below)
- Hard stops (universal)
- The enforcement scope rule (brownfield-specific — see §2.2.1)

### 2.2.1 The Enforcement Scope Rule (Touched-Files-Only)

```
## ENFORCEMENT SCOPE (BROWNFIELD)
- The constitution applies FULLY to: new files, and any region of an
  existing file modified in the current task.
- Untouched legacy code is EXEMPT until touched (boy-scout rule).
- Never demand a refactor of an unrelated legacy file as a precondition
  for a small change. Flag the debt; do not block on it.
- When touching a legacy file, leave the touched region cleaner than
  found: parameterise the query you edited, type the function you
  modified — but do NOT rewrite the whole file.
```

Without this rule, every small fix demands refactoring a 3,000-line god-file first,
and the team abandons the system. With it, quality ratchets upward with every commit.

### 2.2.2 Universal Security Invariants (identical in every constitution)

```
## SECURITY INVARIANTS (ABSOLUTE — NEVER NEGOTIATE)
- Credentials/secrets/keys NEVER written to any file on disk.
- .env is in .gitignore. Must never be committed.
- Every route exposing data requires explicit auth enforcement.
- Raw exceptions and stack traces NEVER returned to clients.
- User input NEVER interpolated into query strings — parameterised only.
- Secrets NEVER appear in log output at any level.
```

### 2.2.3 Hard Stops (universal)

| Trigger | Why human approval is required |
|---|---|
| New runtime dependency / lockfile alteration | Supply chain; hidden transitive deps bypass review |
| Database schema migration | Irreversible in production |
| Auth/authz logic change | Direct path to access-control bypass |
| New environment variable | Must be provisioned in all environments |
| Deployment/infra config | Misconfiguration causes outages |
| CI/CD pipeline modification | Can silently suppress security checks |
| .gitignore changes | Could unblock accidental secret commits |
| Background job/scheduler | Double-processing or data loss |
| Changes to .claude/baseline.json by hand | Defeats the ratchet (see §4.3) |
| Permission-mode change or settings.json edit | Disabling the prompt layer disables the only mechanical push gate |
| Editing the CORE_FILES list in CLAUDE.md | Shrinks the tier-3 test trigger silently (see §6) |
| Quarantining a test that covers a CORE_FILES module | Removes the one test that catches a core regression (see §6) |
| Any modification to `.githooks/**` or the CI gate definition | Direct trust-root compromise; bypassing local or pipeline constraints |

### 2.2.4 Governance Files Are Human-PR-Only

CLAUDE.md, the CORE_FILES list, settings, hooks, and baseline definitions
change exclusively via human-authored pull requests, never via automated agent
edits. The core list grows as the dependency graph grows, but it is updated via
a human engineering pass. The agent never self-maintains the constitution; the
deny list (§2.3) enforces this mechanically.

## 2.3 settings.json — Hard Permission Boundaries

Anything not in the allow list prompts; anything in the deny list is blocked outright.

```json
{
  "permissions": {
    "defaultMode": "default",
    "allow": [
      "Bash(grep:*)", "Bash(find:*)", "Bash(ls:*)", "Bash(cat:*)",
      "Bash(git status:*)", "Bash(git diff:*)", "Bash(git log:*)",
      "Bash(git show:*)", "Bash(git branch:*)", "Bash(git add:*)",
      "Bash(git commit:*)", "Bash(git update-index:*)",
      "Bash(<your-test-runner>:*)",
      "Bash(<your-linter>:*)",
      "Bash(<your-type-checker>:*)",
      "Read(*)", "Edit(*)", "Write(*)"
    ],
    "deny": [
      "Bash(git reset --hard:*)", "Bash(git rebase:*)",
      "Bash(git push --force:*)", "Bash(git push -f:*)",
      "Bash(git push --force-with-lease:*)", "Bash(git push --mirror:*)",
      "Bash(git push --delete:*)", "Bash(git clean:*)",
      "Bash(git commit --no-verify*)", "Bash(git commit -n *)",
      "Bash(git push --no-verify*)", "Bash(git -c core.hooksPath*)",
      "Bash(SKIP_GATE=*)",
      "Bash(rm -rf:*)", "Bash(sudo:*)",
      "Bash(DROP TABLE:*)", "Bash(DROP DATABASE:*)",
      "Bash(nc:*)", "Bash(ssh:*)", "Bash(scp:*)",
      "Read(.env)", "Read(**/.env)", "Read(**/.env.*)",
      "Read(**/*.pem)", "Read(**/id_rsa*)", "Read(**/.aws/credentials)",
      "Bash(cat .env:*)", "Bash(cat *.pem:*)",
      "Write(.githooks/**)", "Edit(.githooks/**)",
      "Write(.claude/settings.json)", "Edit(.claude/settings.json)",
      "Write(.claude/baseline.json)", "Edit(.claude/baseline.json)",
      "Write(CLAUDE.md)", "Edit(CLAUDE.md)",
      "Bash(git notes*remove*)", "Bash(git update-ref -d*)",
      "Bash(git config core.hooksPath*)", "Bash(git config --add core.hooksPath*)",
      "Bash(git commit -a*)", "Bash(git commit -am*)", "Bash(git commit --amend*)"
    ]
  }
}
```

The `--no-verify` and `core.hooksPath` denies exist because `git commit --no-verify`
skips the pre-commit hook entirely — an allow-listed `Bash(git commit:*)` rule
without them is a silent back door around the whole enforcement layer (§4.5).
The trust-root denies (`.githooks/**`, `settings.json`, `baseline.json`,
`CLAUDE.md`, notes removal, ref deletion) mechanically block the agent from
editing the files that constrain it — a gate the agent can rewrite is not a gate.
These governance files change only via human-approved PR.

**Critical placement rule for `git push`:** put it in NEITHER list. Not in allow
(no silent pushes), not in deny (a deny rule is a hard block — the user never even
sees an approval dialog). Absent from both lists, every push triggers an interactive
Allow/Deny prompt — which is exactly the human-in-the-loop behavior you want.
The chat-level confirmation (§5.3 Gate Step 4) and the pre-push hook (§4.5) are the
primary gates; the dialog is the backstop.

**Boundary caveats (encode all three in CLAUDE.md at init):**

```
P1. PERMISSION MODE: governed repos MUST NOT be operated with
    --dangerously-skip-permissions or defaultMode: bypassPermissions.
    Either nullifies the interactive prompt — the backstop evaporates
    with one CLI flag. defaultMode is pinned to "default" in the
    committed settings.json; changing it is a hard stop (§2.2.3).
P2. COMPOUND COMMANDS: allow rules match command PREFIXES. A compound
    command ("git status && git push origin HEAD") can smuggle a push
    under an allowed prefix on any client with naive prefix matching.
    Rule: git push is ALWAYS issued as a standalone command, never
    inside &&, ;, or | chains — so the prompt always fires.
P3. FORCE-PUSH COVERAGE: the deny list blocks the named force variants,
    but refspec-force syntax (git push origin +main) cannot be
    pattern-matched. It is banned in constitution text and caught by
    the pre-push hook (§4.5) and Gate Step 4 — never describe force-push
    as "hard-blocked" on the deny list alone.
```

## 2.4 Custom Slash Commands

Each file in `.claude/commands/` becomes a `/commandname`. `$ARGUMENTS` receives the
text after the command name. The Implementation Package generates these with your
repo's real commands substituted in. The four commands and their jobs:

| Command | Job | Brownfield-specific behavior |
|---|---|---|
| /feature | Full implementation pipeline (Phases 0–5, see §3) | Checkpoint writes at phase boundaries; impacted-tests-only during EXECUTE |
| /audit | Security + architecture audit | DIFF-SCOPED by default; compares findings against baseline.json; only NEW findings block |
| /review | Pre-PR gate | Diff-scoped; consults gate_state.json to skip already-passed checks |
| /prep | Natural language → execution contract, zero implementation | Flags hard stops at top of contract |

---

# SECTION 3 — THE AGENTIC PIPELINE

## 3.1 Workspace Scanning — Token-Efficient Navigation

The single most expensive mistake: reading entire files to find one function.
Strict scanning hierarchy, cheapest first — never use a higher tier when a lower
tier answers the question:

| Tier | Tool | Cost | Use |
|---|---|---|---|
| 1 Structural | `find src/ -name '*.py' \| sort` | 5–50 tokens | Map structure, zero content |
| 2 Location | `grep -rn 'class OrderService' src/` | 10–30/result | Pinpoint file + line |
| 3 Surgical read | `Read(file, offset=N-5, limit=40)` | 100–300 | The 40 lines around target |
| 4 Section read | `Read(file, offset=0, limit=60)` | 200–500 | Imports + signatures only |
| 5 Full file | `Read(file)` | 500–3,000 | Only when entire file is relevant |

```
# CORRECT sequence (~330 tokens total):
find src/ -name "*.py" | head -60                      # map: ~30 tokens
grep -rn "def process_payment" src/ --include="*.py"   # locate: ~15
Read(src/application/payment_service.py, offset=132, limit=35)  # ~250
grep -rn "process_payment" src/ tests/                 # impact radius

# NAIVE equivalent (reading all service files): ~8,000 tokens
# SAVING: ~96% for identical information
```

**At enormous-repo scale this is not an optimisation — it is survival.** A naive
deep-read of a 50k-file monorepo dies before producing anything.

## 3.2 The /feature Pipeline (Phases 0–5)

```
PHASE 0: PRE-FLIGHT
  git status -> clean | branch -> not protected
  test suite -> collects | build -> compiles
        |
PHASE 1: RECONNAISSANCE (zero writes)
  grep -> locate all symbols | Read(targeted)
  Output: explicit change manifest with dependency order
        |
PHASE 2: DESIGN DECLARATION (still zero writes)
  Layer assignment, typed signatures, error states, test list.
  Cannot answer something? STOP and ask. Never assume.
        |
PHASE 2.5: STUBS-FIRST SIGNATURE PROTOCOL [MANDATORY for 3+ files]
  Write ALL stubs simultaneously: real imports + typed signatures
  + empty returns. Compile-check ALL at once. All clean before
  ANY implementation. Locks contracts before logic exists.
        |
PHASE 3: IMPLEMENTATION (dependency order, bottom-up)
  After each file: compile/import check.
  >>> CHECKPOINT EVALUATION (see §4.1) <<<
        |
PHASE 4: VERIFICATION LOOP (max 3 attempts — see §3.3)
  git update-index --refresh BEFORE every diff/re-run.
  Impacted tests -> pass -> tier-2 test selection (§6) -> pass.
  >>> CHECKPOINT EVALUATION <<<
        |
PHASE 5: OUTPUT
  Change manifest | test output verbatim | Conventional Commit msg
  >>> CHECKPOINT WRITE (always, unconditional) <<<
```

### The Stubs-First Protocol — why it works

A stub file contains: all real imports, all signatures fully type-annotated, empty
typed returns, zero logic. Compile-checking all stubs simultaneously:

- Surfaces import errors at stub time, not mid-implementation
- Confirms the dependency graph is coherent before any business logic
- Prevents the hallucination loop where File A invents a signature contradicting File B
- Gives the human a reviewable interface contract before logic is written

```bash
# Compile check across ALL stubs at once:
# Python:     python -c "import all_stub_modules; print('CLEAN')"
# TypeScript: tsc --noEmit
# Go:         go build ./...
# Rust:       cargo check
# Exit code 0 required before Phase 3 begins.
```

## 3.3 Self-Correction — Root Cause, Three Strikes, Loop Invariants

**Root-Cause Reading Protocol** — on any error, answer three questions BEFORE fixing:

```
Error: ImportError: cannot import name 'PaymentService' from 'application'
  Q1: Does the symbol actually exist?       grep -rn "class PaymentService" src/
  Q2: What is the correct path?             Read the defining file's header
  Q3: Where is the bad reference?           grep -rn "from application import"
Root cause stated in ONE sentence -> minimum fix -> verify.
```

Symptom-chasing burns 5 iterations going the wrong way; root-cause-first takes one.

**Mandatory before every re-run and every git diff:**

```bash
git update-index -q --refresh; git diff --no-ext-diff
# IMPORTANT — what --refresh actually does: it reconciles STAT METADATA
# only (clears stale stat-dirty bits when content is unchanged). It does
# NOT import new content, and it cannot rescue a content change hidden
# behind an identical mtime+size (fast editor saves, container clock
# skew). For verification it must be paired with a content-level check:
# git diff --no-ext-diff re-hashes on stat mismatch. When certainty is
# required, use git status --porcelain=v2. Never treat --refresh alone
# as proof the working tree matches the index.
```

**The Three-Strike Rule:**

```
Attempt 1: refresh index, run, read FULL traceback, state root cause
           in ONE sentence, apply minimum fix, re-run.
Attempt 2: DO NOT stack a fix on a fix. Identical error? Attempt 1
           did nothing — revert it. Changed error? New root cause —
           clean fix, re-run.
Attempt 3: STOP. Output: original error verbatim, what each attempt
           changed and produced, best root-cause assessment, what a
           human needs to provide. NO fourth attempt.
```

**Loop-prevention invariants (never break):**

- Never modify a test to make it pass — modify the code under test
- Never add try/except to silence an error — fix the error
- Never add "if test mode" conditionals — that is a mask
- Same error twice across different fixes = your mental model is wrong; restart analysis
- Import errors resolve fully BEFORE running the suite

**Circular imports are structural problems** — resolution order: (1) extract shared
dependency to a third module; (2) dependency inversion via an interface;
(3) TYPE_CHECKING guard — valid ONLY for type-annotation cycles, never runtime.

---

# SECTION 4 — THE STATEFUL LAYER (checkpoints, ledger, baseline)

> This section is what makes the system viable on large existing repos. Without
> state, every gate re-pays full cost on every run, sessions die with their context,
> and pre-existing debt blocks the first commit forever. Four mechanisms fix this:
> **checkpoints** (session state survives restarts), the **gate-state ledger**
> (passed gates are never re-run on identical code), the **baseline ratchet**
> (existing debt never blocks; new debt always does), and the **enforcement layer**
> (git hooks that make all of the above mechanical rather than volunteered —
> without §4.5, everything else in this section is advisory).

## 4.1 The Checkpoint System

### 4.1.1 Purpose

Claude Code sessions lose context: compaction is lossy, restarts are total. A
checkpoint is a **state snapshot, not a conversation summary** — what exists on
disk, what was decided, what remains. A fresh session reading the latest checkpoint
resumes at full competence without re-deriving anything.

### 4.1.2 Storage

```
.claude/checkpoints/<YYYYMMDD-HHMM>-<phase>.md     one file per checkpoint
.claude/checkpoints/LATEST.md                       always overwritten with newest
```

Gitignored. Per-machine, per-engineer state.

### 4.1.3 Trigger Rules (exact — no interpretation)

Claude Code MUST evaluate checkpoint pressure at every phase boundary of /feature
(end of Phase 1, 3, 4) and after completing any /audit or /review. Pressure is HIGH
if ANY of:

```
C1. 3 or more pipeline phases completed this session
C2. 5 or more files modified this session
C3. A hard stop fired and was resolved this session
C4. A test failure was diagnosed and fixed this session
C5. The session has run more than ~2 hours
```

- If HIGH → write checkpoint BEFORE continuing, and tell the user:
  `"Context pressure high — checkpoint written to .claude/checkpoints/<file>"`
- At end of Phase 5 → write checkpoint ALWAYS, unconditionally.
- Claude Code cannot read its own token meter; C1–C5 are the proxy. When in doubt,
  write the checkpoint — a redundant checkpoint costs ~200 tokens; a lost session
  costs an hour.

### 4.1.4 Checkpoint File Schema (every field required)

```markdown
# CHECKPOINT
phase:        <recon | execute | verify | output | audit | review>
git_sha:      <git rev-parse HEAD>
branch:       <git branch --show-current>
dirty_files:  <git status --porcelain | wc -l> uncommitted
timestamp:    <YYYYMMDD-HHMM>

## TASK
<one sentence: what this session is doing and for whom>

## FILES MODIFIED THIS SESSION
- path/to/file — one-line reason

## DECISIONS LOCKED
- <decision>: <why this over the alternative>   (one line each)

## CURRENT STATE
- tests: <last run result, e.g. "144 passed">
- lint/scan: <clean | known findings vs baseline>
- build: <compiles | broken at X>

## PENDING
- <ordered list of what remains before the task is complete>

## RESUME INSTRUCTION
<one sentence: the exact next action a fresh session should take>
```

State only. Never conversation excerpts, never reasoning transcripts.

### 4.1.5 Resume Protocol (exact)

At the start of ANY session in a repo where `.claude/checkpoints/LATEST.md` exists:

```
1. Read LATEST.md (it is ~40 lines — negligible cost).
2. Run: git rev-parse HEAD  and  git status --porcelain
3. If HEAD matches checkpoint git_sha (or descends from it):
     resume from RESUME INSTRUCTION. State to the user:
     "Resuming from checkpoint <timestamp>: <task summary>".
4. If HEAD has diverged (someone else pushed, branch changed):
     state the divergence, ask whether the checkpoint is still valid.
5. If the user starts a clearly NEW task: ignore the checkpoint,
     and note that the old one will be superseded at next write.
```

### 4.1.6 Retention

Keep the 10 most recent checkpoint files; delete older ones at write time.
LATEST.md always reflects the newest.

## 4.2 The Gate-State Ledger

### 4.2.1 The problem it solves

A stateless gate re-runs the full audit + review + suite even when nothing changed
since the last pass. On a large repo that is minutes of wall-time and thousands of
tokens per push — and it trains engineers to bypass the system. The ledger gives
gates memory.

### 4.2.2 The ledger file

`.claude/gate_state.json` (gitignored — per-machine):

```json
{
  "audit":  { "fingerprint": "<hash>", "result": "pass", "new_findings": 0, "ts": "..." },
  "review": { "fingerprint": "<hash>", "result": "pass", "ts": "..." },
  "tests":  { "fingerprint": "<hash>", "result": "212 passed", "scope": "impacted",
              "suite_wall_time_s": 41, "ts": "..." },
  "last_pass_sha": "<commit sha of the last fully-passing state>"
}
```

The ledger is written by the gate script (§4.5), atomically (`write tmp + rename`),
and is the ONLY writer. Bypass records do NOT live here — they live in the
append-only bypass ledger (§4.4), because an escape-hatch log the escaping party
can edit is not an audit log.

### 4.2.3 The fingerprint

The fingerprint must capture committed state + staged changes + unstaged changes
+ **untracked files**. A fingerprint that omits untracked files is blind to a
brand-new unstaged file — a new SQL-injecting module, a new unauthenticated
route — and every gate would SKIP loudly while net-new vulnerable code ships:

```bash
fingerprint() {
  {
    git rev-parse 'HEAD^{tree}'
    git -c color.ui=false -c diff.noprefix=false -c diff.context=3 diff --no-ext-diff
    git -c color.ui=false -c diff.noprefix=false -c diff.context=3 diff --no-ext-diff --cached
    git ls-files -z --others --exclude-standard | sort -z | while IFS= read -r -d '' f; do [ -f "$f" ] && shasum "$f"; done
  } | shasum | cut -d' ' -f1
}
```

Rules:

```
F1. A receipt is valid ONLY if untracked, staged, AND unstaged state are
    all unchanged — the fingerprint above encodes all three.
F2. The diff invocations pin color/prefix/context config. git diff output
    is NOT stable across gitconfigs (mnemonicPrefix, noprefix, context,
    color); unpinned diffs make cross-machine receipts meaningless.
F3. Identical fingerprint = identical state = a passed gate is still
    valid. One changed byte, one new file = miss = the gate runs.
    Fingerprint state, never time.
F4. TWO FINGERPRINT FORMS — they govern different lifecycle moments and
    must never be conflated:
      a. WORKING-TREE fingerprint (the function above): governs ONLY the
         in-session ledger SKIP — "has anything changed since the last
         gate run in this directory?"
      b. COMMIT-TREE receipt key: when the pre-commit hook passes, it
         keys the receipt by the TREE OF THE COMMIT BEING CREATED
         (git write-tree on the index being committed). The pre-push
         hook then recomputes git rev-parse 'HEAD^{tree}' and matches
         against THAT key.
    Why the split is mandatory: the working-tree fingerprint is computed
    over dirty state; the instant the commit lands, HEAD moves, the
    staged diff empties, and the working-tree fingerprint can NEVER
    again equal the receipt pre-commit just wrote. Without form (b),
    pre-push either blocks every legitimate push or checks nothing.
```

### 4.2.4 Gate logic with ledger

```
on commit/push trigger (hook-enforced, §4.5):
  current = fingerprint()                      # working-tree form, F4a
  for each gate in [audit, review, tests]:
      if ledger[gate].fingerprint == current and result == pass:
          SKIP — and say so loudly
      else:
          if last_pass_sha is null:            # COLD START — first run
              changed = ALL tracked files + untracked files
              (audit everything once; on pass set last_pass_sha = HEAD)
          else:
              changed = git diff --name-only <last_pass_sha>..HEAD
                        + staged + unstaged + untracked files
          run gate SCOPED TO that change set
          write new receipt on pass (script writes, atomically),
          keyed per F4: working-tree fp for the session ledger,
          commit-tree hash for the pre-push receipt
```

"Diff since last pass" is computed against `last_pass_sha` (a commit ref recorded
in the ledger) — never against a fingerprint hash, which is not a git object and
cannot be diffed against. The null cold-start branch is not optional: without it,
`git diff null..HEAD` is a fatal git error and the gate crashes on the very first
commit — the init verification commit itself.

### 4.2.5 Loud skips — the adoption requirement

Silent skips breed distrust; slow re-runs breed abandonment. Every gate run ends
with a report like:

```
GATE REPORT  (emitted by the gate script — see integrity rule below)
  audit:  SKIPPED — passed at this exact fingerprint 12 min ago
  review: SKIPPED — no changes since last pass
  tests:  3 files changed -> 11 impacted tests run -> all pass
          (full suite deferred to CI)
  Total gate time: ~20s
```

**Report integrity:** the GATE REPORT is emitted by the gate script (§4.5) to
stdout — never composed by the model. A model-written "GATE REPORT" with no
underlying script run is invalid by definition; /review prints the
script-generated report verbatim and may not summarize or reconstruct it.
Engineers who can SEE why a skip was safe — and know the report cannot be
faked — keep using the system.

### 4.2.6 Cross-session trust

Receipts persist on disk and survive sessions and restarts — but trust is earned
per use: before trusting any receipt, RECOMPUTE the full fingerprint (including
untracked files) in the current session and compare. Match → trust. Mismatch →
the gate runs, no exceptions, including "it was only a comment change."

### 4.2.7 Concurrency

One session per working directory — two concurrent sessions in the same directory
will interleave ledger writes and corrupt the JSON; this is unsupported. Parallel
work belongs in separate worktrees (§8), where each worktree naturally owns its
own `.claude/gate_state.json`. All ledger writes are atomic (`write tmp + rename`).

## 4.3 The Baseline Ratchet (brownfield's centerpiece)

### 4.3.1 The problem it solves

An existing repo has debt: hundreds of linter findings, legacy patterns, files that
predate the rules. A gate demanding zero findings blocks the first commit forever →
the team disables the gate on day one. The ratchet makes the gate incremental:
**existing debt never blocks; new debt always blocks; total debt only goes down.**

### 4.3.2 The baseline file

`.claude/baseline.json` — generated once by the init prompt, COMMITTED to the repo
(the whole team shares one baseline). The schema stores **per-finding identity**,
not counts — counts cannot distinguish "moved", "masked", or "new":

```json
{
  "generated_at": "<ts>",
  "generated_from_sha": "<sha>",
  "summary": { "security_high": 3, "security_medium": 41, "lint_errors": 230,
               "type_errors": 88, "layer_violations": 54 },
  "scanners": { "security": "<tool name>", "lint": "<tool>",
                "types": "<tool>", "complexity": "NO_SCANNER" },
  "findings": {
    "src/legacy/billing.py": [
      { "rule": "B608", "line_hint": 142,
        "fp": "<hash of the finding's surrounding normalized tokens>" },
      { "rule": "E722", "line_hint": 88, "fp": "<hash>" }
    ]
  }
}
```

The `fp` (finding fingerprint) hashes the normalized code tokens surrounding the
finding — stable across line-number shifts, unique per actual defect. `line_hint`
is advisory only; identity lives in `(rule, fp)`.

**fp normalization MUST be whitespace- and format-insensitive**: normalize to a
canonical token stream (strip whitespace, comments, and line breaks) before
hashing. Otherwise a pure-formatting pass over a legacy file (reflow, import
sort) shifts the surrounding tokens of every grandfathered finding, every fp
reclassifies as NEW, and the boy-scout tidy-up the ratchet exists to enable gets
blocked by hundreds of phantom findings. Additionally: if ALL of a touched
file's findings shift fp simultaneously while rule+file+count are unchanged, the
gate treats it as a **re-fingerprint event** — re-anchor the baseline fps to the
new positions, do not block.

Every debt category with no available scanner is recorded as `"NO_SCANNER"` and
/review prints `UNPROTECTED: <category>` on every run — a silently absent scanner
must never read as "clean."

### 4.3.3 Ratchet rules (exact)

```
R1. IDENTITY, NOT COUNTS. The gate keys every current finding by
    (rule, fp) and looks it up in the baseline:
      - present in baseline  -> grandfathered, never blocks
      - absent from baseline -> NEW, always blocks
    A new finding can NEVER be offset by an incidental fix elsewhere:
    deleting one old defect while introducing one new one is a BLOCK,
    even though the count is unchanged. Count-equality masks exactly
    this swap; identity comparison does not.
R2. RATCHET-DOWN. When a baseline finding's (rule, fp) is no longer
    present, the gate script removes that entry from baseline.json and
    commits it with the task — and records the removed fingerprints in
    the audit receipt. /review verifies every baseline decrease against
    that receipt: a downward delta is legal ONLY if the audit run
    recorded those same fingerprints as removed.
R3. The baseline NEVER increases. There is no mechanism to add debt.
    New debt is fixed before merge, full stop.
R4. Any baseline.json change WITHOUT a matching audit receipt is a
    HARD STOP — this is how the gate distinguishes its own legal
    ratchet-down writes (R2) from human or model tampering. Baseline
    increases are never legal regardless of receipts.
R5. A finding moving from file A to file B keeps its rule but gets a
    new fp context in B -> it is NEW debt in B and blocks. The per-
    finding schema is what makes this enforceable; per-file counts
    could not distinguish "moved" from "fixed plus added".
```

### 4.3.3a Diff-scoping a file-level scanner (the hunk-intersection rule)

Most scanners (bandit, eslint) report on whole files — they cannot be pointed at
changed lines. Running them on a touched legacy god-file re-surfaces every
grandfathered finding as noise. The gate therefore intersects:

```
1. Run the scanner on the FULL changed file (the only mode it has).
2. Compute touched line ranges: git diff -U0 <last_pass_sha> -- <file>
   (zero-context hunks give exact changed ranges).
3. For each finding:
     inside a touched hunk  -> evaluate ALWAYS (R1 identity check —
                               new fp blocks, grandfathered fp passes)
     outside touched hunks  -> check against baseline only; block only
                               if this edit INCREASED findings there
                               (which only happens via R5-style moves)
4. The report lists suppressed out-of-hunk grandfathered findings as a
   one-line count, not as noise: "(14 baseline findings outside touched
   hunks — unchanged)".
```

This is the mechanism behind "touched-files-only" (§2.2.1) — without the hunk
intersection, the policy is unimplementable for file-level scanners.

### 4.3.4 The payoff curve

Week 1: gates pass despite 1,600 findings — nothing blocks, team onboards smoothly.
Month 3: every touched file got slightly cleaner; baseline has ratcheted down ~20%.
Month 12: debt is a fraction of the start, and it was paid for by the boy-scout rule —
nobody ever did a "big cleanup sprint."

## 4.4 The Kill Switch

Emergencies are real. If the gate cannot be bypassed when production is down, the
team will uninstall the system the first time it is on fire. The bypass exists,
is loud, and is audited — and critically, **it is enforced by the hook layer
(§4.5), not by model goodwill**:

```bash
SKIP_GATE=1 git commit -m "hotfix(...): <msg>"
```

Rules:

```
K1. LAYERED, WITH HONEST GUARANTEES. "Claude never invokes SKIP_GATE" is
    policy, not a control — a model in a failure loop (or prompt-injected)
    can emit that exact string. The mechanical layers, strongest first:
      a. PRIMARY — settings.json denies "Bash(SKIP_GATE=*)". This is the
         un-spoofable layer: the agent cannot form the command at all.
         CAVEAT: verify your client's matcher actually catches env-prefixed
         commands (some tokenizers only match when the program itself is
         the pattern). If unverified, enforce in the hook instead: the
         pre-commit hook refuses SKIP_GATE when agent-environment markers
         are present (e.g. $CLAUDECODE set, or no interactive terminal).
      b. SECONDARY — the pre-commit hook, on seeing SKIP_GATE set, demands
         confirmation via read -p from /dev/tty. This assumes an agent
         WITHOUT an interactive terminal; an interactive CLI session DOES
         have a controlling TTY, so this is a human-presence backstop,
         not a categorical guarantee. Never describe it as "physically
         impossible" — the deny rule is the hard layer, this is defense
         in depth.
      c. The typed confirmation must include a reason string; empty = abort.
    The documented human path: run the bypass in a PLAIN shell, not
    through the agent — then no matcher semantics are in play at all.
K2. APPEND-ONLY, SHARED AUDIT TRAIL. The hook (never the model, never a
    hand edit) records each bypass as a git note on the bypassed commit
    (git notes --ref=bypasses add). gate_state.json is NOT the bypass
    log — gitignored mutable per-machine JSON is not an audit trail.
    PROPAGATION IS NOT AUTOMATIC: git does not push refs/notes/* by
    default. The init (§4.5.1) MUST configure:
      git config --add remote.origin.push  'refs/notes/bypasses:refs/notes/bypasses'
      git config --add remote.origin.fetch '+refs/notes/bypasses:refs/notes/bypasses'
    and CI must git fetch origin 'refs/notes/*:refs/notes/*' before its
    deadline check. Without these, the note stays on the laptop and the
    "visible to every clone and CI" guarantee is false.
K3. The next /review reports all bypass notes since the last clean pass
    and re-runs the skipped gates against the bypassed commits.
K4. 24-HOUR CLOCK ON GIT TIME. The pre-push hook compares each bypassed
    commit's COMMITTER DATE (git-authoritative metadata) against now;
    any bypass older than 24h without a matching clean re-run receipt
    blocks the push. The comparison never uses self-reported ledger
    timestamps — that would re-import the clock-drift failure mode the
    fingerprint design exists to avoid.
```

## 4.5 The Enforcement Layer (git hooks) — what makes everything above real

> Without this section, every "blocks", "auto-triggered", and "HARD STOP" in
> this standard is a behavior the model is asked to volunteer each session — a
> forgetful or jailbroken session bypasses everything silently. The hooks make
> the gate mechanical: it runs because git runs it, not because the model
> chose to.

**Honest scope statement:** local hooks are evadable by a determined actor
(`git commit --no-verify`, `git -c core.hooksPath=/dev/null`). The deny list
(§2.3) blocks the model from forming the common evasions; the CI run of the same
gate script is the authoritative layer that catches everything else. Never
describe local hooks as un-bypassable — describe them as the fast layer that
makes the honest path the easy path.

### 4.5.1 Installation (generated at init, committed)

```
.githooks/
  gate.sh         <- the shared gate script (hooks and CI both call it)
  pre-commit      <- fingerprint -> scoped gate -> ledger receipt
  pre-push        <- receipt validation + bypass-deadline check + force guard

Per-clone activation (wrapped as cc-init-hooks in .team_aliases):
  git config core.hooksPath .githooks
  git config --add remote.origin.push  'refs/notes/bypasses:refs/notes/bypasses'
  git config --add remote.origin.fetch '+refs/notes/bypasses:refs/notes/bypasses'
```

Committed to the repo: the hooks ARE the gate. The notes refspecs are not
optional — without them, bypass notes never leave the laptop (K2).

### 4.5.2 pre-commit responsibilities

```
1. If SKIP_GATE is set: apply K1 (deny-first, TTY backstop, reason
   required); on success write the bypass git note (K2) and exit 0.
2. SCAN THE COMMIT TREE, NOT THE WORKING TREE: build the exact tree
   being committed via git write-tree on the index (use a temp index
   for safety). With git commit -a or git add -p partial staging, the
   index differs from the working tree — scanning the working tree
   both blocks findings that aren't being committed and misses hunks
   that are. The working-tree fingerprint (F4a) governs only the
   session-ledger SKIP; the scan target here is the index tree.
   The git commit -a, -am, and --amend flags are strictly blocked via
   hard settings permissions to guarantee that the index tree perfectly
   equals the commit tree at hook time.
3. Receipt valid for this tree? -> emit GATE REPORT (skips), exit 0.
4. Else: run the scoped gate — change set per §4.2.4 (including the
   null cold-start branch), audit with hunk intersection (§4.3.3a) +
   identity ratchet (§4.3.3) + tier-2 tests (algorithm below) — emit
   the GATE REPORT, write receipts atomically (working-tree fp for
   the session ledger, write-tree hash for the pre-push key, per F4),
   exit nonzero on any block.

TIER-2 SELECTION ALGORITHM (gate.sh must implement exactly this):
  a. If test-impact tooling is installed (required at init for any
     repo with >~200 tests — see §6 T3): query it with the change
     set; run the returned set.
  b. If tooling is absent (small repos only): run the naming-contract-
     mapped tests of every changed file PLUS the entire test set of
     every module that depends on any changed CORE_FILES entry
     (transitive, from the init-built import graph) — and label the
     report "TIER 2 (degraded: tooling absent)". grep alone is never
     the selector (§6 T5).

LINTER (hard gate — runs after security scan):
  Run LINT_CMD (recorded in gate_state.json at init) scoped to changed
  files where the tool supports it. Non-zero exit blocks the commit.
  Absence must be explicit: record NO_LINTER in the gate report.

TYPE CHECKER (hard gate — runs after linter):
  Run TYPECHECK_CMD (recorded in gate_state.json at init) on the full
  project. Non-zero exit blocks the commit. Record NO_TYPECHECKER if
  absent.

COVERAGE GATE (hard gate — runs after test execution):
  Assert line coverage ≥ COVERAGE_THRESHOLD (default 80%, stored in
  gate_state.json). Block the commit if coverage drops below threshold.
  The threshold is human-editable via PR only — agents cannot lower it.

COMPLEXITY GATE (performance proxy — runs on changed files only):
  Run the stack's complexity scanner (radon cc -n C for Python,
  eslint with complexity rule for JS/TS, gocyclo for Go). Block the
  commit if any function exceeds COMPLEXITY_THRESHOLD (default
  cyclomatic complexity 10, stored in gate_state.json). High complexity
  is the leading structural indicator of performance regression.
```

### 4.5.3 pre-push responsibilities

```
1. Refuse pushes to main/master/develop outright.
2. Refuse any refspec beginning with '+' (force syntax that no
   settings pattern can catch — §2.3 P3).
3. Recompute git rev-parse 'HEAD^{tree}' and require a passing receipt
   keyed by that commit-tree hash (F4b); none -> block with "gate has
   not passed for this exact state". Never match against the working-
   tree fingerprint — it cannot equal a post-commit state (F4).
4. Refuse any refspec containing a deletion semicolon targeting the
   bypass trail (echo "$@" | grep -qE ":refs/notes/bypasses" must
   return exit code 1) — git notes are not inherently append-only;
   git push origin :refs/notes/bypasses would erase the audit trail.
5. Enforce the bypass 24h deadline (K4) — after fetching
   refs/notes/bypasses so remote bypasses are visible.
```

### 4.5.4 Division of labor — hooks vs. model

```
HOOKS (mechanical, cannot be forgotten):   fingerprint, receipts,
  ratchet arithmetic, hunk intersection, tier execution, bypass
  control, force-push refusal, deadline math, GATE REPORT emission.
MODEL (judgment, cannot be mechanized):    root-causing a finding,
  writing the fix, deciding severity context, drafting the PR body,
  the Gate Step 4 push conversation.
The model orchestrates and explains; the hooks enforce and record.
A model that skips its part produces worse UX; it cannot produce a
bypassed gate.
```

CI runs the same gate script as the hooks (same fingerprint, same ratchet) so a
hook-stripped clone still cannot merge unverified code — hooks are the fast local
layer, CI is the authoritative one.

---

# SECTION 5 — CODE QUALITY GUARDRAILS

## 5.1 Atomic Commit Discipline

An atomic commit: exactly one logical change; the suite passes at that commit in
isolation; reviewable in under 5 minutes; the message alone explains WHY.

```
FORMAT:  type(scope): imperative description
TYPES:   feat | fix | refactor | test | perf | security | docs | chore

ACCEPTABLE:
  fix(cache):     close stampede gap by swapping event.set() and map.delete()
  security(auth): route infrastructure probes to hardened prompt path
NOT ACCEPTABLE:
  "fix stuff" | "updates" | "WIP" | "changes"
```

**The anti-blob pattern** — one feature = layered commits, each independently
reviewable and bisectable:

```
commit 1: feat(domain): add Payment entity + repository interface
commit 2: feat(infra):  implement StripePaymentRepository
commit 3: feat(app):    add ProcessPaymentUseCase with retry logic
commit 4: feat(api):    add POST /payments endpoint
commit 5: test(payment): unit + integration coverage
```

## 5.2 Auditable Diffs

At every non-obvious decision, one comment explaining WHY (a message to the
reviewer, not documentation):

```python
# Exponential backoff: provider returns 429 on burst — linear retry
# would saturate the limit
```

Test names are specification sentences:

```
test_process_payment_retries_on_rate_limit_up_to_three_times()
test_process_payment_is_idempotent_with_same_idempotency_key()
```

## 5.3 The Commit/Push Gate (hook-enforced, ledger-aware)

The gate runs at TWO layers. The model layer triggers when the user says "commit",
"push", "PR", "ship", "merge" — it orchestrates, explains, and fixes. The hook
layer (§4.5) runs on every `git commit` and `git push` regardless of what the
model does — it is the enforcement. A session that never reads CLAUDE.md still
cannot land an ungated commit. With the ledger (§4.2), repeat runs on unchanged
code skip in seconds.

```
GATE STEP 1 — /audit (diff-scoped, baseline-aware)
  Ledger hit at current fingerprint -> SKIP loudly (script-emitted).
  Else: audit files changed since last_pass_sha, hunk-intersected
  (§4.3.3a), identity-checked against baseline (§4.3.3 R1).
  NEW findings: CRITICAL/HIGH -> BLOCK, await human.
  MEDIUM/LOW new findings -> auto-remediate, re-verify.

GATE STEP 2 — /review (diff-scoped, ledger-aware)
  Ledger hit -> SKIP loudly.
  Else: layer compliance + secrets-in-diff + test coverage +
  lockfile assertion — on changed files only.
  LOCKFILE RULE: any lockfile diff without an approved dependency
  addition = HARD STOP. Hidden transitive deps bypass review.

GATE STEP 3 — git (only if 1 and 2 pass clean)
  git update-index -q --refresh; git diff --no-ext-diff   (§3.3 semantics)
  git add <specific files — NEVER git add -A>
  Conventional Commit message. The pre-commit hook re-verifies
  mechanically — a model that skipped steps 1-2 gets blocked here.

GATE STEP 4 — PUSH CONFIRMATION (mandatory, no exceptions)
  State in chat: exact branch and remote.
  Wait for explicit human approval IN THIS CONVERSATION.
  A prior "push" in the same message does NOT count.
  No reply = no push. Ever.
  The pre-push hook independently refuses protected branches,
  +refspec force syntax, missing receipts, and expired bypasses.
```

## 5.4 Pre-PR Manual Gates

```bash
git update-index --refresh                       # always first
<test-runner per §6 tiers>                       # green required
git diff main...HEAD | grep -iE "password|secret|api_key|token"   # zero matches
git diff main...HEAD --name-only                 # every file explainable
<linter> && <type-checker>                       # no NEW errors vs baseline
```

---

# SECTION 6 — TESTING AT SCALE (3-Tier Selection)

> A 10,000-test suite cannot run on every commit. Running it anyway produces
> 30-minute gates, and 30-minute gates produce engineers who stop committing.
> Test selection is tiered by scope; the full suite belongs to CI.

```
TIER 1 — per-file (during /feature Phase 3, after each file):
  Run ONLY the test file(s) mapped to the modified module.
  Mapping source, in order of preference:
    a. Naming contract (tests/<layer>/test_<module>) if the repo has one
    b. Test-impact tooling (pytest-testmon, jest --changedSince,
       go test ./changed/..., bazel rdeps queries)
    c. Import-graph reverse lookup (grep) — a LOWER BOUND only, see T5
  Typical cost: seconds.

TIER 2 — impacted set (gate, pre-commit):
  Tests for all changed files PLUS reverse dependencies:
    - LEAF modules (imported by few others): one level of reverse deps
      is permitted.
    - CORE_FILES (see below): transitive closure to a FIXED POINT.
      One level is NOT enough for shared code: a regression in
      util/money.py breaks services/billing.py whose tests sit TWO
      import hops away — one-level selection misses them and the
      break leaks to staging.
  Typical cost: tens of seconds on a large repo.

TIER 3 — full suite:
  Runs ONLY when: a CORE_FILES match changed, OR before PR creation,
  OR explicitly requested. PREFER running tier 3 in CI, not locally.
```

**CORE_FILES — the explicit list that makes tier 3 deterministic.** "A shared/core
file changed" is a judgment the agent cannot be trusted to make per-session.
CLAUDE.md MUST contain an explicit `CORE_FILES` glob list — the ONLY trigger for
mandatory tier 3. The init populates it mechanically from the dependency graph
(any module imported by more than N≈5 other modules is core, plus config, base
models, DI wiring, conftest/fixtures). The list grows as the dependency graph
grows, but it is updated via a human engineering pass — editing CORE_FILES is a
hard stop (§2.2.3) and changes only via human-authored PR, never agent edit.

Rules:

```
T1. The gate report ALWAYS states which tier ran and why
    ("3 files changed -> tier 2 -> 41 tests"). Silent scoping reads
    as full coverage when it isn't — that's how trust dies.
T2. A tier-1/2 pass plus a ledger receipt is sufficient for commit.
    PR merge requires a tier-3 pass (CI).
T3. Test-impact tooling is installed AT INIT for any repo with more
    than ~200 tests — never deferred to "when the suite gets slow".
    Deferring creates a window where the suite carries real risk,
    tooling is absent, and grep is admittedly insufficient (T5): the
    gate would have no reliable tier-2 selector exactly when it
    matters. (Tooling additions are a dependency hard stop — the init
    discovery report requests approval explicitly.) The degraded
    fallback in §4.5.2 exists only for genuinely small repos.
T4. Flaky tests are quarantined in a COMMITTED quarantine.txt with a
    linked issue — never deleted, never retried-until-green inside
    the gate. /review prints the quarantine count and the modules it
    covers on every run ("QUARANTINED: 3 tests covering money.py,
    auth.py"). A quarantined test covering a CORE_FILES module is a
    HARD STOP, not a deferral — that is the one test that would catch
    a core regression.
T5. grep-based import scanning is semantically blind to re-exports
    (from .util import *), dynamic imports (importlib), DI/fixture
    injection (the dependency arrives via conftest, not an import),
    and string-referenced plugins. It is a LOWER BOUND on impact,
    never the full set. When a changed file is consumed through any
    of these mechanisms, tier 2 is insufficient -> escalate to tier 3.
T6. TIER-TRANSITION ENFORCEMENT: the gate script records full-suite
    wall time in gate_state.json on every tier-3 run. When it exceeds
    the threshold (default 60s) twice consecutively, the script emits
    TIER TRANSITION REQUIRED and refuses to default to full-suite
    locally. The trigger lives in the ledger, not in anyone's memory —
    a suite that crosses the line in month 4 is caught in month 4.
T7. IMPORT-GRAPH FRESHNESS: gate.sh must dynamically rebuild the import
    graph whenever an import statement or a CORE_FILES entry appears in
    the change set, or via a scheduled CI pipeline run — a graph built
    once at init decays as the repo grows. The degraded tier-2 path is a
    short-lived bridge to real tooling, never a permanent state.
```

---

# SECTION 7 — SESSION & CONTEXT MANAGEMENT

## 7.1 What Fills the Window

```
Fixed overhead:        CLAUDE.md (~1.5–3k) + system config        ~2–4k tokens
Active task content:   contract + 3–5 files + test output         ~6–20k
History (danger zone): grows ~3–8k per task iteration
After 15 iterations:                                              ~53–144k
```

Near the limit, quality degrades non-linearly. Older content gets less attention —
Claude becomes less accurate about decisions made early in the session.

### 7.1.1 Cost-Warning Firing

COST-WARNING FIRING: The agent must track active context limits via token
approximations based on round-trip turns. If a single task iteration or
pipeline phase consumes more than 40,000 context tokens, or if history
retransmission waste crosses a 50% threshold, the agent must output a
high-visibility cost warning alert to the terminal: "WARNING: Context
pressure exceeding efficiency thresholds (~[Count] tokens used). /compact
or restart recommended to prevent token inflation."

## 7.2 Compact vs. Restart Decision Tree

```
AFTER EVERY COMPLETED TASK:
  >3 major iterations this session?          -> /compact
  >10 distinct files read?                   -> /compact
  Next task unrelated to current work?       -> FULL RESTART
  All no                                     -> continue

/compact:      same task, mid-implementation, 40–60% context used
FULL RESTART:  different feature/domain, >70% used, degraded output
               despite compact, 2+ hour session, post-merge on fresh main
```

**The checkpoint system (§4.1) supersedes the old manual summary ritual.** Before
any compact or restart: ensure a checkpoint is current (write one if not). After
restart: the resume protocol (§4.1.5) re-anchors automatically — CLAUDE.md reloads
free, LATEST.md restores task state for ~200 tokens.

What full restart clears that /compact does not: terminal buffers, tool trace
objects, file-read caches, confusion from contradictory early instructions.

## 7.3 Context Budget Per Task Tier

| Tier | Description | Expected Context | Session Guidance |
|---|---|---|---|
| Micro | Single function fix, rename, doc | <5k | Several per session |
| Small | One endpoint / one method + tests | 5–15k | One per session ideal |
| Medium | Full feature across layers | 15–40k | One per session; /compact if needed |
| Large | Multi-entity feature, service refactor | 40–80k | Split across 2 sessions by layer |
| XL | Cross-service / architectural change | 80k+ | Decompose; one session per sub-task |

## 7.4 XL Decomposition Pattern

Decompose by layer; each sub-task gets its own session, its own checkpoint, and
its own atomic commit. Git history connects sessions; CLAUDE.md governs all:

```
Session 1 — Domain:    "Implement X value objects. Domain tests pass."
Session 2 — Infra:     "Implement X repository. Integration tests pass."
Session 3 — App:       "Update use cases. Application tests pass."
Session 4 — API:       "Update handlers/middleware. Handler tests pass."
Session 5 — E2E:       "Full suite (CI). Zero regressions."
```

## 7.5 Rate-Limit Recovery

```
On HTTP 429 from any tool:
  1. DO NOT retry in a loop.
  2. Write a checkpoint (§4.1) — this replaces the ad-hoc
     "RATE_LIMIT_CHECKPOINT" printout.
  3. git stash OR wip commit.
  4. Stop. Await human instruction.
```

---

# SECTION 8 — WORKTREE ISOLATION (parallel agentic sessions)

Concurrent agentic test loops sharing local resources contaminate each other's
state. The failures look like flaky tests; they are cross-session pollution.

**Banned in parallel worktrees:** shared local DB port, shared cache instance
(e.g. Redis db 0 on 6379 for everyone), shared queues, shared app ports, shared
test schemas, shared third-party sandbox keys or mock tenants.

**Mandatory: each worktree carries `.env.worktree` (gitignored):**

```
# ../project-auth/.env.worktree      (Engineer A)
APP_PORT=8081
TEST_DB_SCHEMA=test_auth_lakshya
CACHE_DB=1
QUEUE_NAMESPACE=wt_auth
STRIPE_TEST_KEY=sk_test_wt_auth_xxx

# ../project-payment/.env.worktree   (Engineer B)
APP_PORT=8082
TEST_DB_SCHEMA=test_payment_priya
CACHE_DB=2
QUEUE_NAMESPACE=wt_payment
STRIPE_TEST_KEY=sk_test_wt_payment_xxx
```

Port standard: 8080 = main, never for parallel work; worktree slots 8081/8082/8083.
Per-worktree DB schema created before the loop, dropped after merge. Sandbox keys
are distinct per worktree and treated as production secrets — never committed,
sourced from .env.worktree only.

A human adds the following to CLAUDE.md via PR (agents cannot edit the
constitution — §2.2.4):

```
## WORKTREE ENVIRONMENT
If .env.worktree exists in project root: source it before every test
run. Never assume default ports or schema names. Always use
${APP_PORT}, ${TEST_DB_SCHEMA}, ${*_TEST_KEY} from .env.worktree.
```

Coordination rules: no two engineers own the same module in the same sprint; the
execution-contract scope list is the unit of coordination — share scopes before
starting. Note: `.claude/gate_state.json` and `.claude/checkpoints/` are naturally
per-worktree (each worktree has its own working directory) — no extra isolation
needed for the stateful layer.

---

# SECTION 9 — PERFORMANCE RUBRIC

| Signal | Beginner | Intermediate | Expert |
|---|---|---|---|
| Prompt structure | "add auth to the api" | Objective + constraints | Full execution contract with verify step |
| Context per task | Fills window | /compact sometimes | Surgical — <30% of window per tier |
| Session hygiene | One long session | /compact after big tasks | Restart between features; checkpoint before every reset |
| Files read | Whatever seems relevant | Targeted, some over-reading | grep first, surgical Read offset+limit |
| Stubs-first | Sequential files, mid-run import errors | Import check per file | All stubs compiled clean before any implementation |
| Self-correction | Accepts first output | Pushes back sometimes | 3-strike rule; root cause before first fix |
| Layer compliance | Code lands anywhere | Mostly correct | Zero violations on touched files |
| Test discipline | After the feature, maybe | With the feature | Declared in design phase; tiered selection (§6) |
| Commit quality | "fix stuff", batched | Format ok, some batching | Atomic, bisectable, why-explaining, one layer per commit |
| Gate awareness | Re-runs everything always | Skips manually (risky) | Ledger receipts; loud skips; baseline ratchet trusted |
| State management | Loses work on restart | Manual summaries | Checkpoint at phase boundaries; instant resume |
| Worktree isolation | Single dir for all work | Worktrees, shared DB/port | .env.worktree, isolated everything |

---

# SECTION 10 — QUICK REFERENCE FIELD CARD

```
+--------------------------------------+--------------------------------------+
| SESSION START                        | EXECUTION CONTRACT                   |
|  [] Feature branch, clean status     |  Scope / Objective / Constraints     |
|  [] checkpoints/LATEST.md? -> resume |  Verify / Output                     |
|  [] Test suite collects              |                                      |
+--------------------------------------+--------------------------------------+
| SCANNING ORDER                       | WRITE ORDER                          |
|  1. grep/find        (~30 tok)       |  Domain -> Infra -> App ->           |
|  2. Read(offset,limit)(~250)         |  Presentation -> Tests               |
|  3. Full read        (~2000, rare)   |  (or repo's real layer order)        |
+--------------------------------------+--------------------------------------+
| STUBS-FIRST (3+ files)               | SELF-CORRECTION                      |
|  ALL stubs -> compile ALL -> impl    |  Full traceback, root cause 1 line   |
|                                      |  Min fix. 3 strikes -> STOP          |
+--------------------------------------+--------------------------------------+
| STATEFUL LAYER                       | TEST TIERS                           |
|  Checkpoint: phase end if C1-C5      |  1: mapped module tests (per file)   |
|  Ledger: skip on identical           |  2: impacted; CORE_FILES -> closure  |
|  fingerprint (incl. untracked!)      |  3: full suite (CI / pre-PR / CORE)  |
|  Baseline: NEW identity blocks,      |  grep = lower bound, never a tier    |
|  grandfathered never; only shrinks   |  quarantine.txt committed + loud     |
+--------------------------------------+--------------------------------------+
| SESSION HYGIENE                      | HARD STOPS                           |
|  /compact: same task, 40-60% full    |  New dep / lockfile | schema change  |
|  Restart: new feature, >70%, 2h+     |  auth | env var | infra | CI/CD      |
|  Checkpoint BEFORE either            |  .gitignore | baseline | CORE_FILES  |
|                                      |  settings/permission-mode change     |
+--------------------------------------+--------------------------------------+
| GATE (hook-enforced, §4.5)           | KILL SWITCH                          |
|  pre-commit: fingerprint -> scoped   |  SKIP_GATE=1: settings deny is the   |
|  gate -> receipt. pre-push: receipt  |  hard layer; TTY adds human-         |
|  + force guard + bypass deadline.    |  presence assurance. Bypass = git    |
|  Model orchestrates; hooks enforce.  |  note on commit. Re-run 24h          |
|  ASK in chat before every push.      |  (committer date) or push blocks.    |
+--------------------------------------+--------------------------------------+
| QUALITY AXIOM: output ceiling = prompt floor                                |
+-----------------------------------------------------------------------------+
```

---

# SECTION A — ONBOARDING PATH (30 days)

| Timeframe | Action | Success Signal |
|---|---|---|
| Day 1 AM | Install CLI: `npm install -g @anthropic-ai/claude-code` | `claude --version` works |
| Day 1 PM | Read this guide end-to-end, no action | You can explain ledger + baseline + checkpoint in 3 sentences |
| Day 2 | Run the Implementation Package init on your repo; review the discovery report CAREFULLY before confirming | Constitution matches your repo's real architecture; baseline.json committed |
| Day 3–4 | First task via /feature on a small ticket; /review before PR | Diff shows only in-scope files; gate report shows tiered tests |
| Week 1 | 3 features via execution contracts; watch the gate skip on unchanged code | Zero NEW findings vs baseline; you trust the loud skips |
| Week 2 | Stubs-first on a multi-file task; practice checkpoint-resume (kill a session mid-task deliberately, resume) | Resume takes <1 min, nothing re-derived |
| Week 3 | Parallel worktrees with .env.worktree; mentor a colleague | No cross-session contamination; colleague's first clean /review |
| Month 1 | Propose a CLAUDE.md improvement via human PR; measure your baseline delta | Baseline ratcheted down; 40–60% completion-time reduction |

---

*This document is a living standard. The methodology is durable: scope clearly,
execute contractually, stub-first multi-file work, self-correct with discipline,
checkpoint state, fingerprint gates, ratchet debt downward, isolate concurrent
agents, verify in tiers, and commit atomically. Engineers who master this do not
just use AI faster — they operate at a quality ceiling manual development cannot
match at any speed.*
