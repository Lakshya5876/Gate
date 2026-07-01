# ultimate_harness.md
## Complete Engineering Curriculum: ai-dev-workflow
### From Absolute Zero to the Level of the Engineer Who Built It

---

**How to use this document.**  
Read every section in order. Do not skip. Each module assumes the previous ones.  
Every code block is real — taken verbatim from the project at commit `a7d3c04` (HEAD), incorporating all patches from `630d3ad` (process-tree detection + graph kill-restart lifecycle).  
When the text says "type this and observe the output" — type it and observe.  
When the text says "explain this without looking" — close the document and explain it.  
The understanding this document builds is permanent precisely because it goes from first principles every time.

---

## TABLE OF CONTENTS

- [Module 0 — Unix/Shell Fundamentals](#module-0)
- [Module 1 — Git Internals: What Hooks Actually Are](#module-1)
- [Module 2 — The Problem This Project Exists to Solve](#module-2)
- [Module 3 — Architecture Overview](#module-3)
- [Module 4 — gate.sh: The Core Engine](#module-4)
- [Module 5 — gate_state.json: The State Machine](#module-5)
- [Module 6 — install.sh: The Bootstrap Engine](#module-6)
- [Module 7 — The Claude Code Hook Layer](#module-7)
- [Module 8 — The Receipt System](#module-8)
- [Module 9 — The Bypass System](#module-9)
- [Module 10 — Testing with bats](#module-10)
- [Module 11 — The v1 Release Packages](#module-11)
- [Module 12 — Security Posture](#module-12)
- [Module 13 — Design Challenge Mode](#module-13)

---

<a name="module-0"></a>
# MODULE 0 — Unix/Shell Fundamentals

**Prerequisite knowledge:** None. This module assumes you are starting from zero.  
**Time investment:** 4–6 hours of active reading + exercises.  
**Why this module first:** Every mechanism in gate.sh — exit codes, pipes, ERR traps, timeout, process tree traversal — is a direct application of what this module teaches. Without understanding these primitives, gate.sh is a magic spell. With them, it is a logical consequence.

---

## 0.1 The Unix Process Model — What Really Happens When a Command Runs

### What is a process?

A **process** is a running program. It is a program loaded into memory by the operating system, given a unique identifier (a **PID** — process ID), and scheduled to run on a CPU.

When you type `ls` in a terminal, three things happen:
1. The shell creates a copy of itself (a child process) — this is called `fork()`
2. The child process replaces its running code with the code for `ls` — this is called `exec()`
3. The shell waits for the child to finish, reads its exit code, and prompts you again

This fork-then-exec pattern is the foundation of how Unix works. Every command you run — `ls`, `grep`, `git`, `python3` — is the result of your shell doing fork() + exec().

### The process tree

Every process (except PID 1, the init process) has a parent. The relationship is hierarchical:

```
PID 1 (init/launchd/systemd)
└── Terminal app (PID 1234)
    └── bash/zsh shell (PID 5678)
        └── git commit (PID 9012)
            └── pre-commit hook / gate.sh (PID 9013)
                └── python3 (PID 9014)
```

Each process knows its own PID (`$$` in bash) and its parent's PID (`$PPID`).

This tree structure is how gate.sh determines whether a commit comes from a Claude Code agent or a human. It traverses the tree from the hook's own PPID upward to PID 1, checking each ancestor's command name.

```bash
# You can see this yourself:
echo "My PID is $$"
echo "My parent's PID is $PPID"
ps -p $PPID -o command=    # What is my parent process?
```

### Inherited attributes

When a child process is created with fork(), it inherits three things from its parent:

1. **Environment variables** — a copy of the parent's key=value store. Changes in the child do NOT affect the parent.
2. **Working directory** — the current directory. Changes in the child (`cd`) do NOT affect the parent (this is why `cd foo` in a script doesn't change your terminal's directory).
3. **File descriptor table** — the open files (stdin, stdout, stderr — more on these in 0.4).

These are copies, not references. The parent and child are independent after fork().

### Why this matters for gate.sh

gate.sh runs as a subprocess of git, which runs as a subprocess of your shell, which runs as a subprocess of Claude Code (if you're using it). The process lineage is:

```
Claude Code CLI process
    └── git commit
        └── .githooks/pre-commit
            └── gate.sh (inherits all env vars from above)
```

gate.sh uses this to detect if it was launched from a Claude Code session:

```bash
# From gate.sh lines 179-195: _is_claude_agent_process()
_is_claude_agent_process() {
    IS_AGENT=false
    CURRENT_PID=$PPID
    while [ "${CURRENT_PID:-0}" -gt 1 ] 2>/dev/null; do
        _AP_CMD=$(ps -p "$CURRENT_PID" -o command= 2>/dev/null | tr -d '\n' || echo "")
        if echo "$_AP_CMD" | grep -qE '@anthropic-ai/claude-code|claude-code'; then
            IS_AGENT=true
            break
        fi
        _AP_PPID=$(ps -p "$CURRENT_PID" -o ppid= 2>/dev/null | tr -d ' \n' || echo "0")
        [ -z "$_AP_PPID" ] || [ "$_AP_PPID" = "0" ] && break
        CURRENT_PID=$_AP_PPID
    done
}
```

This function starts at `$PPID` (gate.sh's parent, which is git) and climbs the tree one level at a time, asking `ps` for each ancestor's command name, until it either finds `claude-code` in the ancestry or reaches PID 1. This cannot be fooled by subprocess nesting: no matter how many shell layers Claude Code spawns, the function climbs to the root of the session.

**Exercise 0.1:** Open a terminal. Run `echo $$`. Then run `bash -c 'echo "My parent PID is $PPID"`. Is the output what you expected? Run `ps -p $$` to confirm. Now run `bash -c 'ps -p $PPID -o command='` — what do you see?

---

## 0.2 Bash Scripting Fundamentals — Scripts as Programs, Not Macros

### What a script actually is

A shell script is a text file that the shell reads and interprets line by line. It is not a macro, not a template, not a configuration file. It is a **program** that runs as a process.

```bash
#!/usr/bin/env bash     # Line 1: the shebang
echo "Hello, world"    # Line 2: a command
```

Line 1 is the **shebang** (also called a hashbang). When you run `./myscript.sh`, the kernel reads the first two bytes of the file. If they are `#!`, the kernel uses the rest of that line as the interpreter path and launches it with the script as an argument. So `#!/usr/bin/env bash` means: "run `/usr/bin/env bash`, passing this script as the argument."

Why `env bash` instead of `/bin/bash`? Because the location of bash varies across systems (macOS: `/bin/bash` or `/opt/homebrew/bin/bash`; Linux: `/bin/bash`; Alpine Linux: `/bin/bash` may not exist at all). `env` searches `$PATH` for `bash`, which always finds the right one.

### Running a script

```bash
chmod +x myscript.sh   # Make it executable
./myscript.sh          # Run it as a child process (fork + exec)
source myscript.sh     # Run it in the CURRENT shell (no fork — shares state)
bash myscript.sh       # Run it explicitly with bash (no chmod needed)
```

The crucial difference: `./myscript.sh` runs in a subshell. `source myscript.sh` runs in your current shell. For git hooks, git uses `exec` — the hook replaces the current process entirely without forking.

### Variable assignment

```bash
# Assignment: NO SPACES around =
NAME="Alice"          # CORRECT
NAME = "Alice"        # WRONG — bash thinks NAME is a command with arguments "=" and "Alice"

# Reading a variable
echo $NAME            # Alice
echo "$NAME"          # Alice (always quote!)
echo "${NAME}"        # Alice (explicit braces — use in ambiguous contexts)

# Variable in a string
echo "Hello, $NAME"   # Hello, Alice
echo 'Hello, $NAME'   # Hello, $NAME (single quotes: NO expansion)
```

**Always double-quote variables.** Unquoted variables undergo word-splitting and glob expansion, which causes subtle bugs. `"$CHANGED_FILES"` is safe; `$CHANGED_FILES` may split on spaces in file paths.

### Command substitution

```bash
# Run a command and capture its output
TODAY=$(date +%Y-%m-%d)          # Modern syntax (preferred)
TODAY=`date +%Y-%m-%d`           # Legacy syntax (avoid — harder to nest)

BRANCH=$(git branch --show-current)
HEAD_SHA=$(git rev-parse HEAD)
```

### Arithmetic

```bash
# Integer arithmetic only — use bc or python3 for floats
TOTAL=$(( SPENT + SESSION_SPEND ))    # Addition
PCT=$(( TOTAL_SPENT * 100 / TOKEN_BUDGET ))   # Division truncates to integer
```

### Functions

```bash
my_function() {
    local arg1="$1"    # local: scoped to this function
    local arg2="$2"
    echo "Args: $arg1 $arg2"
    return 0           # explicit return code (0 = success)
}

my_function "hello" "world"
```

Functions in bash behave like commands: they receive arguments as `$1`, `$2`, etc., and return an exit code (0–255) via `return`. They share the caller's variable scope unless you use `local`.

---

## 0.3 Exit Codes — The Universal Language of Success and Failure

### The rule

Every program that exits returns a number between 0 and 255 to its caller. **0 means success. Any other value means failure.** This is a Unix convention observed by every program on the system.

```bash
ls /tmp      # exits 0 (found the directory)
ls /noexist  # exits 2 (not found)
echo $?      # prints the exit code of the LAST command
```

`$?` is a special variable that always holds the exit code of the most recently completed command.

### Why 0 means success

When a program succeeds, it may succeed in many ways (fast, slow, different modes). When it fails, it may fail in many different ways. Using 0 for one specific state (success) and the rest for various failure codes is a natural encoding.

Importantly, exit code 0 is the expected default for "everything is fine." Code that checks `if command_ran_successfully; then` can be written as `if cmd; then` because bash treats exit code 0 as `true`.

```bash
if git commit -m "test" 2>/dev/null; then
    echo "commit succeeded"   # only prints if git exited 0
fi
```

### How git hooks use exit codes

Git runs each hook as a child process. After the hook finishes, git reads the exit code:

- **Exit 0** → git continues with the operation (commit proceeds, push proceeds)
- **Exit non-zero (typically 1)** → git aborts the operation

This is the entire mechanism by which gate.sh blocks commits. Every `exit 1` in gate.sh's 942 lines is a commit block. Every `exit 0` is a pass. All 942 lines are computing which one to return.

```bash
# The simplest possible blocking hook:
#!/usr/bin/env bash
exit 1    # blocks every single commit forever

# The simplest possible passing hook:
#!/usr/bin/env bash
exit 0    # passes every commit (equivalent to no hook)
```

### Exit codes in gate.sh

gate.sh never returns exit 2, 3, or anything other than 0 or 1. The reason: git hooks only distinguish between 0 (allow) and non-zero (block). Using specific non-zero codes would convey no additional information to git. The human-readable block reason is printed to stderr before the `exit 1`.

---

## 0.4 Standard Streams — stdin, stdout, stderr, and Why They're Separate

### The three file descriptors

When any process starts, it inherits three open **file descriptors** (FDs) from its parent:

| FD | Name | Default destination | Usage |
|----|------|--------------------|----|
| 0  | stdin | keyboard / empty | Process reads input from here |
| 1  | stdout | terminal screen | Normal output |
| 2  | stderr | terminal screen | Error messages and diagnostics |

FDs are integers that point to open files. FD 0, 1, and 2 are opened by convention. You can open more (FD 3, 4, etc.) for other purposes.

### Why stderr exists separately from stdout

The separation is for composability. When you chain commands in a pipeline:

```bash
git log --oneline | grep "feat" | wc -l
```

stdout flows through the pipe. stderr bypasses the pipe and goes directly to your terminal. This means log messages from git don't corrupt the data being counted by `wc -l`.

In gate.sh, **all human-readable output goes to stderr** (`>&2`). The hook's stdout is never used for messages — only for data that other programs might parse. This is why you see `echo "GATE PASS..." >&2` — the `>&2` redirects the output of echo from FD 1 (stdout) to FD 2 (stderr), where the developer will see it in their terminal.

```bash
# Redirection syntax
echo "error message" >&2           # stdout → stderr
command 2>/dev/null                # stderr → /dev/null (discard errors)
command > output.txt               # stdout → file
command 2>&1                       # stderr → same place as stdout
command > output.txt 2>&1          # both → file
```

### stdin and /dev/tty

`/dev/tty` is a special file that represents the controlling terminal — the physical terminal the process is attached to. It is distinct from stdin (FD 0), which may have been redirected.

In gate.sh's bypass prompt and in the agent approval hook:

```bash
printf 'Approve? [y/N] ' > /dev/tty      # write directly to terminal
read -r REPLY < /dev/tty                  # read directly from terminal
```

This is used because Claude Code captures the hook's stdin and stdout for injection into the model context. Writing to `/dev/tty` bypasses that capture entirely and goes directly to the physical keyboard/screen of the developer sitting at the terminal.

---

## 0.5 Pipes and Pipelines — Composition Without Coupling

### What a pipe does

A pipe (`|`) connects the stdout of one command to the stdin of the next:

```bash
git diff --cached -p | grep -iE "password" | wc -l
```

Three processes run concurrently:
1. `git diff` writes its output
2. `grep` reads that output, filters it
3. `wc -l` reads grep's output, counts lines

The shell creates these three processes nearly simultaneously. They communicate through kernel buffers (not temp files). When a writer fills the buffer, it blocks until the reader consumes some. This is efficient and — critically — the data never touches disk.

### Exit codes in pipelines

By default, the exit code of a pipeline is the exit code of the **last** command:

```bash
false | true   # exit code = 0 (true succeeded; false is ignored)
```

This is a dangerous default for a security script. If `git diff` failed (exit 1), but `grep` returned exit 0 because the pattern wasn't found, the pipeline exit code would be 0 (pass), hiding the upstream failure.

`set -o pipefail` fixes this: the pipeline exit code becomes the **rightmost non-zero exit code**, or 0 if all succeeded.

```bash
set -o pipefail
false | true   # exit code = 1 (false failed; pipefail propagates it)
```

### grep's role in exit codes

`grep` exits 0 if it found any match, 1 if it found no match, 2 on error. In gate.sh's secrets scan:

```bash
if git diff --cached --diff-filter=ACMR -p 2>/dev/null | \
    grep -iE '(api[_-]?key|secret|password|...)' 2>/dev/null | \
    grep -v '^---\|^+++\|^@@\|^#\|placeholder\|example\|REDACTED' 2>/dev/null | \
    grep -q .; then
    SECRETS_FOUND=1
fi
```

`grep -q .` exits 0 if there's any output at all (at least one byte), 1 if there's nothing. The entire pipeline exit code tells gate.sh whether any secret-looking string survived the filters.

But there's a subtle problem with `set -o pipefail` here: if `grep -v` filters out ALL lines (no secrets), it exits 0. If `grep -iE` finds nothing, it exits 1. With pipefail, the whole pipeline exits 1, which means the `if` condition is false — correct behavior, secrets not found. But if `git diff` fails (crashes, empty repo), it exits 1, pipefail propagates that, and the `if` is false — also correct (blocked by the ERR trap).

The `|| true` patterns you'll see elsewhere prevent pipefail from aborting on expected "not found" exits:

```bash
SOME_VAR=$(grep -oE 'date=[0-9]+' <<< "$NOTES" | head -1 | cut -d= -f2 || true)
```

The `|| true` converts any non-zero exit to 0, preventing set -e from aborting.

---

## 0.6 Shell Options: set -euo pipefail — Why This Is the First Line of Every Serious Script

These three options together form the safety layer that gate.sh depends on. Without them, bash scripts silently continue through errors.

### -e (errexit): Exit on any error

```bash
#!/usr/bin/env bash
set -e
false           # This command fails (exit 1)
echo "This line never runs"   # script exits before here
```

Without `-e`, bash ignores the failed `false` and runs the echo. With `-e`, any command that exits non-zero immediately terminates the script.

**Exception:** Commands in `if`, `while`, `until` conditions, and commands followed by `||` or `&&` are not subject to `-e`. This is intentional — you often want to test whether a command failed.

```bash
set -e
if false; then echo "never"; fi    # OK — condition is expected to fail
false || true                       # OK — the || makes it fail-safe
command_that_might_fail || true     # OK — explicitly suppress -e here
```

### -u (nounset): Error on unset variables

```bash
set -u
echo $UNDEFINED_VAR   # Error: UNDEFINED_VAR: unbound variable
```

Without `-u`, `$UNDEFINED_VAR` expands to an empty string silently. A typo like `$GATE_STAET` instead of `$GATE_STATE` would silently use an empty string, causing confusing behavior downstream.

Default values for potentially unset variables:

```bash
# Set a default if the variable is unset or empty
VALUE="${SOME_VAR:-default}"

# Error only on unset, not empty
VALUE="${SOME_VAR-default}"
```

gate.sh uses `${GATE_TRIGGER:-pre-commit}` throughout: if `GATE_TRIGGER` was not set by the calling hook, default to `pre-commit`.

### -o pipefail: Pipeline failure propagation

Covered in 0.5. With pipefail:
- A pipeline's exit code = the rightmost non-zero exit code
- If all commands succeed, exit code = 0

### Together: fail-fast and loud

```bash
#!/usr/bin/env bash
set -euo pipefail
```

With all three:
- **Any** failing command terminates the script (`-e`)
- **Any** typo in a variable name terminates the script (`-u`)
- **Any** failure in a pipe is propagated (`-o pipefail`)

The result: gate.sh cannot silently continue through an error. Any unexpected failure hits the ERR trap (next section) and blocks the commit with a diagnostic.

This is the correct behavior for a security gate: **better to block than to silently pass corrupted state.**

---

## 0.7 Signal Handling and Traps — What Happens When Things Go Wrong

### Signals

Signals are asynchronous notifications sent to a process. Common ones:

| Signal | Number | Default action | How sent |
|--------|--------|---------------|----------|
| SIGINT | 2 | Terminate | Ctrl+C |
| SIGTERM | 15 | Terminate | `kill PID` |
| SIGKILL | 9 | Terminate (unstoppable) | `kill -9 PID` |
| SIGHUP | 1 | Terminate | Terminal closed |
| SIGPIPE | 13 | Terminate | Broken pipe |

### Trap syntax

```bash
trap 'command_to_run' SIGNAL [SIGNAL...]
```

A trap registers a handler: when the process receives the named signal (or pseudo-signal), it runs `command_to_run` instead of the default action.

### The ERR pseudo-signal

`ERR` is not a Unix signal — it's a bash pseudo-signal. It fires when any command exits with a non-zero status (under `set -e`). It fires BEFORE bash exits due to the `set -e` rule.

This makes `trap ... ERR` the ideal crash handler for safety scripts:

```bash
# gate.sh lines 221-225
_crash_handler() {
    echo -e "${RED}GATE CRASH at line $1 — exit $2. Commit blocked. Fix gate.sh or contact platform team.${RESET}" >&2
    exit 1
}
trap '_crash_handler ${LINENO} $?' ERR
```

When any command in gate.sh fails unexpectedly, this trap fires before the script exits. It prints the exact line number and exit code, then exits with code 1 (blocking the commit).

Without this trap, an unexpected crash (say, Python3 is missing, or a JSON file is malformed) would cause gate.sh to silently exit with whatever code the failing command returned. If that happened to be 0, the commit would pass despite an internal gate failure.

**The invariant:** Any unexpected failure in gate.sh is a BLOCK, never a PASS.

### EXIT trap for cleanup

```bash
trap 'cleanup_function' EXIT
```

`EXIT` fires when the script ends for any reason: normal exit, killed by signal, or killed by `set -e`. Useful for cleanup:

```bash
TMP_FILE=$(mktemp)
trap 'rm -f "$TMP_FILE"' EXIT    # cleaned up no matter how the script ends
```

gate.sh cleans up `$SESSION_SPEND` on successful pass (line 926: `rm -f "$SESSION_SPEND"`), but since this is on the happy path, a trap isn't needed — the ERR trap handles the failure case by blocking the commit.

**Exercise 0.7:** Write a 10-line bash script that:
1. Uses `set -euo pipefail`
2. Has an ERR trap that prints "CRASH at line $LINENO"
3. Intentionally fails at line 8 with `false`
4. Has a command at line 10 that should never run
Verify the trap fires at line 8.

---

<a name="module-1"></a>
# MODULE 1 — Git Internals: What Hooks Actually Are

**Prerequisite:** Module 0 (you understand processes, exit codes, and scripts).  
**Time investment:** 3–5 hours.  
**Why this module:** Hooks are not magic. They are shell scripts that git runs as child processes. Understanding git's object model tells you *why* a tree hash is used for receipts instead of a commit hash — a distinction that is the difference between a secure receipt system and a trivially bypassable one.

---

## 1.1 Git's Object Model — Commits, Trees, Blobs, Tags

Git stores everything as **objects** in `.git/objects/`. An object is a file containing:
- A header (`blob 1234\0`, `tree 567\0`, `commit 890\0`)
- The content

The filename is the SHA-1 hash of the header + content. This is content-addressable storage: the identifier IS the content.

### Four object types

**Blob**: Raw file content. No filename. No permissions. Just bytes.

```bash
# See the blob for a file:
git hash-object README.md    # prints the sha1 of just the content
```

**Tree**: A directory listing. Each entry has:
- file mode (100644 = regular file, 100755 = executable, 040000 = directory)
- object type (blob or tree)
- SHA-1 of the blob/subtree
- name

```bash
# See the tree for the current HEAD:
git cat-file -p HEAD^{tree}
# Example output:
# 100644 blob a8c9f7... CLAUDE.md
# 100644 blob 4bc8e2... README.md
# 040000 tree 9f12a3... templates
```

A tree is a snapshot of a directory at a specific moment. Critically: it recursively includes subtree SHAs, so the top-level tree SHA covers all files recursively.

**Commit**: Points to a tree (the state of files at this point) plus metadata.

```bash
git cat-file -p HEAD
# Example output:
# tree 9f12a3c4b5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0
# parent 3d2c1b0a9f8e7d6c5b4a3f2e1d0c9b8a7f6e5d4
# author Lakshya Diwani <lakshya@lji.io> 1751340000 +0530
# committer Lakshya Diwani <lakshya@lji.io> 1751340000 +0530
#
# feat: add billing report
```

A commit contains: tree hash, parent commit hash(es), author info, committer info, timestamp, message. The **commit hash** is derived from ALL of these fields.

**Tag**: Points to any object (usually a commit) with a name and optional message. Used for version releases (`v1.0.0`).

### The DAG structure

Commits form a **Directed Acyclic Graph (DAG)**. Each commit points to its parent(s). Branches are just named pointers to commits. `HEAD` is a pointer to the current branch.

```
  HEAD
   |
   v
main → commit C → commit B → commit A
                     |
               feature/x → commit D
```

### Content-addressable storage: the key insight

Because every object's name IS its content hash, git has a powerful property:
- **Two identical files have the same SHA**: no duplicate storage
- **Changing one byte creates a completely different SHA**: tamper-evident
- **A tree SHA covers all files recursively**: if any file anywhere in the tree changes, the top-level tree SHA changes

This last property is the basis of the receipt system in gate.sh.

---

## 1.2 What a Tree Hash Is and Why It's Cryptographically Useful

### How git computes a tree hash

```bash
# Get the tree hash of what's currently staged:
git write-tree
# Example output: 4b825dc642cb6eb9a060e54bf8d69288fbee4904

# Get the tree hash of HEAD:
git rev-parse HEAD^{tree}
# Same format — a SHA-1 hash
```

The tree hash is computed by:
1. For each file in the staging area: compute its blob SHA (hash of file content)
2. For each directory: recursively compute the subtree SHA
3. Hash the sorted list of `(mode, name, sha)` entries

The result: **a single SHA that fingerprints the exact contents of every file in the repository at this moment**.

### Tree hash vs. commit hash

This distinction is crucial for the receipt system:

| Property | Commit hash | Tree hash |
|----------|-------------|-----------|
| Changes when... | message/author/timestamp/parent changes | any FILE CONTENT changes |
| `git commit --amend` (message only) | NEW hash | SAME hash |
| `git commit --amend` (file added) | NEW hash | NEW hash |
| Rebase (same files, different parent) | NEW hash | SAME hash |

**The receipt system uses tree hashes because it wants to answer: "were these exact file contents verified?"** Not "was this specific commit object verified."

If you amend only the commit message (fixing a typo in "feat: biilng report" → "feat: billing report"), the files haven't changed — the tree hash is identical — so the receipt from pre-commit is still valid for the amended commit. This is correct behavior: the files were checked. Only the message metadata changed.

If you add a file to the amend, the tree hash changes, the receipt doesn't match, and pre-push will run the full gate again. Also correct.

### SHA-1 collision resistance

SHA-1 was broken in 2017 (SHAttered attack). Git is migrating to SHA-256. For this project's purpose — detecting accidental changes and creating audit trails — SHA-1's properties are more than sufficient. The receipt system is not a cryptographic proof against an active adversary with SHA-1 collision capabilities; it is a mechanical check against accidental bypass and careless circumvention.

### The Three-Tree Model — Why Unstaged Changes Are Invisible to git write-tree

This is the most important concept for understanding the receipt system. Git maintains **three completely separate data structures** simultaneously:

```
WORKING TREE              GIT INDEX (Staging Area)      OBJECT STORE (Commits)
────────────────          ─────────────────────────     ──────────────────────
Files on your disk        .git/index  (binary file)     .git/objects/
Edited by your editor     Built by: git add             Built by: git commit
Dirty, uncommitted        Snapshot of what will         Immutable, hashed,
No SHA, no version        be committed NEXT             permanent history
```

These are three **separate states**. A single file can simultaneously exist in all three trees with three different contents:

```bash
echo "v1" > auth.py && git add auth.py && git commit -m "v1"  # object store = v1
echo "v2" >> auth.py && git add auth.py                        # index = v2
echo "v3" >> auth.py                                            # working tree = v3

git diff HEAD          # shows v1 → v3 (object store vs working tree)
git diff --cached      # shows v1 → v2 (object store vs index)
git diff               # shows v2 → v3 (index vs working tree)
```

**`git write-tree` reads ONLY from the index** (`.git/index` binary file). It does NOT touch the filesystem. Unstaged changes in the working tree are completely invisible to it:

```bash
echo "clean" > file.py
git add file.py                 # index contains "clean"
echo "dirty" >> file.py         # working tree now has "clean\ndirty"
git write-tree                  # hashes the index → sees "clean" only
                                # "dirty" does NOT appear in the hash
```

This is why `COMMIT_TREE_FP = git write-tree` is the correct fingerprint for "what is about to be committed." It hashes exactly what `git commit` will commit — the index — not the entire working tree.

**Practical implication:** A developer with a dirty working tree (files edited but not staged) gets the same receipt as a developer with a clean working tree, provided their index contents are identical. The gate checks what will be committed, not what happens to be sitting on disk.

---

## 1.3 The .git/hooks Directory — What Git Does Before It Saves Work

### Git's hook mechanism

At specific points in its workflow, git checks for an executable file in the hooks directory and runs it as a subprocess. If the hook exits non-zero, git aborts the operation.

```bash
ls .git/hooks/
# applypatch-msg.sample    post-commit.sample    pre-push.sample
# commit-msg.sample        post-receive.sample   pre-rebase.sample
# fsmonitor-watchman.sample post-update.sample   pre-receive.sample
# post-checkout.sample     prepare-commit-msg.sample
# pre-applypatch.sample    pre-commit.sample     update.sample
```

The `.sample` suffix makes them inactive — git only runs files named exactly without `.sample`. To activate a hook:

```bash
cp .git/hooks/pre-commit.sample .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

### The list of hook events

| Hook | Fires when | Can block? |
|------|-----------|-----------|
| `pre-commit` | Before recording a commit | Yes (exit 1) |
| `prepare-commit-msg` | Before commit message editor opens | Yes |
| `commit-msg` | After commit message is entered | Yes |
| `post-commit` | After a commit is recorded | No (informational) |
| `pre-push` | Before sending refs to a remote | Yes (exit 1) |
| `pre-receive` | Server-side: before receiving a push | Yes |
| `update` | Server-side: before updating a ref | Yes |
| `post-receive` | Server-side: after receiving a push | No |

This project uses `pre-commit` (block commits) and `pre-push` (block pushes / verify receipts).

### What git passes to hooks

- **pre-commit**: Receives nothing on stdin and no arguments. The hook must use `git diff --cached` to see what's being committed.
- **pre-push**: Receives, on stdin, one line per ref being pushed: `<local-ref> <local-sha> <remote-ref> <remote-sha>`. Receives the remote name and URL as arguments.

```bash
# pre-push receives stdin like this:
# refs/heads/feature/x abc123 refs/heads/feature/x 000000...   (new branch)
# refs/heads/feature/x abc123 refs/heads/feature/x def456...   (update)
```

---

## 1.4 pre-commit vs pre-push — When Each Fires, What It Receives, What It Can Block

### pre-commit

**When:** Immediately after `git commit` is run, before git creates the commit object.

**What it can access:**
- `git diff --cached --name-only` → list of staged files
- `git diff --cached -p` → full diff of staged changes
- `git stash list` → stash state
- The working directory in its current state

**What it cannot access:**
- The commit hash (it hasn't been created yet)
- The tree hash of the commit (but it CAN get the tree hash of the staging area via `git write-tree`)

**What it blocks:** The creation of the commit object. If pre-commit exits 1, no `.git/COMMIT_EDITMSG` is written, no new commit object is created, nothing is added to the branch history.

**In this project:** gate.sh runs all 8 STEPs (branch check, token budget, secrets scan, lint, type check, layer boundary, tests, coverage/complexity) and writes a receipt on pass.

### pre-push

**When:** After `git push` is run, after the local refs are validated, but BEFORE any data is sent to the remote.

**What it receives on stdin:**
```
<local-ref> SP <local-sha> SP <remote-ref> SP <remote-sha> LF
```
- `local-ref`: the refspec being pushed (e.g., `refs/heads/feature/x`)
- `local-sha`: the SHA we're trying to send
- `remote-ref`: the ref on the remote side
- `remote-sha`: the current SHA on the remote (all zeros if it doesn't exist yet)

**What it blocks:** The push. If pre-push exits 1, no data is sent to the remote. The local repo is unchanged.

**In this project:** The pre-push hook does two things:
1. Checks for protected branches, force push attempts, bypass audit trail tampering (in the hook stubs written by install.sh)
2. Invokes gate.sh with `GATE_TRIGGER=pre-push` for receipt verification

---

## 1.5 core.hooksPath — How to Move Hooks Out of .git/ and Into Version Control

### The problem with .git/hooks/

The `.git/` directory is not committed to version control. When you run `git clone https://...`, you get all the project's files — but the cloned repo's `.git/hooks/` is empty (with only `.sample` files). Every developer who clones the repo starts without any hooks.

This means:
- New team members have no gate
- AI agents running in CI have no gate
- Anyone who does a fresh clone loses protection

### The solution: core.hooksPath

Git has a configuration option that redirects the hook lookup:

```bash
git config core.hooksPath .githooks
```

After this, git looks for hooks in `.githooks/` instead of `.git/hooks/`. Because `.githooks/` is a regular directory (not inside `.git/`), it IS committed to the repository.

```bash
# Verify:
git config --get core.hooksPath   # prints: .githooks
ls .githooks/
# gate.sh    pre-commit    pre-push
```

Now:
1. `git clone` downloads `.githooks/` along with all other files ✓
2. `.githooks/pre-commit` and `.githooks/pre-push` are in version history ✓
3. Every team member has the gate from their first commit ✓
4. Modifying the hooks requires a PR (goes through code review) ✓

**This single command (`git config core.hooksPath .githooks`) is the most important thing install.sh does.** Everything else is support infrastructure.

---

## 1.6 git notes — The Append-Only Audit Log System Baked Into Git

### What git notes are

Git notes are metadata you can attach to any git object (usually commits) without modifying the object itself. They are stored in a parallel ref namespace.

```bash
# Attach a note to the current commit:
git notes add -m "Reviewed by Alice on 2026-07-01"

# See the note:
git notes show HEAD

# Append to an existing note:
git notes append -m "Also reviewed by Bob"

# Use a custom ref namespace:
git notes --ref=refs/notes/reviews add HEAD -m "approved"
```

Notes live in `refs/notes/<name>`. The default is `refs/notes/commits`.

### Key properties

**Notes do NOT change the commit hash.** The SHA of the commit object is computed from its tree, parent, author, committer, timestamp, and message. Notes are stored separately and are not part of this calculation. Adding a note to a commit doesn't change the commit's identity.

**Notes are push-independent.** They live in `refs/notes/`, which is separate from `refs/heads/` (branches) and `refs/tags/` (tags). A `git push` does not push notes by default:

```bash
git push origin refs/notes/bypasses    # explicitly push notes
git push origin 'refs/notes/*:refs/notes/*'   # push all note namespaces
```

**The fetch side — a silent failure most teams hit:**

Pushing notes is only half the story. Git's default fetch refspec maps `refs/heads/*` to `refs/remotes/origin/*`. The `refs/notes/` namespace is not included. This means `git fetch origin` silently ignores all remote notes, forever, unless the refspec is explicitly extended:

```bash
# What git fetch does by default (from .git/config):
[remote "origin"]
    fetch = +refs/heads/*:refs/remotes/origin/*
    # refs/notes/* is NOT here — notes are never fetched

# Fix: add the notes refspec (run once per clone):
git config --add remote.origin.fetch '+refs/notes/*:refs/notes/*'

# .git/config now contains:
[remote "origin"]
    fetch = +refs/heads/*:refs/remotes/origin/*
    fetch = +refs/notes/*:refs/notes/*
```

After this, `git fetch origin` also syncs all note namespaces. Without it, a teammate can push a bypass note and every other developer's clone will never see it — `git log --show-notes=bypasses` shows nothing, silently. The bypass audit trail is effectively invisible across the team.

**install.sh gap:** This refspec configuration is not currently automated by install.sh. Teams using multi-developer bypass auditing must add it to their setup script or clone instructions:
```bash
# Add to install.sh after git config core.hooksPath:
git config --add remote.origin.fetch '+refs/notes/*:refs/notes/*'
```

**Notes can be seen on log:**

```bash
git log --show-notes=bypasses   # shows bypass notes inline with the log
```

### Mutability

Notes can be edited (`git notes edit HEAD`) or removed (`git notes remove HEAD`). However, this project protects against deletion by blocking any push that targets the bypass notes namespace:

```bash
# In the pre-push hook:
if echo "$LOCAL_REF $REMOTE_REF" | grep -qE ':refs/notes/bypasses'; then
    echo "PRE-PUSH BLOCK: Tampering with bypass audit trail is forbidden." >&2
    exit 1
fi
```

---

## 1.7 refs/notes/bypasses — How This Project Creates a Tamper-Evident Bypass Log

### The specific ref used

When a developer uses `SKIP_GATE=1 git commit ...`, gate.sh writes:

```bash
git notes --ref=refs/notes/bypasses append HEAD \
  -m "BYPASS | date=$(date +%s) | reason=${BYPASS_REASON}"
```

This creates a note under `refs/notes/bypasses` on the HEAD commit containing:
- An exact Unix timestamp (not git's spoofable `GIT_COMMITTER_DATE`)
- The developer's stated reason

### What the pre-push hook reads

```bash
# From the pre-push hook:
if git notes --ref=refs/notes/bypasses show HEAD 2>/dev/null | grep -q "BYPASS"; then
    BYPASS_DATE=$(git notes --ref=refs/notes/bypasses show HEAD 2>/dev/null \
        | grep -oE 'date=[0-9]+' | head -1 | cut -d= -f2)
    NOW_EPOCH=$(date +%s)
    BYPASS_AGE=$(( NOW_EPOCH - BYPASS_DATE ))
    if [ "$BYPASS_AGE" -gt 86400 ]; then
        echo "PRE-PUSH BLOCK: Bypass deadline expired ($((BYPASS_AGE/3600))h ago)." >&2
        exit 1
    fi
fi
```

The pre-push hook extracts the epoch timestamp, computes the age in seconds, and blocks pushes if the bypass is older than 24 hours (86400 seconds).

### How to audit who bypassed

```bash
# List all bypass notes in the repo:
git log --show-notes=bypasses --grep="BYPASS" --all

# Show the bypass note for a specific commit:
git notes --ref=refs/notes/bypasses show <sha>

# See all commits with bypass notes:
git log --all | while read sha; do
    note=$(git notes --ref=refs/notes/bypasses show "$sha" 2>/dev/null)
    [ -n "$note" ] && echo "$sha: $note"
done
```

### Tamper protection

Three mechanisms prevent the bypass audit trail from being erased:

1. **Pre-push blocks note deletion:** Any refspec pushing to `refs/notes/bypasses` is blocked.
2. **Notes don't modify commit hashes:** Removing a note doesn't change the commit, but the absence of the note is detectable if someone pushed the notes ref before deleting them.
3. **Remote copy is the source of truth:** Once notes are pushed to origin, they can be recovered even if deleted locally.

**Exercise 1.7:** On any git repo, run `git notes add HEAD -m "test"`. Then run `git cat-file -p HEAD` — observe that the commit hash doesn't change. Run `git notes show HEAD` to confirm the note exists. Run `git notes remove HEAD`. The commit hash is still the same.

---

<a name="module-2"></a>
# MODULE 2 — The Problem This Project Exists to Solve

**Prerequisite:** None — this module is context, not mechanics.  
**Time investment:** 1–2 hours.  
**Read this before touching any code.** The best way to misunderstand a system is to learn what it does without first understanding why it was built.

---

## 2.1 What AI Coding Assistants Actually Do at the System Level

Claude Code, GitHub Copilot, Cursor, and similar tools operate as follows:

1. They receive the contents of your open files + git context as input (this is "context")
2. They generate text that looks like code
3. They write that text to your files via tool calls (Write, Edit, MultiEdit)
4. They may run commands (Bash tool) to verify the output

The key word is **generate**. LLMs are autocomplete systems at scale. They generate the statistically most likely continuation of their input. They do not compile the code, run it, or reason about its correctness in the way a human engineer reasons.

When an LLM generates a function, it is pattern-matching: "what does a function like this usually look like in a codebase like this?" The output is syntactically valid (it has seen millions of examples) and often functionally correct (it has seen what correct code looks like). But it may violate architectural invariants specific to YOUR codebase that are not captured in training data.

At the system level, Claude Code's file writes are identical to yours: it calls the same operating system APIs to modify the same files. The difference is the decision-making process that produced those bytes.

---

## 2.2 Why AI-Generated Code Passes Review but Fails in Production

Code review is a cognitive task. Reviewers are looking for:
- **Syntax errors** (rare in AI code — LLMs are excellent at syntax)
- **Logic errors** (sometimes caught — obvious ones)
- **Security vulnerabilities** (sometimes caught — reviewers vary in expertise)
- **Architectural violations** (rarely caught — requires deep codebase knowledge)

AI-generated code is typically syntactically perfect and logically plausible. It looks right. It follows the language's idioms. It may even follow the project's naming conventions if those were in the context window.

What it often violates are **implicit invariants** — rules that are never written anywhere in the files the LLM sees, but are understood by every engineer who has worked on the system:

- "We never put database queries in route handlers — that's what repositories are for"
- "Auth middleware must be the first decorator on any data endpoint"
- "API keys are only read from SSM, never from environment variables"
- "This endpoint always returns a structured error, never a raw exception"

A reviewer who reviews code all day, on their fourth review of the afternoon, with three Slack threads open — they will miss these. Not because they don't know the rule. Because cognitive load is real and subtle violations look clean.

---

## 2.3 The Three Failure Modes: Security Debt, Architecture Drift, Token Waste

### Failure Mode 1: Security Debt

AI tools generate code that introduces security vulnerabilities at a rate proportional to their speed. Specific patterns observed in AI-generated code:

**Hardcoded credentials:**
```python
# AI-generated "quick test" that gets committed
DATABASE_URL = "postgresql://admin:password123@prod-db.company.com/billing"
```

**SQL injection via f-strings:**
```python
# AI replacing parameterized query with f-string for "convenience"
cursor.execute(f"SELECT * FROM users WHERE id = {user_id}")
```

**Auth bypass:**
```python
# AI adding a "health check" endpoint without realizing auth is required
@app.get("/health")
async def health():    # missing: Depends(get_current_user)
    return {"status": "ok", "db": await db.execute("SELECT 1")}
```

These pass syntax checks and often pass linting. They fail under security review — but security review is not always thorough.

### Failure Mode 2: Architecture Drift

Over weeks of AI-assisted development on a layered architecture (routes → services → repositories), the layers blur:

- AI writes a service function that imports directly from FastAPI because it needed an `HTTPException`
- AI puts a `SELECT` query in a route handler because it was "simpler to just do it here"
- AI writes a repository function that calls an external HTTP API because it was "adjacent to the data access pattern"

Each individual violation is small. Collectively, after a month, the architecture is gone. The codebase is a ball of mud where routes call databases, services call HTTP, and repositories call services. Debugging becomes impossible. Testing becomes impossible. Refactoring becomes impossible.

### Failure Mode 3: Token Waste

An LLM API charges per token. Claude's context window can hold ~200,000 tokens. A session that loads the entire codebase as context can consume 50,000–100,000 tokens before writing a single line of code.

With a team of 10 engineers, each running 2–3 Claude sessions per day:
- 10 engineers × 3 sessions × 100,000 tokens/session = 3,000,000 tokens/day
- At $15/MTok (Claude 3 Opus pricing): $45/day = $1,350/month

Without a budget system, this spending is invisible until the invoice arrives.

---

## 2.4 Why the Failure Is Systemic, Not Per-Engineer

These failures are not caused by incompetent engineers using AI tools carelessly. They are structural:

1. **Speed asymmetry:** AI writes 10× faster than humans. The reviewer is always behind.
2. **Context asymmetry:** The reviewer sees 50–100 lines at a time. The AI saw the whole codebase.
3. **Implicit knowledge asymmetry:** The AI doesn't know your architecture. The reviewer knows it but it's never written down.
4. **Cognitive fatigue:** Reviews done under time pressure miss things everyone would catch with fresh eyes.

The failure compounds: as the codebase accumulates small violations, engineers stop trusting the architecture, start working around it instead of with it, and the violations accelerate.

---

## 2.5 Why Linters and Code Review Don't Catch It

### Why linters fail

Linters (ruff, eslint, golangci-lint) check against language-level rules:
- Unused variables
- Missing semicolons
- Deprecated function calls
- Cyclomatic complexity

They do NOT check:
- "Is this HTTP import in a file that should only contain business logic?"
- "Is this SQL in a file that should only contain HTTP request handlers?"
- "Does this endpoint have the required authentication middleware?"

These are **codebase-specific invariants**, not language rules. You cannot express them in a linter config without writing a custom plugin (which is complex, fragile, and rare).

### Why code review fails

Code review catches what reviewers are looking for. Reviewers are looking for:
- Correctness (does it work as described?)
- Obvious security issues (they've seen before)
- Code style (is it consistent?)

Reviewers are NOT systematically checking:
- "Does every file in app/services/ have zero HTTP imports?"
- "Does every file in app/routes/ have zero SQL?"
- "Does every file that contains an endpoint have the auth decorator?"

Because doing that systematically would require reading every line of every file in the relevant directories, every review, every PR. Nobody does this.

---

## 2.6 What a "Governance Gate" Is Conceptually

A governance gate is a **mechanical checkpoint** that sits in the code delivery pipeline and enforces a set of rules automatically, every time, without human attention.

Key word: **mechanical**. The gate doesn't understand the code. It pattern-matches. It checks specific signatures. But it does this precisely, consistently, in under 2 minutes, on every single commit, without fatigue.

The gate covers what humans systematically miss:
- Exact grep patterns (SQL strings in route files)
- Token budget arithmetic
- Secret scanning via regex on the diff
- Receipt verification

It does NOT replace code review. It augments it by ensuring that the things machines can check reliably are always checked.

---

## 2.7 The Difference Between Advisory Gates and Blocking Gates

**Advisory gate:** Reports problems but lets the commit proceed. Example: `pre-commit` that prints warnings but always exits 0.

**Blocking gate:** Prevents the operation if problems are found. Example: gate.sh, which exits 1 when checks fail.

Advisory gates are often worse than no gate at all. When developers see the same warnings on every commit and nothing happens, they learn to ignore them. The warnings become noise. The signal is lost.

Blocking gates are more disruptive but more effective. The key is that **blocked commits must be fixable in reasonable time**. A gate that blocks commits for issues the developer cannot fix (because the test suite takes 20 minutes or the fix requires a product decision) will be disabled or bypassed.

gate.sh's design respects this: the bypass system exists precisely because an unbypassable gate gets deleted.

---

## 2.8 Why This Lives in Git Hooks and Not in the CI/CD Pipeline

### The CI/CD option

An alternative approach: run all checks in CI (CircleCI, GitHub Actions, etc.) after every push. Block merges until CI passes.

**Pros:** Platform-managed, always consistent, visible to everyone.  
**Cons:**
1. **Feedback latency:** CI runs after you push. You find out the gate failed 5 minutes later, in a different context.
2. **Broken-branch syndrome:** Commits that fail CI sit in the PR as broken until fixed. This is disruptive to other reviewers.
3. **Token waste is not CI-catchable:** Token budgets are per-session spending that needs to be measured at commit time.
4. **No receipt system:** CI cannot produce a receipt that a downstream step (push) can verify quickly.

### The git hook advantage

Git hooks run **before** the commit (pre-commit) and **before** the push (pre-push). The developer gets feedback in 60–90 seconds, while their context is still fully loaded. They fix it immediately. The commit that enters the PR is already clean.

The dual-hook architecture (explained in detail in Module 3) front-loads all the expensive checking to commit time, and makes push-time trivially fast via the receipt system.

This project does ALSO include a CI gate (`.github/workflows/gate.yml`) for defense-in-depth — but the primary gate is local, at the hook layer, because local is faster and provides better developer experience.

---

<a name="module-3"></a>
# MODULE 3 — Architecture Overview

**Prerequisite:** Modules 0, 1, 2.  
**Time investment:** 2–4 hours.  
**Goal:** Form a complete mental model before reading any implementation code. You should be able to draw the architecture from memory after this module.

---

## 3.1 The Two-Layer Architecture: The Framework Repo vs the Target Repo

This project has two distinct roles:

### The framework repo (ai-dev-workflow)

Lives at `~/ai-dev-workflow/` (or wherever it was cloned). This is what you are studying. It contains:
- `install.sh` — the bootstrapper
- `templates/gate.sh` — the enforcement engine (the source of truth)
- `templates/gate_state.json` — the initial state schema
- `tests/gate/` — the bats test suite for gate.sh
- `v1_release/` — documentation packages for teams
- `.claude/settings.json` — the project-level Claude Code hook for write-guarding

The framework repo is never installed in a project. You run `install.sh` from it to install the gate INTO another project.

### The target repo (your project)

Any repository where the team works. After `./path/to/install.sh` runs in the target repo:
- `.githooks/gate.sh` — copy of the enforcement engine
- `.githooks/pre-commit` — stub that calls gate.sh with `GATE_TRIGGER=pre-commit`
- `.githooks/pre-push` — stub that calls gate.sh with `GATE_TRIGGER=pre-push` (plus protected branch guards)
- `.claude/gate_state.json` — the live state machine
- `.claude/baseline.json` — lint debt ratchet (brownfield only)
- `.mcp.json` — code-review-graph configuration
- `CLAUDE.md` — the team's engineering constitution (human-authored)
- `~/.claude/org_policy.json` — written to the home directory, not the repo

The target repo is where developers work. gate.sh enforces the rules defined in `gate_state.json`.

---

## 3.2 The Installation Flow: What install.sh Does to a Foreign Codebase

```
Developer runs: cd /path/to/target-repo && /path/to/ai-dev-workflow/install.sh

install.sh:
  1. Verify git, python3 present
  2. Detect target repo root (git rev-parse --show-toplevel)
  3. Count commits → greenfield (≤50) or brownfield (>50)
  4. mkdir -p .githooks .claude
  5. cp templates/gate.sh .githooks/gate.sh && chmod +x
  6. Write .githooks/pre-commit (stub that sets GATE_TRIGGER=pre-commit and execs gate.sh)
  7. Write .githooks/pre-push (stub with protected branch checks, bypass clock, receipt path)
  8. git config core.hooksPath .githooks
  9. pipx install code-review-graph==2.3.6 (semantic code index)
 10. Write .mcp.json (graph configuration)
 11. Write ~/.claude/org_policy.json (token budget — if not already exists)
 12. Write .claude/gate_state.json (from templates/gate_state.json — the initial state)
 13. Brownfield: snapshot current lint errors → .claude/baseline.json
 14. Greenfield: write .claude/baseline.json with count=0
 15. Scaffold CLAUDE.md if not present
 16. Print: "Installation complete"
```

After installation, the target repo is governed. Every commit fires gate.sh.

---

## 3.3 The Enforcement Loop: commit → pre-commit hook → gate.sh → block or pass

```
Developer types: git commit -m "feat: add billing report"
                                 │
            git reads core.hooksPath = ".githooks"
                                 │
            git executes .githooks/pre-commit as a subprocess
                                 │
            pre-commit sets GATE_TRIGGER=pre-commit
            pre-commit execs gate.sh (replaces self with gate.sh)
                                 │
            gate.sh starts. set -euo pipefail. ERR trap registered.
                                 │
            ┌─── GATE CHECKS (8 STEPs) ────────────────────────────┐
            │                                                       │
            │  STEP 1: Branch validation + code_writes_permitted    │
            │  STEP 2: Token harness (daily budget)                 │
            │  STEP 3: Graph staleness warning                      │
            │  STEP 4: Scan scope + fingerprints                    │
            │  STEP 4.4: Brainstorming checkpoint (agent only)      │
            │  STEP 4.5: WORKING_TREE_FP + COMMIT_TREE_FP          │
            │  STEP 4.6: Pre-push checkpoint gate (agent only)      │
            │  STEP 5: Secrets scan                                 │
            │  STEP 6: Lint + type check                            │
            │  STEP 6.5: Layer boundary scan                        │
            │  STEP 7: Frontend checks                              │
            │  STEP 8: Tests + coverage + complexity (if enabled)   │
            │                                                       │
            └───────────────────────────────────────────────────────┘
                                 │
              Any check fails?
              YES → exit 1 → commit blocked
              NO  → write receipt → update last_pass_sha → exit 0
                                 │
            git receives exit 0 → commit object created → branch advances
```

---

## 3.4 The State Machine: gate_state.json as the Memory Between Runs

gate.sh has no in-memory state that persists between invocations (it's a new process every commit). All persistent state lives in `.claude/gate_state.json`.

Key fields gate.sh reads and writes:

| Field | Read by | Written by | Purpose |
|-------|---------|-----------|---------|
| `last_pass_sha` | STEP 4 | STEP 8 | Incremental scan baseline |
| `receipts` | STEP 4.5 (pre-push) | STEP 8 | Fast-path verification |
| `token.token_spent_today` | STEP 2 | STEP 8 | Budget accumulation |
| `token.token_last_reset` | STEP 2 | STEP 2 | Date-roll detection |
| `token.token_audit_log` | — | Multiple steps | 90-day audit trail |
| `mcp_graph.last_build_timestamp` | STEP 3 | _ensure_graph_freshness | Staleness warning |
| `claude_md_hash` | _verify_context_anchoring | same | Drift detection |
| `thresholds` | STEP 6, 8 | (human via PR) | Configurable limits |
| `branch_strategy` | STEP 1 | (human via PR) | Branch rules |
| `core_files` | STEP 4.3 | (human via PR) | Tier-3 escalation |

The file is a JSON document committed to the repo. Every time gate.sh runs, it reads this file at the start and writes updates at the end.

---

## 3.5 The Receipt System: Cryptographic Proof That a Commit Was Gate-Verified

The problem: pre-commit runs all checks and takes 60–90 seconds. pre-push also runs gate.sh — without receipts, this would be another 60–90 seconds of identical work.

The solution: after all pre-commit checks pass, gate.sh writes a receipt to `gate_state.json`:

```json
{
  "receipts": {
    "4b825dc642cb6eb9a060e54bf8d69288fbee4904": {
      "timestamp": "2026-07-01T14:23:00Z",
      "branch": "feature/billing-report",
      "outcome": "pass"
    }
  }
}
```

The key is `COMMIT_TREE_FP` — `git write-tree` at pre-commit time (the SHA of what's about to be committed).

At pre-push time:
1. gate.sh computes `git rev-parse HEAD^{tree}` (the tree hash of what was committed)
2. Looks it up in `receipts`
3. If found with `outcome: pass` → exits 0 in under 100ms
4. If not found → runs full gate (which happens for: no pre-commit was run, bypass was used, tree changed after commit)

---

## 3.6 The Two-Hook Protocol: pre-commit Writes a Receipt, pre-push Verifies It

```
COMMIT TIME:
  git commit
    → pre-commit fires
    → gate.sh STEP 1-8 (60-90 seconds)
    → COMMIT_TREE_FP = git write-tree  [the STAGED tree]
    → all checks pass
    → _receipt_write "$COMMIT_TREE_FP" "$CURRENT_BRANCH"
    → exit 0
    → commit object created
    → HEAD advances to new commit

PUSH TIME (seconds to minutes later):
  git push
    → pre-push fires
    → gate.sh STEP 4.5 (first thing checked)
    → COMMIT_TREE_FP = git rev-parse HEAD^{tree}  [the COMMITTED tree]
    → _receipt_has_pass "$COMMIT_TREE_FP" == "yes"
    → exit 0 immediately  [< 100ms]
    → data sent to remote
```

Note: at pre-commit time, `git write-tree` returns the tree that would be committed from the staging area. At pre-push time, `git rev-parse HEAD^{tree}` returns the tree that was actually committed. They are the same tree hash if nothing changed between commit and push — which is the normal case.

---

## 3.7 The Claude Code Hook Layer: Intercepting Writes Before They Happen

Claude Code supports **hooks**: shell scripts that run at specific events in the tool's lifecycle.

**PreToolUse hooks** fire BEFORE a tool call executes and can block it (exit 1 = block).

This project configures two PreToolUse hooks:

**Hook 1 — Global agent approval** (`~/.claude/settings.json`):
Fires before any `Agent` tool call. Prompts the developer on `/dev/tty` for approval before Claude Code spawns a subagent.

**Hook 2 — Project write guard** (`.claude/settings.json` in the ai-dev-workflow repo itself):
Fires before any `Write | Edit | MultiEdit` tool call. Reads `gate_state.json`, checks `code_writes_permitted` for the current branch. On release branches where this is false, the file write is blocked before it happens — the file never touches disk.

This creates a **three-layer defense**:
1. Claude Code PreToolUse hooks (before file written)
2. git pre-commit hook / gate.sh (before commit created)
3. git pre-push hook (before data sent to remote)

Each layer can catch what the previous layer missed.

---

## 3.8 The MCP Graph Layer: Semantic Understanding of the Codebase

`code-review-graph` is a semantic code indexer installed via `pipx` at install time. It builds a graph of the codebase's modules, their relationships, and their impact radii.

gate.sh interacts with this graph in two ways:

**STEP 3 — Staleness check:** If the graph hasn't been rebuilt in >7 days, warn (once per day) that analysis may be stale. This is informational, not a block.

**_ensure_graph_freshness** (STEP 8 / post-pass): After all checks pass, gate.sh spawns a background rebuild:

```bash
nohup bash -c "code-review-graph build > /dev/null 2>&1; rm -f '$_GF_PID_FILE'" > /dev/null 2>&1 &
echo $! > "$_GF_PID_FILE"
```

Key detail (commit `630d3ad`): before spawning a new build, gate.sh checks if a prior build is still running (via `.claude/graph.pid`) and kills it with `kill -9`. This prevents stale index drift where an old indexer finishes after a new commit changes the files.

---

## 3.8.1 What the Graph Actually Contains — Nodes, Edges, and Tool Contracts

Module 5.3 lists five MCP tool names and `max_hops` values without explaining what they operate on. This section fills that gap.

### Nodes

A node in the `code-review-graph` index is a **named symbol with a location** — a function, class, method, or top-level constant. Not a file. A file with 12 functions produces 12 function nodes plus 1 module node.

```
Node:
  id:      "app/services/kpi_service.py::get_kpi_summary"
  type:    function | class | method | module
  file:    "app/services/kpi_service.py"
  line:    42
  domain:  "application_code"   ← one of included_domains
```

`node_count` in `gate_state.json` is the total node count after the last build. Watching this number across builds tells you how much of the codebase is indexed.

### Edges

An edge represents a typed dependency between two nodes:

| Edge type | Meaning | Example |
|-----------|---------|---------|
| `calls` | Function A invokes function B | `kpi_service.get_kpi_summary → kpi_repository.fetch_kpi_rows` |
| `imports` | Module A imports symbol B | `routes/kpis.py → services/kpi_service.KpiService` |
| `inherits` | Class A subclasses class B | `AdminUser → BaseUser` |
| `uses_sql` | Function A executes a migration/SQL file | `kpi_repository.fetch_kpi_rows → migrations/0012_add_billing_table.sql` |

**The `included_domains` constraint:** Edge construction is restricted to nodes whose `domain` field is in `included_domains`. Omitting `"sql_migrations"` means `uses_sql` edges are never built — the impact of a schema change is invisible to the graph. This is why the default `included_domains` list includes all seven domain types.

### max_hops — BFS Depth in the Dependency Graph

When `get_impact_radius_tool` is called for a changed file, the graph server does a breadth-first traversal following edges outward from the changed symbols:

```
hop 0: the changed symbol
hop 1: everything that directly calls/imports the changed symbol
hop 2: everything that calls/imports those callers
hop N: …
```

`max_hops: 1` (ULTRA-NARROW, hotfix): Only direct callers. Minimum blast-radius view for production emergencies.  
`max_hops: 2` (NARROW, bugfix): Callers and their callers. Sufficient for targeted bug fixes.  
`max_hops: null` (BROAD, feature): Full transitive closure. Architecture-level changes need the full picture.

**Critical detail:** `max_hops` is enforced by the MCP server at query time, not by gate.sh and not by CLAUDE.md. The server reads `branch_strategy.<type>.max_hops` from `gate_state.json` and truncates the BFS at that depth before returning. The AI cannot "ask for deeper" — the server will not return it.

### The Five MCP Tools and What They Are For

**`get_architecture_overview_tool`** (BROAD only, required before first write)  
Returns a structural summary of the entire codebase: all modules organized by domain, their top-level import/call relationships, and any detected cross-domain violations. This is the "zoom out" before starting a feature. BROAD branches set `architecture_overview_required: true`, which means the AI must call this tool before any write — enforced by the hook layer.

**`semantic_search_nodes_tool`** (BROAD only)  
Text search over symbol names and inline docstrings. Used when the AI knows what it is looking for ("billing history filter") but not which file or function implements it. Returns a ranked list of matching nodes.

**`get_impact_radius_tool`** (all except DIFF-ONLY)  
Given a file path (or set of files being changed), returns all nodes that transitively depend on any symbol in those files, up to `max_hops`. This is the primary tool Claude Code uses to determine whether a change is truly isolated or touches something critical — and therefore what tier of test coverage to require.

**`query_graph_tool`** (BROAD + NARROW)  
Arbitrary graph traversal filtered by edge type. Used for targeted questions: "what SQL migrations does this service file touch?", "what routes invoke this repository function?", "which modules in the `infrastructure` domain depend on this config constant?"

**`get_review_context_tool`** (BROAD + DIFF-ONLY)  
Diff-focused summary: what changed, what that change calls, what calls it. Used on release branches where code writes are forbidden but review is permitted. Gives the AI the dependency context for a PR without traversing the full graph.

### Why `tools_permitted` Is Server-Side, Not Instruction-Side

The MCP server returns a capability error for any tool call not in the branch's `tools_permitted` list. This is not a CLAUDE.md instruction ("please don't call X") — it is a hard server refusal. The AI cannot call `get_architecture_overview_tool` on a hotfix branch regardless of what it wants to do.

This is the governance mechanism that makes branch strategies enforceable beyond developer trust: the AI's toolset is structurally narrowed by the branch it is working on.

---

## 3.9 Full Data Flow Diagram: From `git commit` to Atoms on Disk

```
Developer: git commit -m "feat: add billing report"
│
├─ git reads .git/config → core.hooksPath = .githooks
│
├─ git forks → exec .githooks/pre-commit
│   │
│   ├─ pre-commit sets GATE_TRIGGER=pre-commit
│   └─ pre-commit execs .githooks/gate.sh
│       │
│       ├─ set -euo pipefail; trap ERR
│       ├─ _verify_context_anchoring  (CLAUDE.md hash drift check)
│       │
│       ├─ STEP 1: git branch --show-current
│       │   ├─ check: main/master/develop → block
│       │   └─ check: code_writes_permitted in gate_state.json → block if false
│       │
│       ├─ STEP 2: Token harness
│       │   ├─ read: token.token_spent_today from gate_state.json
│       │   ├─ read: ~/.claude/org_policy.json for budget
│       │   ├─ date-roll reset if new day
│       │   └─ if IS_AGENT && budget_exhausted → block
│       │
│       ├─ STEP 3: Graph staleness
│       │   └─ if last_build >7 days ago → warn (no block)
│       │
│       ├─ STEP 4: Scan scope
│       │   ├─ LAST_SHA from gate_state.json → cold or incremental
│       │   ├─ git diff to get CHANGED_FILES
│       │   └─ classify: HAS_BACKEND / HAS_FRONTEND / CORE_FILES_TOUCHED
│       │
│       ├─ STEP 4.4: Brainstorming checkpoint
│       │   └─ if IS_AGENT && ≥5 changed files && no LATEST.md → block
│       │
│       ├─ STEP 4.5: Fingerprints
│       │   ├─ WORKING_TREE_FP = hash(HEAD tree + both diffs)
│       │   └─ COMMIT_TREE_FP = git write-tree
│       │
│       ├─ STEP 5: Secrets scan
│       │   └─ git diff --cached -p | grep patterns → block if found
│       │
│       ├─ STEP 6: Backend checks (if HAS_BACKEND)
│       │   ├─ lint (with brownfield ratchet)
│       │   ├─ type check
│       │   └─ STEP 6.5: layer boundary scan
│       │
│       ├─ STEP 7: Frontend checks (if HAS_FRONTEND)
│       │   ├─ frontend lint
│       │   └─ frontend type check
│       │
│       ├─ Test suite (if RUN_TESTS=true)
│       │   ├─ infer test command
│       │   ├─ run tests
│       │   ├─ check coverage ≥ threshold
│       │   └─ check complexity ≤ threshold
│       │
│       └─ STEP 8: Pass
│           ├─ _json_set last_pass_sha = HEAD_SHA
│           ├─ _receipt_write "$COMMIT_TREE_FP" "$CURRENT_BRANCH"
│           ├─ _ensure_graph_freshness (background rebuild)
│           ├─ _json_append_audit "pass"
│           └─ exit 0
│
├─ git receives exit 0
├─ git creates commit object (SHA = hash of tree + message + author + parent + timestamp)
├─ git advances branch pointer (HEAD → new commit SHA)
└─ git updates .git/refs/heads/feature/billing-report
```

The entire commit-to-disk flow takes approximately 90 seconds (plus test time if enabled).

---

<a name="module-4"></a>
# MODULE 4 — gate.sh: The Core Engine

**Prerequisite:** Modules 0, 1, 2, 3.  
**Time investment:** 10–15 hours. This is 40% of the entire curriculum.  
**This module walks through gate.sh line by line.** All 942 lines are explained. Code blocks are verbatim from the file at HEAD.

---

## 4.1 File Header and Stack-Specific Variables (Lines 1–24)

```bash
#!/usr/bin/env bash
# gate.sh — Claude Code enforcement gate (generated by install.sh, committed to .githooks/)
# Called by pre-commit and pre-push hooks. Never invoke directly in CI.
#
# STACK-SPECIFIC VARIABLES (filled by init — do not edit manually):
TEST_CMD="${TEST_CMD:-}"
LINT_CMD="${LINT_CMD:-}"
TYPE_CMD="${TYPE_CMD:-}"
COVERAGE_CMD="${COVERAGE_CMD:-}"
COMPLEXITY_CMD="${COMPLEXITY_CMD:-}"
FRONTEND_TEST_CMD="${FRONTEND_TEST_CMD:-}"
FRONTEND_LINT_CMD="${FRONTEND_TEST_CMD:-}"
FRONTEND_TYPE_CMD="${FRONTEND_TYPE_CMD:-}"
```

These variables are the gate's configuration interface. They allow the engineer who runs `install.sh` to specify exact commands for their stack. By default they are empty (`${VAR:-}` evaluates to empty string if VAR is unset).

The comment says "filled by init" — when running `install.sh` on a project, the init prompt asks the engineer to specify their test/lint/type-check commands, and those are filled in here.

**Why not hardcode `pytest`?** The gate serves Python, Java, Go, Rust, Node projects. Hardcoding `pytest` would fail on every non-Python project. Leaving them empty allows gate.sh to infer the right command dynamically (STEP 6, the `_infer_backend_test_cmd` function).

```bash
# TEST EXECUTION FLAG: Default = false (skip tests at pre-commit for speed)
RUN_TESTS="${RUN_TESTS:-false}"
# Allow override via commit message: [run-tests] keyword triggers test execution
if git log -1 --pretty=%B 2>/dev/null | grep -qiE '\[.*run-?tests.*\]|--run-?tests'; then
    RUN_TESTS="true"
fi
```

Tests are opt-in at pre-commit because they can take several minutes. The developer opts in per-commit using `[run-tests]` in the message. Tests are MANDATORY at pre-push time (set unconditionally on line 511).

---

## 4.2 set -euo pipefail (Line 26)

```bash
set -euo pipefail
```

This single line is gate.sh's safety foundation. See Module 0.6 for the full explanation. In the context of gate.sh specifically:

- **-e:** Any failing command immediately exits gate.sh. Since the ERR trap calls `exit 1`, every unexpected failure becomes a commit block.
- **-u:** Typos in variable names are caught immediately. `$GATE_STAET` would fail visibly instead of silently using an empty value.
- **-o pipefail:** The secrets scan pipeline (`git diff | grep | grep | grep -q`) propagates upstream failures. A failing `git diff` doesn't silently produce an empty pipeline that exits 0.

---

## 4.3 Constants Block (Lines 28–43)

```bash
GATE_STATE=".claude/gate_state.json"
SESSION_SPEND=".claude/session_spend.tmp"
GIT_CACHE=".claude/git_cache.json"
BASELINE=".claude/baseline.json"
ORG_POLICY="${HOME}/.claude/org_policy.json"
```

All file paths are centralized here. This means:
1. Every reference to these files in the script uses a named constant, not a string literal
2. If the path ever needs to change (e.g., migration from `.claude/` to `.github/`), it changes in ONE place
3. The paths are self-documenting: `$GATE_STATE` is more readable than `".claude/gate_state.json"` at the 15th usage

`$ORG_POLICY` uses `${HOME}` (the user's home directory) because it is a global configuration file shared across all repos on the machine, not per-repo state.

```bash
if [ -t 2 ]; then
    RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'; RESET='\033[0m'
else
    RED=''; YELLOW=''; GREEN=''; RESET=''
fi
```

ANSI color codes work by embedding escape sequences in strings. When printed to a real terminal (`[ -t 2 ]` = "is FD 2 a tty?"), the terminal interprets them as colors. When printed to a pipe, file, or IDE extension's output capture, they appear as garbage (`^[[0;31m`). The check disables them in non-TTY contexts.

---

## 4.4 ANSI Color Detection — The IDE Extension Problem

VS Code and other IDEs run git commands through a non-TTY wrapper. The stderr of hooks is captured and displayed in the IDE's "Source Control" pane. ANSI escape codes in that context render as raw text like `\033[0;31m`.

Even worse: some IDE terminals can freeze or truncate output when they encounter unexpected control characters.

The check `[ -t 2 ]` asks: "is file descriptor 2 (stderr) connected to a real terminal?" If yes, we are in a real terminal — colors work. If no, we are in an IDE extension / CI / pipe — use plain text.

This is why gate.sh's output looks colorful in your terminal but clean in VS Code's Git output pane.

---

## 4.5 Helper Functions: _json_get, _json_set — Why Not jq?

```bash
_json_get() {
    python3 -c "
import json, sys
with open('$1') as f:
    d = json.load(f)
keys = '$2'.split('.')
v = d
for k in keys:
    if k == '': break
    v = v.get(k, '')
print(v if v is not None else '')
" 2>/dev/null || echo ""
}
```

**Why Python3 instead of jq?** `jq` is not installed on many systems by default. Python3 is. Since gate.sh requires Python3 (used in multiple places: receipts, audit log, layer violations), the dependency is already paid. Adding jq as a required dependency would cause installations to fail on any system without it.

**Why not just write JSON in bash?** JSON manipulation in pure bash is painful. String escaping, nested structures, and atomic writes are hard. Python's `json` module handles all of these correctly.

**_json_get signature:** `_json_get <file> <dotted.key.path>`

```bash
_json_get "$GATE_STATE" "token.token_spent_today"  # reads .token.token_spent_today
_json_get "$GATE_STATE" "thresholds.coverage_pct"
```

The dotted path is split on `.` and traversed through the JSON dictionary.

```bash
_json_set() {
    python3 -c "
import json, sys
with open('$1') as f:
    d = json.load(f)
keys = '$2'.split('.')
obj = d
for k in keys[:-1]:
    obj = obj.setdefault(k, {})
val = '$3'
try:
    obj[keys[-1]] = json.loads(val)
except:
    obj[keys[-1]] = val
with open('$1', 'w') as f:
    json.dump(d, f, indent=2)
" 2>/dev/null
}
```

**_json_set** reads the entire JSON file, modifies one value, and writes the entire file back. This is not atomic in the POSIX sense (a crash between read and write could corrupt the file), but in practice, each gate.sh run is a single process that is highly unlikely to crash mid-write, and the file is small enough that the read-modify-write is instantaneous.

The `try: json.loads(val) / except: val` pattern handles both typed and string values:
- `_json_set file "key" "42"` → stores integer 42 (JSON parses "42" as an integer)
- `_json_set file "key" '"hello"'` → stores string "hello" (the JSON string `"hello"`)
- `_json_set file "key" "true"` → stores boolean true

### Python Mechanics Deep-Dive: keys[:-1] and setdefault()

A reader coming from six modules of bash will hit `keys[:-1]` and `obj.setdefault(k, {})` and find them opaque. Here is the full trace:

**Python slice notation:**
```python
keys = "last_pass_sha.feature/billing".split('.')
# → ["last_pass_sha", "feature/billing"]

keys[:-1]   # all elements except the last → ["last_pass_sha"]
keys[-1]    # last element only            → "feature/billing"
keys[1:]    # all elements except first    → ["feature/billing"]
```
The slice `[:-1]` means "from the start up to but not including the last." In `_json_set`, we need to walk down to the parent dict before setting the final key. `keys[:-1]` gives us the path to traverse; `keys[-1]` is the key we actually assign to.

**dict.setdefault(key, default):**
```python
d = {}
obj = d
obj = obj.setdefault("last_pass_sha", {})
# → "last_pass_sha" not in d, so d["last_pass_sha"] = {} is inserted
# → returns the new {}, which obj now points to
obj["feature/billing"] = "abc123"
# → d is now {"last_pass_sha": {"feature/billing": "abc123"}}
```
`setdefault` does two things in one call: if the key is absent it inserts `key: default` and returns `default`; if the key is present it returns the existing value without touching it. This means the loop is safe to call on a path that is partially or fully constructed — it never overwrites existing structure.

**Full trace of `_json_set gate_state.json "last_pass_sha.feature/billing" '"abc123"'`:**
```python
# Step 1: parse JSON
d = {"last_pass_sha": {}, "receipts": {}, ...}

# Step 2: split path
keys = ["last_pass_sha", "feature/billing"]

# Step 3: descend all-but-last
obj = d
for k in ["last_pass_sha"]:       # keys[:-1]
    obj = obj.setdefault(k, {})   # obj now points to d["last_pass_sha"] = {}

# Step 4: assign at the final key
val = '"abc123"'
obj["feature/billing"] = json.loads('"abc123"')   # → Python str "abc123"

# Step 5: d is now {"last_pass_sha": {"feature/billing": "abc123"}, ...}
# Step 6: write entire dict back to file
```

**Why not just `d["a"]["b"] = val`?** Because it raises `KeyError` if `d["a"]` doesn't exist yet. `setdefault` handles missing intermediate levels without needing to pre-check their existence.

---

## 4.6 _json_append_audit — The 90-Day Rolling Audit Log

```bash
_json_append_audit() {
    python3 -c "
import json, sys
from datetime import datetime, timedelta
with open('$GATE_STATE') as f:
    d = json.load(f)
entry = {'timestamp': '$1', 'trigger': '$2', 'spend_at_run': $3, 'outcome': '$4'}
log = d.get('token', {}).get('token_audit_log', [])
log.append(entry)
cutoff = (datetime.utcnow() - timedelta(days=90)).isoformat()
log = [e for e in log if e.get('timestamp','') >= cutoff]
d.setdefault('token', {})['token_audit_log'] = log
with open('$GATE_STATE', 'w') as f:
    json.dump(d, f, indent=2)
" 2>/dev/null
}
```

Called with: `_json_append_audit "$NOW_ISO" "$GATE_TRIGGER" "$TOTAL_SPENT" "pass"` or `"block:lint"`, `"timeout"`, etc.

The 90-day rolling window prevents unbounded growth: entries older than 90 days are pruned on every write. After 90 days, the log for a given commit is gone.

What the audit log records:
- **timestamp:** ISO 8601 UTC (from `date -u +%Y-%m-%dT%H:%M:%SZ`)
- **trigger:** `pre-commit` or `pre-push`
- **spend_at_run:** token spend at the time of this gate run
- **outcome:** `pass`, `pass:receipt`, `block:lint`, `block:secrets`, `block:layer-boundary`, `block:type`, `block:tests`, `block:coverage`, `block:complexity`, `hard_block`, `block:no-brainstorm-checkpoint`, `block:no-checkpoint`, `warn`, `timeout:<cmd>`

The audit log answers: "has this AI been burning budget efficiently? What's it blocking on most often?"

---

## 4.7 _verify_context_anchoring — CLAUDE.md Hash Drift Detection

```bash
_verify_context_anchoring() {
    [ -f "CLAUDE.md" ] || return 0
    [ -f "$GATE_STATE" ] || return 0
    _CA_HASH=$(sha256sum CLAUDE.md 2>/dev/null | awk '{print $1}' || \
               shasum -a 256 CLAUDE.md 2>/dev/null | awk '{print $1}' || echo "")
    [ -z "$_CA_HASH" ] && return 0
    _CA_STORED=$(_json_get "$GATE_STATE" "claude_md_hash")
    if [ -z "$_CA_STORED" ] || [ "$_CA_STORED" = "null" ]; then
        _json_set "$GATE_STATE" "claude_md_hash" "\"$_CA_HASH\""
        echo "GATE: CLAUDE.md anchored (${_CA_HASH:0:12})." >&2
    elif [ "$_CA_STORED" != "$_CA_HASH" ]; then
        echo -e "${YELLOW}⚠ GATE: CLAUDE.md changed since last verified pass — re-read it to refresh architectural alignment before proceeding.${RESET}" >&2
        _json_set "$GATE_STATE" "claude_md_hash" "\"$_CA_HASH\""
    fi
}
```

**The problem:** CLAUDE.md is the repository's engineering constitution. It defines layer boundaries, naming contracts, security invariants, and all the rules the AI agent must follow. If the AI changes CLAUDE.md (to relax rules), or if a human changes it (to add new rules), and the AI continues committing code without re-reading the updated constitution, it may be violating rules it doesn't know about.

**The mechanism:** Every time gate.sh runs a passing commit, it stores the SHA-256 hash of CLAUDE.md in `gate_state.json`. On subsequent runs, it compares the current hash to the stored hash. If they differ, CLAUDE.md changed since the last verified pass — the AI should re-read it.

This is a warning, not a block. The warning fires once (then the stored hash is updated) and disappears. But it shows up in the commit output, making the AI aware that its architectural context may be stale.

The dual `sha256sum`/`shasum -a 256` handles macOS (which uses `shasum`) vs Linux (which uses `sha256sum`).

---

## 4.8 _receipt_write and _receipt_has_pass — The Fingerprint Receipt System

```bash
_receipt_write() {
    [ -f "$GATE_STATE" ] || return 0
    [ -n "$1" ] || return 0
    python3 -c "
import json
from datetime import datetime, timezone
with open('$GATE_STATE') as f:
    d = json.load(f)
r = d.setdefault('receipts', {})
r['$1'] = {'timestamp': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'), 'branch': '$2', 'outcome': 'pass'}
if len(r) > 50:
    keep = sorted(r.items(), key=lambda kv: kv[1].get('timestamp',''), reverse=True)[:50]
    d['receipts'] = dict(keep)
with open('$GATE_STATE', 'w') as f:
    json.dump(d, f, indent=2)
" 2>/dev/null
}
```

Called as `_receipt_write "$COMMIT_TREE_FP" "$CURRENT_BRANCH"` in STEP 8.

The receipt is keyed by `$COMMIT_TREE_FP` = `git write-tree` at pre-commit time. The value is a dict with timestamp, branch, and outcome.

**The 50-receipt bound:** `if len(r) > 50:` When the ledger exceeds 50 entries, keep only the 50 most recent (sorted by timestamp descending). This prevents `gate_state.json` from growing without bound on a project with many commits.

A 51st commit causes the oldest receipt to be pruned. If that old commit is somehow pushed more than 50 commits later without any intermediate push, the receipt is gone and the full gate re-runs at push time. This is the correct degraded behavior: fall back to full verification, not silent pass.

```bash
_receipt_has_pass() {
    if [ ! -f "$GATE_STATE" ] || [ -z "$1" ]; then echo "no"; return 0; fi
    python3 -c "
import json
try:
    with open('$GATE_STATE') as f:
        d = json.load(f)
    r = d.get('receipts', {}).get('$1', {})
    print('yes' if r.get('outcome') == 'pass' else 'no')
except Exception:
    print('no')
" 2>/dev/null || echo "no"
}
```

Returns `"yes"` or `"no"`. Called at STEP 4.5 during pre-push. The `|| echo "no"` ensures that any failure (Python3 crash, JSON parse error) returns "no" — triggering a full re-run rather than a silent pass.

---

## 4.9 _ensure_graph_freshness — The Kill-Restart Lifecycle (Commit 630d3ad)

```bash
_ensure_graph_freshness() {
    [ -f ".mcp.json" ] || return 0
    command -v code-review-graph >/dev/null 2>&1 || return 0
    _GF_HIT=$(echo "$CHANGED_FILES" | grep -E '\.(ts|tsx|py|go|java)$' | head -1 || true)
    [ -n "$_GF_HIT" ] || return 0
    _GF_PID_FILE=".claude/graph.pid"
    if [ -f "$_GF_PID_FILE" ]; then
        _GF_PID=$(cat "$_GF_PID_FILE" 2>/dev/null)
        if [ -n "$_GF_PID" ] && kill -0 "$_GF_PID" 2>/dev/null; then
            echo -e "${YELLOW}[GRAPH GUARD] Active indexer obsolete. Terminating stale process and restarting build for current HEAD...${RESET}" >&2
            kill -9 "$_GF_PID" 2>/dev/null || true
        fi
        rm -f "$_GF_PID_FILE"
    fi
    nohup bash -c "code-review-graph build > /dev/null 2>&1; rm -f '$_GF_PID_FILE'" > /dev/null 2>&1 &
    echo $! > "$_GF_PID_FILE"
    echo -e "${GREEN}GATE: graph index refreshing in background.${RESET}" >&2
}
```

**Why this was added in commit 630d3ad:** Before this fix, if a developer made two commits in quick succession:
1. Commit A: gate.sh spawns a graph rebuild background process (PID 1234)
2. Commit B (30 seconds later): graph rebuild for commit A is still running
3. gate.sh would spawn a SECOND rebuild (PID 1235) for commit B
4. PID 1234 finishes, writes a graph based on commit A's state — **stale**
5. PID 1235 finishes, overwrites with commit B's state — correct

But PID 1234 and PID 1235 race. If PID 1235 finishes first (unlikely but possible on large repos), PID 1234 finishes second and overwrites with the wrong state.

**The fix:** Before spawning a new rebuild, check `.claude/graph.pid` for a running process. Kill it (`kill -9`) before starting fresh. No race condition is possible — there is always at most one running rebuild.

`kill -0 "$PID"` checks if the process exists without killing it. `kill -9 "$PID"` sends SIGKILL (uncatchable terminate signal).

`nohup ... &` runs the command immune to SIGHUP (terminal close), detached from the foreground. The `$!` captures the PID of the last backgrounded process.

---

## 4.10 _is_claude_agent_process — OS Process Tree Traversal

```bash
_is_claude_agent_process() {
    IS_AGENT=false
    CURRENT_PID=$PPID
    while [ "${CURRENT_PID:-0}" -gt 1 ] 2>/dev/null; do
        _AP_CMD=$(ps -p "$CURRENT_PID" -o command= 2>/dev/null | tr -d '\n' || echo "")
        if echo "$_AP_CMD" | grep -qE '@anthropic-ai/claude-code|claude-code'; then
            IS_AGENT=true
            break
        fi
        _AP_PPID=$(ps -p "$CURRENT_PID" -o ppid= 2>/dev/null | tr -d ' \n' || echo "0")
        [ -z "$_AP_PPID" ] || [ "$_AP_PPID" = "0" ] && break
        CURRENT_PID=$_AP_PPID
    done
}
```

**What it does:** Traverses the process tree from `$PPID` (gate.sh's parent = git) toward PID 1 (init). For each ancestor, it asks `ps` for the command name and checks if it contains `claude-code` or `@anthropic-ai/claude-code`.

**Why traversal instead of checking one level?**
Claude Code spawns many sub-processes:
```
claude-code (PID 100)
  └── node (PID 101) — the actual runtime
       └── bash (PID 102) — tool execution
            └── git commit (PID 103)
                 └── gate.sh (PID 104) — PPID = 103
```

If gate.sh only checked PPID (103 = git), it would miss the Claude Code ancestry. The traversal finds it at PID 100.

**Why `ps -p "$CURRENT_PID" -o command=`?** `ps -p` shows a specific PID. `-o command=` shows only the command column (no header). This works on both macOS (BSD ps) and Linux (GNU ps).

**The `2>/dev/null` guards:** ps may fail if the process exited between iterations. The `|| echo ""` converts any ps failure to an empty string. `echo "$_AP_CMD" | grep -q` safely handles empty strings.

---

## 4.11 _run_with_timeout — The 30-Second Budget Per Command

```bash
_run_with_timeout() {
    local timeout_sec cmd_label
    timeout_sec=$(_json_get "$GATE_STATE" "thresholds.command_timeout_sec")
    timeout_sec="${timeout_sec:-30}"
    cmd_label="$1"; shift
    if command -v timeout >/dev/null 2>&1; then
        if ! timeout "$timeout_sec" "$@" 2>&1; then
            local exit_code=$?
            if [ $exit_code -eq 124 ]; then
                echo -e "${YELLOW}⚠ TIMEOUT: '$cmd_label' exceeded ${timeout_sec}s — killed and logged${RESET}" >&2
                _json_append_audit "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "timeout" 0 "timeout:${cmd_label}"
                return 1
            fi
            return $exit_code
        fi
    else
        "$@"
    fi
}
```

**Why timeout per command?** A test suite or linter on a large repo can run for minutes. The gate is supposed to be a fast check, not a 10-minute blocking operation. The configurable timeout (default: 30 seconds) kills commands that take too long and logs the timeout to the audit log.

**Exit code 124** is the specific exit code `timeout(1)` returns when it kills a command. This distinguishes "timed out" from "command failed" (any other non-zero exit).

The `command -v timeout` check handles macOS, which historically lacked `timeout` (it's installed by Homebrew). If `timeout` is not available, the command runs without a limit. On modern macOS with Homebrew's coreutils, `timeout` is available.

---

## 4.12 Crash Guard and ERR Trap — Why Every Unhandled Error Must Block

```bash
_crash_handler() {
    echo -e "${RED}GATE CRASH at line $1 — exit $2. Commit blocked. Fix gate.sh or contact platform team.${RESET}" >&2
    exit 1
}
trap '_crash_handler ${LINENO} $?' ERR
```

This is the most important safety mechanism in gate.sh. Without it:
- If Python3 crashes mid-execution, bash's `set -e` triggers and gate.sh exits non-zero
- BUT: the exit code from Python3 might be 1 (which blocks the commit) OR it might be something weird that gate.sh's `set -e` doesn't treat as a hard failure
- More importantly: the developer sees nothing useful. "Process exited with code 1" is not helpful.

With the ERR trap:
- ANY unexpected non-zero exit fires `_crash_handler`
- `${LINENO}` captures the EXACT LINE that failed
- `$?` captures the EXACT EXIT CODE
- The output is a clear, human-readable message: "GATE CRASH at line 347 — exit 2"
- The commit is blocked (`exit 1`)

The invariant: **gate.sh never silently passes a commit on an internal error.** Any unexpected failure is a block, never a pass.

---

## 4.13 STEP 1: Branch Validation and code_writes_permitted Enforcement (Lines 235–267)

```bash
CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "")
if [[ "$CURRENT_BRANCH" =~ ^(main|master|develop)$ ]]; then
    echo -e "${RED}BRANCH BLOCK: Direct commits to '$CURRENT_BRANCH' are forbidden.${RESET}" >&2
    echo "Create a feature/bugfix/hotfix/release branch." >&2
    exit 1
fi

BRANCH_PREFIX="${CURRENT_BRANCH%%/*}"
```

`${CURRENT_BRANCH%%/*}` removes the longest suffix matching `/*` — so `feature/my-thing` becomes `feature`, `release/v1.0` becomes `release`.

```bash
if [ -f "$GATE_STATE" ]; then
    _CWP=$(python3 -c "
import json, sys
try:
    with open(sys.argv[1]) as f:
        d = json.load(f)
    s = d.get('branch_strategy', {}).get(sys.argv[2], {})
    print('false' if s.get('code_writes_permitted') is False else 'true')
except Exception:
    print('true')
" "$GATE_STATE" "$BRANCH_PREFIX" 2>/dev/null || echo "true")
    if [ "$_CWP" = "false" ]; then
        echo -e "${RED}BRANCH BLOCK: Branch '$CURRENT_BRANCH' has code_writes_permitted=false.${RESET}" >&2
        exit 1
    fi
fi
```

`code_writes_permitted` is explicitly checked with `is False` (Python identity check). The default-to-true behavior (`'true'` in the except clause) means: if the key is absent, writes are permitted. Only explicit `false` blocks.

Why two layers of protection (Claude Code PreToolUse hook + gate.sh STEP 1)?
- Claude Code hook: blocks BEFORE files are written (the AI can't create commits on release branches)
- gate.sh STEP 1: blocks AFTER files are written but BEFORE commit is recorded (defense-in-depth if hook is bypassed)

---

## 4.14 STEP 2: Token Harness — Daily Budget and Spend Tracking (Lines 269–366)

The token harness is gate.sh's most complex step. It implements:
1. Reading the daily budget from org_policy.json and gate_state.json
2. Date-roll reset (midnight rollover)
3. Session spend accumulation
4. Hard block for AI sessions exceeding budget
5. Warning for human commits when budget is exhausted
6. 80% warning (once per day)

### Budget resolution chain

```bash
# Org-level: from ~/.claude/org_policy.json
ORG_BUDGET = weekly_limit × daily_budget_pct ÷ 100

# Repo-level: from .claude/gate_state.json
TOKEN_BUDGET = gate_state.token.token_budget

# Resolution: org ceiling wins if lower
effective_budget = min(ORG_BUDGET, TOKEN_BUDGET) if both set
effective_budget = TOKEN_BUDGET if only repo set
effective_budget = ORG_BUDGET if only org set
effective_budget = 200000 if neither set (fallback)
```

### Date-roll reset

```bash
TODAY=$(date +%Y-%m-%d)
if [ "$LAST_RESET" != "$TODAY" ]; then
    _json_set "$GATE_STATE" "token.token_spent_today" "0"
    _json_set "$GATE_STATE" "token.token_last_reset" "\"$TODAY\""
fi
```

Simple and reliable: compare today's date string to the stored reset date. If they differ, it's a new day — reset the counter. No timezone complexity; `date +%Y-%m-%d` uses the local timezone, which is what the developer's day corresponds to.

### Human vs. AI commit distinction

```bash
SESSION_SPEND_VAL=0
if [ -f "$SESSION_SPEND" ]; then
    SESSION_SPEND_VAL=$(cat "$SESSION_SPEND" 2>/dev/null | tr -cd '0-9' || echo "0")
fi

TOTAL_SPENT=$(( SPENT_TODAY + SESSION_SPEND_VAL ))

if [ "$TOKEN_BUDGET" -gt 0 ] 2>/dev/null; then
    PCT=$(( TOTAL_SPENT * 100 / TOKEN_BUDGET ))
    if [ "$PCT" -ge 100 ]; then
        if [ "${SESSION_SPEND_VAL:-0}" -gt 0 ] 2>/dev/null; then
            # Active Claude session — BLOCK
            exit 1
        else
            # No active session — WARN only (human commit)
        fi
    fi
fi
```

The distinction is `SESSION_SPEND_VAL > 0`. The file `.claude/session_spend.tmp` is written by Claude Code during a session to record how many tokens the current session has consumed. If this file doesn't exist or contains 0, gate.sh concludes this is a human-authored commit (not from an active AI session) and does not block.

This is a deliberate design choice: **never block a human developer because an AI was profligate.** The human should be able to commit even if the AI exhausted the day's budget. Only new AI-session-based commits are blocked.

---

## 4.15 STEP 3: Secret Scanning — What Patterns Are Caught and Why (Lines 515–528)

```bash
SECRETS_FOUND=0
if git diff --cached --diff-filter=ACMR -p 2>/dev/null | \
    grep -iE '(api[_-]?key|secret|password|token|private[_-]?key|aws_access|BEGIN (RSA|EC|OPENSSH|PGP))' 2>/dev/null | \
    grep -v '^---\|^+++\|^@@\|^#\|placeholder\|example\|REDACTED' 2>/dev/null | \
    grep -q .; then
    SECRETS_FOUND=1
fi
```

### What each stage does

**Stage 1: `git diff --cached --diff-filter=ACMR -p`**  
Gets the full patch of staged changes. `--diff-filter=ACMR` includes only Added, Copied, Modified, Renamed files — not Deleted files (a deleted file containing a secret is being removed, which is good).

**Stage 2: `grep -iE '(api[_-]?key|...|BEGIN (RSA|EC|OPENSSH|PGP))'`**  
Matches lines containing secret-looking patterns. `-i` = case-insensitive. The patterns cover:
- Variable names: `API_KEY`, `api-key`, `PASSWORD`, `SECRET`
- AWS credentials: `AWS_ACCESS`
- Private keys: `BEGIN RSA PRIVATE KEY`, `BEGIN EC PRIVATE KEY`, etc.

**Stage 3: `grep -v '^---\|^+++\|^@@\|^#\|placeholder\|example\|REDACTED'`**  
Removes false positives:
- `^---` and `^+++` are diff header lines (not actual content)
- `^@@` is a diff hunk header
- `^#` is a comment line
- Lines containing `placeholder`, `example`, or `REDACTED` are documentation/examples

**Stage 4: `grep -q .`**  
Exits 0 if ANY line survived the pipeline (secret found). Exits 1 if nothing (no secret).

### False positive rate

The pattern is intentionally broad: it will flag `api_key = "test"` in test fixtures. This is a good default — better to flag and let the developer explicitly suppress (by adding `# REDACTED` or `# example`) than to miss a real credential.

---

## 4.16 STEP 4: Changed File Detection and Tiered Analysis Selection (Lines 391–418)

```bash
LAST_SHA=""
if [ -f "$GATE_STATE" ]; then
    LAST_SHA=$(_json_get "$GATE_STATE" "last_pass_sha")
fi

HEAD_SHA=$(git rev-parse HEAD 2>/dev/null || echo "INIT")

if [ -z "$LAST_SHA" ] || [ "$LAST_SHA" = "null" ] || [ "$LAST_SHA" = "" ]; then
    echo "GATE: cold start — full scan" >&2
    CHANGED_FILES=$(git diff --cached --name-only 2>/dev/null)
    SCAN_MODE="cold"
else
    CHANGED_FILES=$(git diff --name-only "${LAST_SHA}..HEAD" 2>/dev/null)
    STAGED_FILES=$(git diff --cached --name-only 2>/dev/null)
    CHANGED_FILES=$(echo -e "${CHANGED_FILES}\n${STAGED_FILES}" | sort -u | grep -v '^$')
    SCAN_MODE="incremental"
fi
```

**Cold start:** First commit ever (or after reset). `last_pass_sha` is null. Uses `git diff --cached` to see what's staged.

**Incremental:** Has a `last_pass_sha`. Uses `git diff LAST_SHA..HEAD` to see all commits since the last gate pass, UNION'd with currently staged files. The union ensures we catch files that changed in previous commits but weren't yet fully analyzed (e.g., if a commit was bypassed and then revisited).

```bash
HAS_BACKEND=false; HAS_FRONTEND=false
while IFS= read -r f; do
    [[ "$f" == backend/* ]] || [[ "$f" == src/* ]] || [[ "$f" == app/* ]] || \
    [[ "$f" == *.py ]] || [[ "$f" == *.java ]] || [[ "$f" == *.go ]] || \
    [[ "$f" == *.rs ]] && HAS_BACKEND=true
    [[ "$f" == frontend/* ]] || [[ "$f" == *.tsx ]] || [[ "$f" == *.ts ]] || \
    [[ "$f" == *.jsx ]] && HAS_FRONTEND=true
done <<< "$CHANGED_FILES"
```

The `&&` chains: because of bash operator precedence, this is evaluated as:
```
([[ condition1 ]] || [[ condition2 ]] || ... || [[ conditionN ]]) && HAS_BACKEND=true
```
If ANY condition on the left side is true, `HAS_BACKEND=true` runs.

---

## 4.17 STEP 4.3: Core Files Detection — Tier 3 Forced Escalation (Lines 421–442)

```bash
CORE_FILES_TOUCHED=false
if [ -f "$GATE_STATE" ]; then
    CORE_MATCH=$(python3 -c "
import json, fnmatch
try:
    with open('$GATE_STATE') as f:
        d = json.load(f)
    patterns = d.get('core_files', []) or []
    changed = '''$CHANGED_FILES'''.split('\n')
    hit = next((c for c in changed if c and any(fnmatch.fnmatch(c, p) for p in patterns)), '')
    print(hit)
except Exception:
    print('')
" 2>/dev/null || echo "")
    if [ -n "$CORE_MATCH" ]; then
        CORE_FILES_TOUCHED=true
        RUN_TESTS="true"   # Mandatory tests on core file changes
    fi
fi
```

**Core files** are glob patterns stored in `gate_state.json.core_files`. Examples:
```json
{
  "core_files": [
    "app/dependencies/**",
    "config.py",
    "app/repositories/kpi_repository.py"
  ]
}
```

If any changed file matches any glob (using `fnmatch` — the same module that powers `*.py` style patterns), the gate escalates to TIER-3: full test suite + mandatory test run.

The design intent: some files are so architecturally central (auth middleware, database connection config, the core repository pattern) that any change to them demands the most thorough verification. This list is maintained by humans via PR — not by the AI.

---

## 4.18 STEP 4.4: Tier 3+ Brainstorming Hard Block (Lines 444–459)

```bash
if [ "$GATE_TRIGGER" = "pre-commit" ]; then
    _is_claude_agent_process
    if [ "$IS_AGENT" = "true" ]; then
        _T3_COUNT=$(echo "$CHANGED_FILES" | grep -c . 2>/dev/null || echo "0")
        _T3_CKPT=".claude/checkpoints/LATEST.md"
        if [ "${_T3_COUNT:-0}" -ge 5 ] && [ ! -f "$_T3_CKPT" ]; then
            echo -e "${RED}PRE-COMMIT BLOCK: Tier 3+ change footprint (${_T3_COUNT} files) with no brainstorming checkpoint.${RESET}" >&2
            exit 1
        fi
    fi
fi
```

**What this enforces:** An AI agent changing 5+ files must have written a design brief to `.claude/checkpoints/LATEST.md` before committing.

**Why 5 files?** Changing 1–4 files might be a targeted bug fix (NARROW strategy — legitimate). Changing 5+ files is architectural work (BROAD strategy) that requires prior reasoning. Without this check, an AI could dive straight into refactoring a dozen files across layers without ever articulating what it's doing and why.

**Why only for agents?** Human developers are not forced to write design documents for every commit. The `_is_claude_agent_process` check ensures this block only applies to AI-driven commits.

---

## 4.19 STEP 4.5: Fingerprint Forms — WORKING_TREE_FP and COMMIT_TREE_FP (Lines 461–481)

```bash
WORKING_TREE_FP=""
COMMIT_TREE_FP=""
WORKING_TREE_FP=$( { git rev-parse 'HEAD^{tree}' 2>/dev/null; git diff -p 2>/dev/null; git diff --cached -p 2>/dev/null; } | shasum 2>/dev/null | awk '{print $1}' || echo "")

if [ "$GATE_TRIGGER" = "pre-push" ]; then
    COMMIT_TREE_FP=$(git rev-parse 'HEAD^{tree}' 2>/dev/null || echo "")
    if [ "$(_receipt_has_pass "$COMMIT_TREE_FP")" = "yes" ]; then
        echo -e "${GREEN}GATE: pre-push receipt verified for tree ${COMMIT_TREE_FP:0:12} — checks already passed at commit.${RESET}" >&2
        _json_append_audit "$NOW_ISO" "$GATE_TRIGGER" "$TOTAL_SPENT" "pass:receipt"
        exit 0
    fi
    RUN_TESTS="true"
else
    COMMIT_TREE_FP=$(git write-tree 2>/dev/null || echo "")
fi
```

**WORKING_TREE_FP:** Hash of (HEAD tree SHA + unstaged diff + staged diff). This captures the exact working state — including uncommitted changes. Used for in-session deduplication: "I already checked this exact combination of files."

**COMMIT_TREE_FP:**
- At **pre-commit** time: `git write-tree` — the SHA of what's in the staging area (what will be committed)
- At **pre-push** time: `git rev-parse HEAD^{tree}` — the SHA of what was committed (the last commit's tree)

At pre-push, if the receipt exists for this tree, **the entire remainder of gate.sh is skipped** (exit 0). This is the fast path that makes pushes nearly instantaneous after a gate-verified commit.

If no receipt: `RUN_TESTS="true"` — the push-time full verification also runs tests. Why? If pre-commit was bypassed (SKIP_GATE=1), there is no receipt. Pre-push catches this and runs the full gate including tests. This prevents the bypass from persisting past the push.

---

## 4.20 STEP 4.6: Pre-Push Checkpoint Gate (Lines 483–508)

```bash
if [ "$GATE_TRIGGER" = "pre-push" ]; then
    _is_claude_agent_process
    if [ "$IS_AGENT" = "true" ]; then
        _CKPT=".claude/checkpoints/LATEST.md"
        _PP_SRC=$(echo "$CHANGED_FILES" | grep -E '\.(ts|tsx|py|go|java|rb|rs|c|cpp|h|cs|swift|kt)$' | head -1 || true)
        if [ -n "$_PP_SRC" ]; then
            if [ ! -f "$_CKPT" ]; then
                echo -e "${RED}PUSH GATING FAILURE: Agent push modifies source files without a checkpoint.${RESET}" >&2
                exit 1
            fi
            _CKPT_LAST_COMMIT=$(git log -1 --format=%ct 2>/dev/null || echo "0")
            _CKPT_MTIME=$(stat -f %m "$_CKPT" 2>/dev/null || stat -c %Y "$_CKPT" 2>/dev/null || echo "0")
            if [ "${_CKPT_MTIME:-0}" -lt "${_CKPT_LAST_COMMIT:-1}" ] 2>/dev/null; then
                echo -e "${YELLOW}⚠ GATE: checkpoint predates the latest commit${RESET}" >&2
            fi
        fi
    fi
fi
```

The dual `stat` (`-f %m` for macOS, `-c %Y` for Linux) gets the file modification time in epoch seconds. The check `_CKPT_MTIME < _CKPT_LAST_COMMIT` warns if the checkpoint was written before the last commit — meaning the agent made commits after writing the checkpoint without updating it.

This is a warning, not a block, to avoid being overly strict on fast-moving development.

---

## 4.21 STEP 6: Lint + Brownfield Ratchet + Type Check + Layer Boundary (Lines 683–817)

### The identity-based brownfield ratchet

```bash
RATCHET_ACTIVE=$(python3 -c "
import json
try:
    with open('$BASELINE') as f: b = json.load(f)
    print('true' if b.get('populated') and isinstance(b.get('lint_findings'), list) else 'false')
except Exception:
    print('false')
" 2>/dev/null || echo "false")
```

The ratchet activates only when `baseline.json` has `"populated": true` and a `lint_findings` list. Greenfield projects start with `populated: false` and use zero-tolerance (any lint failure blocks).

```bash
if [ "$RATCHET_ACTIVE" = "true" ]; then
    NEW_FINDINGS=$(python3 -c "
import json, re, sys
with open('$BASELINE') as f: b = json.load(f)
baseline = set(b.get('lint_findings', []))
new = []
for line in '''$LINT_OUTPUT'''.splitlines():
    m = re.match(r'^([^:]+):\d+:\d+:\s+([A-Z]+[0-9]+)', line.strip())
    if not m:
        continue
    ident = m.group(1) + '|' + m.group(2)
    if ident not in baseline:
        new.append(ident)
for n in sorted(set(new)):
    print(n)
" 2>/dev/null || echo "__PARSE_FAIL__")
```

**Identity = `<normalized_path>|<rule_code>`** — not line number. A rule code like `E501` (line too long) on `app/routes/kpis.py` = identity `app/routes/kpis.py|E501`. 

Why exclude line numbers? If a developer adds 5 lines of comments above an existing lint error, the error's line number changes. It would appear as a new finding (different line) even though it's the same pre-existing violation. Identity-based matching handles this correctly.

### Layer boundary scan

The layer boundary scan is STEP 6.5, explained fully in Module 2.5 (it catches SQL in route files and HTTP imports in service files). The actual code is at lines 760–817, shown verbatim in the earlier reading of gate.sh.

---

## 4.22 STEP 8: Receipt Write and Final Pass Output (Lines 918–942)

```bash
if [ -f "$GATE_STATE" ]; then
    _json_set "$GATE_STATE" "last_pass_sha" "\"${HEAD_SHA}\""
    _json_set "$GATE_STATE" "last_pass_timestamp" "\"${NOW_ISO}\""
    _json_set "$GATE_STATE" "token.token_spent_today" "$TOTAL_SPENT"
    rm -f "$SESSION_SPEND"
fi

if [ -n "$COMMIT_TREE_FP" ]; then
    _receipt_write "$COMMIT_TREE_FP" "$CURRENT_BRANCH"
fi

_ensure_graph_freshness

_json_append_audit "$NOW_ISO" "$GATE_TRIGGER" "$TOTAL_SPENT" "pass"

echo -e "${GREEN}GATE PASS: all checks clean | branch=${CURRENT_BRANCH} | mode=${SCAN_MODE} | tier3=${CORE_FILES_TOUCHED} | token=${TOTAL_SPENT}/${TOKEN_BUDGET}${RESET}" >&2
exit 0
```

The PASS output line is a formatted summary: branch name, scan mode (cold/incremental), whether tier-3 was triggered, and token usage. This makes it easy to audit what the gate checked and what it skipped.

**`rm -f "$SESSION_SPEND"`:** Clears the session token spend file after it's been accumulated into `token.token_spent_today`. This ensures the same session spend isn't double-counted on a subsequent commit in the same session.

**`_ensure_graph_freshness`:** Triggered on PASS only. If a commit was blocked (and gate.sh exited early), we don't rebuild the graph — there's nothing new to index. Only verified-passing commits trigger a graph rebuild.

**`exit 0`:** The commit is allowed to proceed.

---


<a name="module-5"></a>
# MODULE 5 — gate_state.json: The State Machine

**Prerequisite:** Module 4 (you've seen every field being read and written).  
**Time investment:** 2–3 hours.  
**Why a dedicated module:** Every decision in this file's schema has a reason. Understanding the schema is understanding the system's memory.

---

## 5.1 Why a File-Based State Machine Instead of a Database

The gate runs millions of times across thousands of developer machines. A database (Postgres, SQLite, Redis) would require:
- A running server (operational burden)
- Network access for cloud DB (dependency + latency)
- Credentials (security surface)
- Backup/restore plan

A JSON file requires nothing. It travels with the repo. It is read by every gate.sh instance, on every machine, offline, with zero infrastructure. The cost: no concurrent writes from multiple processes (not needed here — one developer makes one commit at a time), no query language (Python dict access is sufficient), no indexing (50 receipts is a tiny dataset).

The tradeoff is deliberate: **simplicity and portability over scalability.**

---

## 5.2 The Receipts Ledger — Keying by Tree Hash, Not Commit Hash

```json
{
  "_receipts_comment": "Keyed by COMMIT_TREE_FP (git tree hash of the committed index). Written by pre-commit after all checks pass; verified by pre-push. Never keyed by the working-tree fingerprint.",
  "receipts": {}
}
```

The comment on `_receipts_comment` is documentation baked into the JSON file itself. It warns against the most likely mistake: keying by commit hash or working-tree hash.

Why not commit hash:
- Commit hashes change on `git commit --amend` (even message-only amendments)
- This would invalidate the receipt for an amended message, forcing a full re-run unnecessarily

Why not working-tree hash:
- The working tree may have uncommitted changes
- A receipt should prove "this set of committed files was verified" — not "my working directory looked like this"

The tree hash is the right key because it is:
- Stable across message amendments and rebases (as long as file content doesn't change)
- Changed whenever file content changes (so stale receipts are automatically invalidated)

---

## 5.3 The branch_strategy Schema — Four Strategies, Their Constraints

```json
{
  "branch_strategy": {
    "feature": {
      "strategy_name": "BROAD",
      "max_hops": null,
      "tools_permitted": ["get_architecture_overview_tool", "semantic_search_nodes_tool", "get_impact_radius_tool", "query_graph_tool", "get_review_context_tool"],
      "architecture_overview_required": true
    },
    "bugfix": {
      "strategy_name": "NARROW",
      "max_hops": 2,
      "tools_permitted": ["get_impact_radius_tool", "query_graph_tool"],
      "architecture_overview_required": false
    },
    "hotfix": {
      "strategy_name": "ULTRA-NARROW",
      "max_hops": 1,
      "tools_permitted": ["get_impact_radius_tool"],
      "architecture_overview_required": false
    },
    "release": {
      "strategy_name": "DIFF-ONLY",
      "max_hops": null,
      "tools_permitted": ["get_review_context_tool"],
      "architecture_overview_required": false,
      "code_writes_permitted": false
    }
  }
}
```

**BROAD (feature):** All MCP tools available. Architecture overview required before coding. No hop limit on graph traversal. Full test suite.

**NARROW (bugfix):** Only impact radius and graph query tools (no architecture overview). max_hops=2 means the AI can only follow 2 levels of dependency from the changed file. Targeted fix — don't rewrite unrelated things.

**ULTRA-NARROW (hotfix):** Only impact radius, max_hops=1. This is a production emergency. Change the minimum possible. One hop means: only the direct callers/callees of the changed function.

**DIFF-ONLY (release):** No code writes. Review only. This branch type is for release preparation — reviewing, tagging, documentation. No new code goes in directly; everything goes through feature branches and merges.

The `code_writes_permitted: false` on release is the only field gate.sh actually enforces via STEP 1. The other fields (`tools_permitted`, `max_hops`) are enforced by the MCP graph server — the AI agent's toolset is constrained based on the branch type read from `gate_state.json`.

---

## 5.4 The Token Block — Budget, Spend, Reset, Audit Log

```json
{
  "token": {
    "_comment": "Daily budget computed from ~/.claude/org_policy.json: WEEKLY_LIMIT × DAILY_BUDGET_PCT ÷ 100.",
    "token_budget": null,
    "token_spent_today": 0,
    "token_last_reset": null,
    "token_audit_log": []
  }
}
```

`token_budget: null` means "use org policy." A non-null value overrides the org policy for this specific repo (but the org ceiling still wins if lower).

`token_spent_today` is reset to 0 every day. The reset is triggered by STEP 2 comparing `token_last_reset` to `date +%Y-%m-%d`.

`token_audit_log` is a rolling 90-day list of gate run outcomes with timestamps. Pruned on every write by `_json_append_audit`.

---

## 5.5 The mcp_graph Block — Config Path, Build Timestamp, Domain Coverage

```json
{
  "mcp_graph": {
    "config_path": ".mcp.json",
    "last_build_timestamp": null,
    "node_count": 0,
    "included_domains": [
      "application_code",
      "sql_migrations",
      "orm_models",
      "infrastructure",
      "ci_cd",
      "proxy_config",
      "env_contracts"
    ]
  }
}
```

`last_build_timestamp` is read by STEP 3 to detect staleness (>7 days). It is written by the `code-review-graph build` process after a successful rebuild.

`included_domains` tells the graph builder which parts of the codebase to index. A graph that only indexes `application_code` would miss the fact that a service function change affects a SQL migration — because migrations aren't indexed.

---

## 5.5.1 The execution_mode_log Field — Reserved Schema Slot

```json
{
  "execution_mode_log": []
}
```

This field appears in every `gate_state.json` scaffolded by install.sh. It is **not read or written by gate.sh v1.0**. The array will remain empty in your installation unless you extend the framework.

**What it is reserved for:** The engineering guide (the implementation package for engineers) defines three execution modes that the AI declares at the start of every response:
- `MUST OUTPUT` — a read-only recon pass with no side effects
- `HARD STOP` — the AI has detected a condition requiring human approval before continuing
- `EXECUTE` — a write pass that will modify files

`execution_mode_log` is the schema slot for a future gate feature that would record which mode each agent session declared, making it auditable that the AI followed the declared mode for each run. The field is scaffolded now so a future gate version can start writing it without a schema migration.

**Practical consequence:** If you are reading `gate_state.json` and see `"execution_mode_log": []`, this is correct. It is not a bug or an indication that something failed to run.

---

## 5.6 The Thresholds Block — coverage_pct, complexity_max, Timeouts

```json
{
  "thresholds": {
    "coverage_pct": 80,
    "complexity_max": 10,
    "command_timeout_sec": 30,
    "git_cache_ttl_sec": 60
  }
}
```

These four values control the gate's quantitative checks:

- **coverage_pct:** Test coverage must be at least this percentage. Lowering it requires a human PR to `gate_state.json`.
- **complexity_max:** Cyclomatic complexity (measured by `radon cc`) must not exceed this. A value of 10 means functions with >10 independent paths are blocked.
- **command_timeout_sec:** Used by `_run_with_timeout`. 30 seconds per command.
- **git_cache_ttl_sec:** How long git output is cached to avoid re-running expensive git commands within the same gate run.

Changing these values requires a human PR because they are agent-immutable. An AI agent that wants to allow lower coverage cannot lower this value itself; it would be blocked by the gate.

---

## 5.7 Core Files Glob Patterns — What Forces Tier 3

```json
{
  "core_files": [],
  "_core_files_comment": "Glob patterns (fnmatch) for architecture-critical files. Any change touching a match forces TIER-3: full test suite + mandatory test run even at pre-commit. Edited only via human PR."
}
```

Default: empty array (no files trigger Tier 3 automatically). Teams add patterns as they identify their architectural critical paths.

Example configuration for a FastAPI project:
```json
{
  "core_files": [
    "app/dependencies/auth.py",
    "app/dependencies/*.py",
    "config.py",
    "app/repositories/kpi_repository.py"
  ]
}
```

`fnmatch` supports `*` (any characters in one path segment), `**` (multiple segments — though `fnmatch` itself doesn't support `**`; the code does `fnmatch.fnmatch(path, pattern)` which works for flat glob patterns).

---

## 5.8 The 50-Receipt Bound — Why Unlimited Growth Is a Production Bug

A project that commits 10× per day would accumulate 3,650 receipts per year. At ~200 bytes per receipt entry:
- 1 year: 730 KB
- 5 years: 3.5 MB

That's manageable for a JSON file, but git will track every change to `gate_state.json`. Thousands of receipts means thousands of dirty-diff bytes per commit, making the gate_state.json diff noisy.

50 receipts covers:
- 5 days of 10 commits/day = any commit in the past week has a receipt
- For teams that push daily, every commit of the past week gets the receipt fast-path

When the 51st receipt evicts the oldest:
- Any commit older than ~5 days loses its receipt
- If pushed, pre-push runs the full gate — which is the correct behavior (the commit is old, it should be re-verified)

---

## 5.9 Atomic Writes — Why Python Is Used Instead of Shell for JSON Mutations

Shell's JSON manipulation is limited. `sed` and `awk` can edit text files but don't understand JSON structure (a value that spans multiple lines would break sed). `jq` can output JSON but isn't installed everywhere.

Python3's `json` module:
1. Parses the entire file into a dict (`json.load`)
2. Modifies the dict in memory
3. Serializes the entire dict back (`json.dump`)

This is not atomic at the filesystem level (a crash between open-for-write and close could leave a partial file), but Python3 writes are fast enough that this is not a practical concern. The file is small (~5KB), the write completes in microseconds.

If true atomicity were required (e.g., for a heavily concurrent team), the pattern would be: write to a temp file, then `os.rename(temp, dest)` — rename is atomic on POSIX filesystems. For this project's scale, the simpler approach is sufficient.

---

<a name="module-6"></a>
# MODULE 6 — install.sh: The Bootstrap Engine

**Prerequisite:** Modules 0, 1, 3.  
**Time investment:** 5–7 hours.  
**install.sh is 615 lines. This module covers the key logic without exhaustive line-by-line annotation.**

---

## 6.1 Greenfield vs Brownfield — Why the Distinction Matters

```bash
FRAMEWORK_VERSION="v1"
FRAMEWORK_SEMVER="1.0.0"
GRAPH_PACKAGE="code-review-graph==2.3.6"
DEFAULT_WEEKLY_LIMIT=1000000

# Count commits to determine basket
COMMIT_COUNT=$(git log --oneline 2>/dev/null | wc -l | tr -d ' ')
if [ "${COMMIT_COUNT:-0}" -gt 50 ]; then
    BASKET="brownfield"
else
    BASKET="greenfield"
fi
```

**Greenfield:** <50 commits. A new project. No technical debt. Zero-tolerance lint policy (any lint failure blocks). Full test coverage expected from day 1.

**Brownfield:** >50 commits. An existing project. Has accumulated lint debt. A zero-tolerance policy would block every commit from day 1. Instead: snapshot current debt as the baseline.

The 50-commit threshold is a heuristic. The real question is "does this project have pre-existing lint violations?" — but checking that requires running the linter first, which is slow. Commit count is a reasonable proxy.

---

## 6.2 Dependency Validation — _require() and Early Failure

```bash
_require() {
    # Usage: _require <command> <install-hint>
    if ! command -v "$1" >/dev/null 2>&1; then
        _error "$1 is required but not found. $2"
    fi
    _success "Found: $1"
}

_require git "Install git from https://git-scm.com/"
_require python3 "Install Python 3.8+ from https://python.org/"
git rev-parse --git-dir >/dev/null 2>&1 || _error "Not inside a git repository."
```

`command -v` is the POSIX way to check if a command exists. Unlike `which` (not always present), `command -v` is built into every POSIX shell.

**Fail early:** If git or python3 are missing, the installation fails immediately with a clear error message, before any files are modified. This is the "validate inputs before side effects" principle.

---

## 6.3 The _fetch() Function — Local Copy

```bash
_fetch() {
    # Usage: _fetch <source_path_relative_to_REPO_DIR> <dest_path>
    local src="${REPO_DIR}/${1}"
    local dest="${2}"
    if [ ! -f "$src" ]; then
        _error "Framework file not found: $src"
    fi
    cp "$src" "$dest"
}
```

`_fetch` copies files from the framework repo to the target repo. The `REPO_DIR` variable is set to the directory containing install.sh (the framework repo root).

This is simpler than a network download (no `curl` dependency, works offline) and ensures the installed gate.sh is exactly the version from the framework repo — not some version from the internet that may have changed.

---

## 6.4 _write_hooks() — gate.sh, pre-commit, pre-push, chmod

```bash
_write_hooks() {
    mkdir -p .githooks
    _fetch "templates/gate.sh" ".githooks/gate.sh"
    chmod +x .githooks/gate.sh

    cat > .githooks/pre-commit << 'PRECOMMIT'
#!/usr/bin/env bash
set -euo pipefail
# Extension/non-TTY guard for SKIP_GATE bypass
_is_extension_or_non_tty() {
    [ ! -t 0 ]                              && return 0
    [ ! -r /dev/tty ]                       && return 0
    [ "${TERM_PROGRAM:-}" = "vscode" ]      && return 0
    [ -n "${VSCODE_PID:-}" ]                && return 0
    [ -n "${VSCODE_GIT_IPC_HANDLE:-}" ]     && return 0
    [ -n "${CURSOR_TRACE_ID:-}" ]           && return 0
    case "${__CFBundleIdentifier:-}" in *vscode*|*cursor*) return 0 ;; esac
    return 1
}
if [ "${SKIP_GATE:-0}" = "1" ]; then
    if _is_extension_or_non_tty; then
        echo "SKIP_GATE bypass needs an interactive terminal." >&2
        exit 1
    fi
    read -r -p "Bypass reason (required): " BYPASS_REASON </dev/tty
    if [ -z "$BYPASS_REASON" ]; then
        echo "Bypass reason is required. Aborting." >&2
        exit 1
    fi
    COMMITTER_DATE=$(date +%s)
    git notes --ref=refs/notes/bypasses append HEAD -m "BYPASS | date=${COMMITTER_DATE} | reason=${BYPASS_REASON}" 2>/dev/null || true
    echo "Gate bypassed. Reason logged to refs/notes/bypasses." >&2
    exit 0
fi
GATE_TRIGGER=pre-commit exec "$(git rev-parse --git-dir)"/../.githooks/gate.sh
PRECOMMIT
    chmod +x .githooks/pre-commit
```

The pre-commit stub does two things:
1. Handles the `SKIP_GATE=1` bypass path (before invoking gate.sh, so gate.sh doesn't need to know about bypass mechanics — separation of concerns)
2. Execs gate.sh with `GATE_TRIGGER=pre-commit`

The `exec` replaces the pre-commit process with gate.sh. This means gate.sh runs AS the pre-commit hook — same PID, same environment, same file descriptors. The `_is_claude_agent_process` traversal works correctly because the hook process IS gate.sh, not a child of gate.sh.

---

## 6.5 core.hooksPath Configuration — Why Not .git/hooks/

Covered fully in Module 1.5. The install.sh call:

```bash
git config core.hooksPath .githooks
```

This writes to `.git/config` in the target repo:
```ini
[core]
    hooksPath = .githooks
```

It does NOT write to `~/.gitconfig` (global) or `/etc/gitconfig` (system). It is a per-repo setting. This means:
- Cloning the repo does NOT automatically configure `core.hooksPath` for the clone
- install.sh must be re-run on each clone to activate the gate

Wait — this seems like it defeats the purpose. Let me clarify:

`git config core.hooksPath .githooks` writes to `.git/config`. But `.githooks/` is committed to the repo. So when you clone the repo, `.githooks/` exists on disk. The problem: `core.hooksPath` is NOT set in the clone's `.git/config`.

**The solution used by the community:** The repo includes a CLAUDE.md instruction: "After cloning, run `git config core.hooksPath .githooks`." Or install.sh is run by a setup script (`make setup`) that includes this step.

Alternatively, install.sh can write a `Makefile` target or a `.github/workflows/setup.yml` that runs the config command automatically.

The key insight: once a developer runs install.sh (or the setup script) once, the gate is active for their local clone. CI is covered by the separate `.github/workflows/gate.yml`.

---

## 6.6–6.7 The pre-commit and pre-push Stubs

The pre-commit stub was shown in 6.4. The pre-push stub handles protected branches and bypass clock:

```bash
cat > .githooks/pre-push << 'PREPUSH'
#!/usr/bin/env bash
set -euo pipefail
PROTECTED_EXACT="main master develop production"
# Block force pushes
if [[ "$LOCAL_REF" == +* ]]; then
    echo "PRE-PUSH BLOCK: Force push is forbidden." >&2
    exit 1
fi
# Block tampering with bypass audit trail
if echo "$LOCAL_REF $REMOTE_REF" | grep -qE ':refs/notes/bypasses'; then
    echo "PRE-PUSH BLOCK: Tampering with bypass audit trail is forbidden." >&2
    exit 1
fi
# Block direct pushes to protected branches
for protected in $PROTECTED_EXACT; do
    if [ "$REMOTE_BRANCH" = "$protected" ]; then
        echo "PRE-PUSH BLOCK: Direct push to $protected is forbidden. Open a PR." >&2
        exit 1
    fi
done
if [[ "$REMOTE_BRANCH" == release/* ]]; then
    echo "PRE-PUSH BLOCK: Direct push to release branch is forbidden." >&2
    exit 1
fi
# Bypass clock enforcement
if git notes --ref=refs/notes/bypasses show HEAD 2>/dev/null | grep -q "BYPASS"; then
    BYPASS_DATE=$(git notes --ref=refs/notes/bypasses show HEAD 2>/dev/null | grep -oE 'date=[0-9]+' | head -1 | cut -d= -f2)
    NOW_EPOCH=$(date +%s)
    if [ -n "$BYPASS_DATE" ]; then
        BYPASS_AGE=$(( NOW_EPOCH - BYPASS_DATE ))
        if [ "$BYPASS_AGE" -gt 86400 ]; then
            echo "PRE-PUSH BLOCK: Bypass deadline expired ($((BYPASS_AGE/3600))h ago)." >&2
            exit 1
        fi
    fi
fi
GATE_TRIGGER=pre-push exec "$(git rev-parse --git-dir)"/../.githooks/gate.sh
PREPUSH
chmod +x .githooks/pre-push
```

---

## 6.8 pipx and code-review-graph — Zero-Knowledge MCP Installation

```bash
if ! command -v pipx >/dev/null 2>&1; then
    python3 -m pip install --user pipx 2>/dev/null || true
    python3 -m pipx ensurepath 2>/dev/null || true
fi
pipx install "${GRAPH_PACKAGE}" --force 2>/dev/null || \
    python3 -m pip install "${GRAPH_PACKAGE}" --user 2>/dev/null || \
    echo "Warning: code-review-graph install failed — graph features unavailable"
```

`pipx` installs Python CLI tools in isolated virtual environments. It prevents package conflicts: `code-review-graph==2.3.6` doesn't pollute the user's global Python environment.

The fallback chain: try pipx, then pip, then just warn. Gate.sh handles missing `code-review-graph` gracefully (`command -v code-review-graph >/dev/null 2>&1 || return 0` in `_ensure_graph_freshness`).

---

## 6.9–6.10 .mcp.json Scaffolding and org_policy.json

```bash
# .mcp.json: tells Claude Code which MCP servers to connect to
cat > .mcp.json << 'MCPJSON'
{
  "mcpServers": {
    "code-review-graph": {
      "command": "code-review-graph",
      "args": ["serve"],
      "domains": ["application_code", "sql_migrations", "orm_models",
                  "infrastructure", "ci_cd", "proxy_config", "env_contracts"]
    }
  }
}
MCPJSON

# ~/.claude/org_policy.json: global token budget
# Written only if not already present (don't overwrite existing policy)
if [ ! -f "${HOME}/.claude/org_policy.json" ]; then
    mkdir -p "${HOME}/.claude"
    cat > "${HOME}/.claude/org_policy.json" << ORGPOLICY
{
  "WEEKLY_LIMIT": ${DEFAULT_WEEKLY_LIMIT},
  "DAILY_BUDGET_PCT": 20,
  "TOKEN_BUDGET": null,
  "policy_version": "1.0"
}
ORGPOLICY
fi
```

`DEFAULT_WEEKLY_LIMIT=1000000` tokens/week → 200,000 tokens/day (20% of weekly). This is a conservative default for a small team. Large teams typically raise this by editing `org_policy.json` directly.

---

## 6.11–6.12 gate_state.json and session_state.json Scaffolding

```bash
# gate_state.json: copy from template (initial state)
cp "${REPO_DIR}/templates/gate_state.json" ".claude/gate_state.json"

# session_state.json: ephemeral per-session state (not committed)
echo '{"brainstorming_complete": false}' > ".claude/session_state.json"
echo ".claude/session_state.json" >> .gitignore
```

`session_state.json` is ephemeral — it is written to `.gitignore` immediately and tracks within-session state (like whether the brainstorming checkpoint was completed). It is reset on each new Claude Code session.

---

## 6.13 The SKIP_GATE Bypass — TTY Guard + git notes Audit Trail

The bypass mechanism is embedded in the pre-commit stub (not in gate.sh itself). This separation means:
- gate.sh doesn't need to know about bypass mechanics
- Bypasses are audited even if gate.sh is somehow corrupted (the stub runs first)

The full mechanism is in 6.4 above and in Module 9.

---

## 6.14 The Date Spoofing Vulnerability and the Fix (date +%s)

Module 9 covers this in detail. Summary: `git var GIT_COMMITTER_DATE` reads from the environment variable `GIT_COMMITTER_DATE` if set, making the bypass timestamp spoofable. The fix (line 113 of install.sh, commit `b400d7d`):

```bash
COMMITTER_DATE=$(date +%s)   # OS clock — immune to GIT_COMMITTER_DATE env var
```

---

<a name="module-7"></a>
# MODULE 7 — The Claude Code Hook Layer

**Prerequisite:** Modules 0, 3.  
**Time investment:** 2–3 hours.

---

## 7.1 What Claude Code Hooks Are and When They Fire

Claude Code has a hook system that runs shell scripts at specific points in the agent's workflow:

| Event | When | Can block? |
|-------|------|-----------|
| `PreToolUse` | Before any tool call executes | Yes (exit 1) |
| `PostToolUse` | After a tool call completes | No (observes only) |
| `PreCompact` | Before context compression | Yes (exit 1) |
| `PostCompact` | After context compression | No |
| `Stop` | When the agent stops responding | No |
| `SessionStart` | When a new session begins | No |
| `UserPromptSubmit` | When user submits a message | Yes |

This project uses `PreToolUse` exclusively — to block actions before they happen.

---

## 7.2 PreToolUse vs PostToolUse — Blocking vs Observing

**Critical distinction:**

```
User writes file:
    Claude Code → PreToolUse hook fires → exit 0 → Write tool executes → file written
                                       → exit 1 → Write tool BLOCKED → file NOT written

User writes file (PostToolUse):
    Claude Code → Write tool executes → file written → PostToolUse hook fires
                                                     → exit 1 → no effect on already-written file
```

PostToolUse fires after the action is complete. It CANNOT undo the action. Exit codes from PostToolUse are ignored for the purpose of blocking. PostToolUse is only for observation: logging, formatting, notifications.

The project's write guard must be a PreToolUse hook, not PostToolUse. The file needs to be stopped before it reaches disk.

---

## 7.3 The Write/Edit/MultiEdit Guard — pre_tool_write_guard.sh

From `.claude/settings.json` in the ai-dev-workflow framework repo:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write|Edit|MultiEdit",
        "hooks": [
          {
            "type": "command",
            "command": "bash .claude/hooks/pre_tool_write_guard.sh"
          }
        ]
      }
    ]
  }
}
```

The `matcher` field is a regex pattern matched against the tool name. `"Write|Edit|MultiEdit"` matches any of the three file-modification tools.

```bash
# .claude/hooks/pre_tool_write_guard.sh
#!/usr/bin/env bash
set -euo pipefail
BRANCH=$(git branch --show-current 2>/dev/null || echo "")
PREFIX="${BRANCH%%/*}"

PERMITTED=$(python3 -c "
import json
try:
    with open('.claude/gate_state.json') as f:
        d = json.load(f)
    strat = d.get('branch_strategy', {}).get('$PREFIX', {})
    print('False' if strat.get('code_writes_permitted') is False else 'True')
except Exception:
    print('True')
" 2>/dev/null || echo "True")

if [ "$PERMITTED" = "False" ]; then
    echo "Write blocked: code_writes_permitted=false on branch $BRANCH" >&2
    exit 1
fi
exit 0
```

---

## 7.4 Reading stdin JSON — How the Hook Receives Tool Input

Every PreToolUse hook receives a JSON payload on stdin:

```json
{
  "session_id": "abc123def456",
  "tool_name": "Write",
  "tool_input": {
    "file_path": "/path/to/file.py",
    "content": "..."
  }
}
```

The pre_tool_write_guard.sh doesn't read stdin because it doesn't need the file path — it only needs to know if we're on a release branch. But the agent_approval hook does need the description:

```bash
INPUT=$(cat)   # read entire stdin
DESCRIPTION=$(python3 -c "
import json, sys
d = json.loads(sys.argv[1])
ti = d.get('tool_input', {})
desc = ti.get('description', '') or ti.get('prompt', '')
print(desc[:200] if desc else '(no description provided)')
" "$INPUT" 2>/dev/null || echo "(no description provided)")
```

---

## 7.5 The code_writes_permitted Check — Bridging Hooks to gate_state.json

The Claude Code hook and gate.sh STEP 1 both check `code_writes_permitted`. They are the first and second layer of the same defense:

| Layer | Fires at | Blocks | What's prevented |
|-------|---------|--------|-----------------|
| Claude Code PreToolUse | Before file write | Write tool call | AI writes file to disk |
| gate.sh STEP 1 | Before commit | Commit creation | File gets committed |

If only the hook existed: someone could write files manually (outside Claude Code) and commit them. Gate.sh catches this.

If only gate.sh existed: the AI could write files (they sit on disk), try to commit, get blocked, and now the working tree is dirty with files that shouldn't exist. The hook prevents this by stopping writes before they happen.

---

## 7.6 The Agent Spawn Guard — ~/.claude/hooks/agent_approval.sh

```bash
#!/usr/bin/env bash
set -euo pipefail

INPUT=$(cat)

DESCRIPTION=$(python3 -c "
import json, sys
d = json.loads(sys.argv[1])
ti = d.get('tool_input', {})
desc = ti.get('description', '') or ti.get('prompt', '')
print(desc[:200] if desc else '(no description provided)')
" "$INPUT" 2>/dev/null || echo "(no description provided)")

printf '\n\033[1;33m[AGENT SPAWN]\033[0m %s\n' "$DESCRIPTION" > /dev/tty
printf 'Approve? [y/N] ' > /dev/tty
read -r REPLY < /dev/tty

case "$REPLY" in
  [yY]|[yY][eE][sS])  exit 0 ;;
  *)                   printf '\033[31mBlocked.\033[0m Agent spawn cancelled.\n' > /dev/tty
                       exit 1 ;;
esac
```

This hook is in `~/.claude/settings.json` (global, applies to all projects). Every time the Claude Code `Agent` tool is called anywhere, this hook fires.

The use of `/dev/tty` for both input and output ensures the prompt appears on the developer's physical terminal regardless of any I/O redirection in the Claude Code pipeline.

---

## 7.7 Settings.json Hook Registration — Matcher Syntax, Command, statusMessage

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Agent",
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude/hooks/agent_approval.sh",
            "statusMessage": "Waiting for agent approval..."
          }
        ]
      }
    ]
  }
}
```

- **`matcher`:** Regex matched against `tool_name`. `"Agent"` matches only the Agent tool. `"Write|Edit|MultiEdit"` matches any of three tools.
- **`type: "command"`:** Runs a shell command. Claude Code also supports `"prompt"` (LLM evaluation) and `"agent"` (subagent evaluation), but `"command"` is the only type used here.
- **`command`:** The shell command to run. Receives JSON on stdin.
- **`statusMessage`:** Text shown in the Claude Code UI while the hook is running.

Settings files:
- `~/.claude/settings.json` — global (applies to all projects)
- `.claude/settings.json` — project-level (committed to repo, applies for all users of this repo)
- `.claude/settings.local.json` — local overrides (gitignored, applies only to this checkout)

---

## 7.8 Exit Codes — Why exit 1 Blocks and exit 0 Allows

In the PreToolUse context:
- **Exit 0:** Hook passes. Tool call proceeds normally.
- **Exit 1:** Hook blocks. Tool call is cancelled. Claude Code receives a "hook blocked this action" response.
- **Exit 2:** Has no special meaning in PreToolUse (unlike PostToolUse where exit 2 adds context without blocking).

---

## 7.9 The Two-Layer Defense: Hooks Block Writes, gate.sh Blocks Commits

```
Attack: AI tries to write SQL to a route file
  → PreToolUse hook fires
  → pre_tool_write_guard.sh: is this a release branch? No. Allow.
  → Write executes. SQL lands in app/routes/billing.py.
  → Developer stages the file: git add app/routes/billing.py
  → Developer commits: git commit -m "feat: billing"
  → pre-commit fires → gate.sh runs
  → STEP 6.5: layer boundary scan
  → grep finds "SELECT" in app/routes/billing.py
  → GATE BLOCK: Layer boundary violation
  → exit 1 → commit blocked

Attack: AI tries to write to a release branch
  → PreToolUse hook fires
  → pre_tool_write_guard.sh: code_writes_permitted=false on release/* → exit 1
  → Write BLOCKED. File never touches disk.
  → Developer cannot stage or commit it.
  → Even if they try: gate.sh STEP 1 would also block it.
```

Defense in depth: neither layer alone is sufficient; together they cover the gap where one layer might be bypassed.

---

<a name="module-8"></a>
# MODULE 8 — The Receipt System: Cryptographic Commit Proof

**Prerequisite:** Modules 1, 4, 5.  
**Time investment:** 2–3 hours.  
**This is the most elegant engineering decision in the project.** Understand it completely.

---

## 8.1 The Problem: How Do You Prove a Specific Commit Was Gate-Checked?

Without the receipt system:

```
Developer flow:
1. git commit → pre-commit fires → gate.sh runs (90 seconds) → pass → commit created
2. git push   → pre-push fires  → gate.sh runs (90 seconds AGAIN) → pass → push proceeds
```

Total friction: 3 minutes per commit-push cycle. On a team of 10 making 5 commits per day: 25 minutes of gate waiting per developer per day. 250 minutes across the team. Developers start writing `SKIP_GATE=1` habitually.

The receipt system reduces step 2 from 90 seconds to <100 milliseconds.

---

## 8.2 Why Commit Hashes Don't Work (They Change on Amend)

Naive approach: "Store the commit hash in a list of verified commits."

Problem: 
```bash
git commit -m "feat: biilng report"   # typo in message
# pre-commit fires → gate passes → commit created → hash = abc123
# Let's fix that typo:
git commit --amend -m "feat: billing report"
# SAME files, DIFFERENT commit hash = def456
# The receipt for abc123 is now useless.
# pre-push finds no receipt for def456 → full re-run (90 seconds)
```

Message amendments are common. The commit hash changes on every amend. A receipt system keyed by commit hash would require a full gate re-run on every amend.

---

## 8.3 What a git Tree Hash Is and Why It's Stable Across Rebases

A tree hash (from `git write-tree` or `git rev-parse HEAD^{tree}`) checksums the file CONTENTS only. It does NOT include:
- Commit message
- Author name
- Author email
- Timestamp
- Parent commit hash

This means:
- **Message-only amend:** Same files → same tree hash → same receipt → fast path ✓
- **Author change (for CI):** Same files → same tree hash → same receipt → fast path ✓
- **Rebase (same files, new parent):** Same files → same tree hash → same receipt → fast path ✓
- **File content change:** Different tree → different hash → old receipt invalid → full re-run ✓

The tree hash answers: "what files, exactly, does this commit contain?" That's exactly the question the receipt system needs to answer.

---

## 8.4 The Two-Hook Protocol: pre-commit Writes, pre-push Reads

Complete sequence for one commit-push cycle:

```bash
# COMMIT:
git commit -m "feat: billing report"
# 1. git runs .githooks/pre-commit
# 2. pre-commit execs gate.sh with GATE_TRIGGER=pre-commit
# 3. gate.sh STEP 4.5: COMMIT_TREE_FP = git write-tree = "4b825dc..."
# 4. gate.sh runs checks (60-90 seconds)
# 5. All pass: _receipt_write "4b825dc..." "feature/billing"
# 6. gate_state.json.receipts["4b825dc..."] = {timestamp, branch, outcome: "pass"}
# 7. exit 0 → commit created → HEAD = abc123

# (Some time passes — developer is writing the PR description)

# PUSH:
git push origin feature/billing
# 1. git runs .githooks/pre-push
# 2. pre-push checks protected branches, bypass clock (pass)
# 3. pre-push execs gate.sh with GATE_TRIGGER=pre-push
# 4. gate.sh STEP 4.5: COMMIT_TREE_FP = git rev-parse HEAD^{tree} = "4b825dc..."
# 5. _receipt_has_pass "4b825dc..." → "yes"
# 6. exit 0 immediately (< 100ms) → push proceeds
```

The tree hash "4b825dc..." is the same at both steps because the files didn't change between commit and push.

---

## 8.5 The Attack Surface: Can You Bypass the Receipt Check?

**Attack 1: Write a fake receipt manually**
```bash
# In .claude/gate_state.json:
echo '{"receipts": {"$(git rev-parse HEAD^{tree})": {"outcome": "pass", ...}}}' > .claude/gate_state.json
```
Then push.

**Does this work?** Yes, technically. Someone with direct file access can write a fake receipt.

**Why it doesn't matter:** 
1. Doing this requires knowing the exact tree hash before pushing (not trivial — requires running `git rev-parse HEAD^{tree}`)
2. `gate_state.json` is committed to the repo. The fake receipt will appear in git diff, will be visible in PR review, and will appear in the audit log
3. Anyone who modifies `gate_state.json` without a legitimate gate run is committing a falsified document — which is detectable and constitutes a policy violation
4. CI also runs the gate (`gate.yml`) and would catch the bypassed commit

**Attack 2: Bypass via SKIP_GATE=1**
This is an intentional, audited escape hatch — not really an attack. Module 9 covers it.

**Attack 3: Delete the receipts key from gate_state.json**
Without a receipt, pre-push runs the full gate. A malicious actor who deletes receipts doesn't bypass the gate — they cause it to run again. This is actually the intended degraded behavior.

**The receipt system's security guarantee:** It is a performance optimization with an audit trail, not a cryptographic proof against an active adversary with write access to `gate_state.json`. An adversary with that level of access could bypass anything. The system prevents casual circumvention and provides audit visibility — which is the appropriate scope for a developer tool.

---

## 8.6 Receipt Pruning — Why Unbounded Growth Breaks Real Teams

Each receipt entry is approximately:
```json
"4b825dc642cb6eb9a060e54bf8d69288fbee4904": {
    "timestamp": "2026-07-01T14:23:00Z",
    "branch": "feature/billing-report",
    "outcome": "pass"
}
```
~120 bytes per entry. 50 entries = 6KB. The file stays small.

Without pruning:
- 100 commits/day × 365 days = 36,500 entries × 120 bytes = 4.4MB just for receipts
- `gate_state.json` becomes a diff-noise machine (every commit modifies it)
- git blame on any file that changes `gate_state.json` becomes unreadable

The 50-entry bound is set conservatively: it covers ~5 days of active development. Any commit older than 5 days that hasn't been pushed yet is an unusual situation anyway.

---

## 8.7 The Incremental Fast Path — Skipping Re-Analysis of Unchanged Trees

The receipt fast path is not just about avoiding duplicate work at push time. There's a second optimization:

`LAST_SHA` in gate_state.json enables **incremental scan** at pre-commit time:

```bash
CHANGED_FILES=$(git diff --name-only "${LAST_SHA}..HEAD" 2>/dev/null)
```

Instead of scanning ALL files on every commit, gate.sh only scans files changed since the last gate pass. On a 100,000-line codebase where only 3 files changed, the lint check, layer boundary scan, and type check run on those 3 files only — not 100,000 lines.

The combined effect of receipts (pre-push fast path) + incremental scan (pre-commit fast path):
- Cold scan (first commit): runs everything, takes full time
- Incremental scan (subsequent commits): runs on changed files only, significantly faster
- Pre-push: receipt check only, <100ms

---

<a name="module-9"></a>
# MODULE 9 — The Bypass System: Controlled Escape Hatches

**Prerequisite:** Modules 1, 4, 6.  
**Time investment:** 1–2 hours.

---

## 9.1 Why a Hard Block With No Escape Is Operationally Dangerous

A blocking gate with no bypass will be deleted.

This is not a hypothetical. The history of development tooling is full of enforcement mechanisms that were disabled under pressure:
- Pre-commit hooks that run slow tests → disabled
- Mandatory code reviews that block hotfixes → bypassed via admin override → removed entirely
- CI that requires manual approval for every deploy → CI disabled for "speed"

When a gate has no emergency override, the natural response to "production is down and the gate is failing a flaky test" is "delete the pre-commit hook" — not "fix the flaky test." Once deleted, it's gone from everyone's clone.

A bypass that is formal, audited, and temporary is better than no bypass (which leads to hook deletion).

---

## 9.2 The SKIP_GATE=1 Mechanism — How It Works

```bash
SKIP_GATE=1 git commit -m "hotfix: revert migration"
```

When `SKIP_GATE=1` is set as an environment variable, the pre-commit stub intercepts it before passing control to gate.sh:

```bash
if [ "${SKIP_GATE:-0}" = "1" ]; then
    if _is_extension_or_non_tty; then
        echo "SKIP_GATE bypass needs an interactive terminal." >&2
        exit 1
    fi
    read -r -p "Bypass reason (required): " BYPASS_REASON </dev/tty
    [ -z "$BYPASS_REASON" ] && { echo "Bypass reason is required." >&2; exit 1; }
    COMMITTER_DATE=$(date +%s)
    git notes --ref=refs/notes/bypasses append HEAD \
      -m "BYPASS | date=${COMMITTER_DATE} | reason=${BYPASS_REASON}" 2>/dev/null || true
    echo "Gate bypassed. Reason logged to refs/notes/bypasses." >&2
    exit 0
fi
```

Note: gate.sh itself never executes on a bypassed commit. The pre-commit stub exits 0 before reaching the `exec gate.sh` line.

---

## 9.3 The TTY Guard — Why IDE Extensions Can't Trigger the Bypass

```bash
_is_extension_or_non_tty() {
    [ ! -t 0 ]                              && return 0   # stdin not a terminal
    [ ! -r /dev/tty ]                       && return 0   # no controlling terminal
    [ "${TERM_PROGRAM:-}" = "vscode" ]      && return 0   # VS Code integrated terminal
    [ -n "${VSCODE_PID:-}" ]                && return 0   # VS Code (pid in env)
    [ -n "${VSCODE_GIT_IPC_HANDLE:-}" ]     && return 0   # VS Code Git integration
    [ -n "${CURSOR_TRACE_ID:-}" ]           && return 0   # Cursor
    case "${__CFBundleIdentifier:-}" in *vscode*|*cursor*) return 0 ;; esac
    return 1
}
```

In VS Code / Cursor, git operations run through the IDE's Git integration, which:
1. Sets VS Code-specific environment variables
2. Does not connect stdin to a real terminal
3. Cannot display an interactive prompt (would freeze the IDE)

This function detects all known IDE integration environments and returns 0 (true = "is extension or non-TTY"). When detected, the bypass is refused with instructions to use a real terminal.

This prevents:
- AI agents from triggering SKIP_GATE (no real terminal in their process tree)
- VS Code source control UI from accidentally triggering a bypass
- CI systems from bypassing the gate

---

## 9.4 The git notes Audit Trail — refs/notes/bypasses

Every bypass writes to git notes:
```
BYPASS | date=1751381000 | reason=Production down, migration revert needed
```

The date is Unix epoch seconds from `date +%s` (the OS clock, NOT `git var GIT_COMMITTER_DATE` — see 9.6).

Accumulating notes:
```bash
git notes --ref=refs/notes/bypasses append HEAD -m "..."
```

`append` adds to existing notes (vs `add` which fails if notes exist). Multiple bypasses on the same commit would accumulate in the same note.

Viewing all bypasses:
```bash
git log --show-notes=bypasses --all
```

---

## 9.5 The BYPASS_REASON Requirement — Human Accountability

```bash
read -r -p "Bypass reason (required): " BYPASS_REASON </dev/tty
if [ -z "$BYPASS_REASON" ]; then
    echo "Bypass reason is required. Aborting." >&2
    exit 1
fi
```

An empty reason is rejected. The developer must type something, which:
1. Forces them to think about why they're bypassing
2. Creates a human-readable record in the audit trail
3. Acts as a speed bump: copy-pasting this behavior is not possible, which reduces casual bypass usage

---

## 9.6 date +%s vs git var GIT_COMMITTER_DATE — The Spoofing Vector We Closed

**The vulnerability (original code):**
```bash
COMMITTER_DATE=$(git var GIT_COMMITTER_DATE)
```

`git var GIT_COMMITTER_DATE` reads from:
1. The environment variable `GIT_COMMITTER_DATE` if set
2. Falls back to the system clock

An attacker (human or AI) can control the timestamp:
```bash
# Make bypass appear expired (future push would be blocked)
GIT_COMMITTER_DATE="Thu, 1 Jan 2020 00:00:00 +0000" SKIP_GATE=1 git commit -m "..."

# Make bypass appear far in the future (never expires)
GIT_COMMITTER_DATE="Thu, 1 Jan 2030 00:00:00 +0000" SKIP_GATE=1 git commit -m "..."
```

**The fix (commit b400d7d in install.sh):**
```bash
COMMITTER_DATE=$(date +%s)
```

`date +%s` reads the **OS system clock** directly. It ignores `GIT_COMMITTER_DATE` entirely. The only way to spoof this is to change the system clock, which requires root access — a fundamentally different threat model.

**Why this matters:** The bypass expiry is a security control. If the timestamp can be set to the future, the 24-hour expiry window is meaningless. The bypass could be made to never expire.

---

## 9.7 How to Audit Who Bypassed and Why

```bash
# Show all bypass notes in the current repo
git log --all --show-notes=bypasses | grep -A3 "BYPASS"

# Show bypasses for a specific time range
git log --all --after="2026-07-01" --show-notes=bypasses | grep -A3 "BYPASS"

# Show the bypass note for a specific commit
git notes --ref=refs/notes/bypasses show <commit-sha>

# List all commits that have bypass notes
git log --all --format="%H %s" | while read sha msg; do
    note=$(git notes --ref=refs/notes/bypasses show "$sha" 2>/dev/null)
    if echo "$note" | grep -q "BYPASS"; then
        echo "BYPASS: $sha — $msg"
        echo "$note" | grep "reason=" | sed 's/.*reason=/  Reason: /'
    fi
done
```

The audit trail answers: who bypassed (git author), when (date= timestamp), on what code (commit SHA + message), and why (reason=).

---

<a name="module-10"></a>
# MODULE 10 — Testing with bats

**Prerequisite:** Module 4 (you understand what gate.sh does so you know what to test).  
**Time investment:** 3–4 hours.

---

## 10.1 Why bats-core Exists and What It Solves

Testing bash scripts is hard. Standard unit test frameworks (pytest, jest) work with languages that have type systems, module imports, and testable functions. Bash scripts are sequences of commands — they have global state, external dependencies (git, filesystem), and side effects.

**bats-core** (Bash Automated Testing System) provides:
- A test file format: `@test "description" { ... }` blocks
- A `run` helper: runs a command and captures exit code + output
- Assertions: `[ "$status" -eq 0 ]` style, or the `[[ "$output" == *"text"* ]]` pattern
- `setup` / `teardown` hooks: run before/after each test
- Test isolation: each test runs independently

The gate.sh tests use real git repos (created by `setup_gate_repo` in test_helper.bash), not mocks. This is intentional: the tests exercise the complete gate.sh pipeline, not individual functions.

---

## 10.2 Test Structure — @test blocks, setup/teardown

```bash
load test_helper   # Load test_helper.bash (sets up helpers)

setup() {
    setup_gate_repo   # Create a fresh throwaway git repo
}

teardown() {
    teardown_gate_repo   # Delete the throwaway git repo
}

@test "description of what this test verifies" {
    # Arrange: set up test conditions
    echo "some content" > test_file.py
    git add test_file.py
    
    # Act: run the gate
    run run_gate GATE_TRIGGER=pre-commit LINT_CMD='true' TYPE_CMD='true'
    
    # Assert: check exit code and output
    [ "$status" -eq 0 ]
    [[ "$output" == *"GATE PASS"* ]]
}
```

`run` is a bats built-in that:
1. Runs the command
2. Captures stdout+stderr as `$output`
3. Captures exit code as `$status`
4. Does NOT abort on non-zero exit

Without `run`, a failed command would terminate the test (due to `set -e`). With `run`, you can test failure cases.

---

## 10.3 test_helper.bash — Shared Fixtures and Utilities

```bash
#!/usr/bin/env bash
FRAMEWORK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GATE_SH_SRC="${FRAMEWORK_ROOT}/templates/gate.sh"
GATE_STATE_SRC="${FRAMEWORK_ROOT}/templates/gate_state.json"

setup_gate_repo() {
    TEST_REPO="$(mktemp -d "${TMPDIR:-/tmp}/gate-test-XXXXXX")"
    cd "$TEST_REPO" || return 1
    git init -q
    git config user.email "gate-test@example.com"
    git config user.name "Gate Test"
    git config init.defaultBranch main
    mkdir -p .githooks .claude
    cp "$GATE_SH_SRC" .githooks/gate.sh
    cp "$GATE_STATE_SRC" .claude/gate_state.json
    chmod +x .githooks/gate.sh
    git checkout -b feature/gate-test -q
    echo "# gate test repo" > README.md
    git add README.md
    git commit -q -m "chore: init test repo"
}

teardown_gate_repo() {
    if [ -n "${TEST_REPO:-}" ] && [ -d "$TEST_REPO" ]; then
        rm -rf "$TEST_REPO"
    fi
}

run_gate() {
    env "$@" GATE_STATE=".claude/gate_state.json" bash .githooks/gate.sh 2>&1
}
```

`setup_gate_repo` creates a fresh git repo in `/tmp` for each test, initializes it with a feature branch, and copies the gate artifacts. Each test gets a clean, isolated repo.

`run_gate` passes extra env vars (`GATE_TRIGGER=pre-commit`, `LINT_CMD='true'`, etc.) to gate.sh. The `2>&1` redirect captures both stdout and stderr into the output that `run` captures.

---

## 10.4 cold_start.bats — What Happens When gate_state.json Is Missing

```bash
@test "cold start: last_pass_sha null emits cold scan mode" {
    echo "docs only" > NOTES.md
    git add NOTES.md
    output="$(run_gate GATE_TRIGGER=pre-commit 2>&1)" || true
    [[ "$output" == *"cold start"* ]]
    [[ "$output" == *"scope=cold"* ]]
}
```

This tests that when `last_pass_sha` is null (template state), gate.sh detects a cold start and announces it. The test verifies the scan mode is correctly identified.

Note: `output="$(run_gate ...)" || true` — the `|| true` prevents the test from aborting if gate.sh exits non-zero. We only care about the output content, not the exit code here.

---

## 10.5 receipt_fast_path.bats — Verifying the Incremental Optimization

```bash
@test "pre-push receipt fast-path skips mechanical re-run" {
    echo "change" > NOTES.md
    git add NOTES.md
    run_gate GATE_TRIGGER=pre-commit >/dev/null 2>&1
    git commit -q -m "feat: notes"

    run run_gate GATE_TRIGGER=pre-push
    [ "$status" -eq 0 ]
    [[ "$output" == *"receipt verified"* ]]
}
```

Three stages:
1. Stage a file change
2. Run pre-commit gate → receipt is written
3. Commit the file
4. Run pre-push gate → should find the receipt and exit 0 immediately

The assertion `[[ "$output" == *"receipt verified"* ]]` confirms the fast path was taken (not a full re-run).

---

## 10.6 secrets_block.bats — Confirming Secrets Are Caught

```bash
@test "secrets scan blocks staged credential patterns" {
    printf 'DATABASE_PASSWORD=super_secret_value\n' > config.env
    git add config.env
    run run_gate GATE_TRIGGER=pre-commit
    [ "$status" -eq 1 ]
    [[ "$output" == *"GATE BLOCK: Potential secret"* ]]
}

@test "secrets scan allows placeholder wording" {
    printf '# example placeholder for DATABASE_URL\n' > .env.example
    git add .env.example
    run run_gate GATE_TRIGGER=pre-commit
    [ "$status" -eq 0 ]
}
```

Two complementary tests: one verifies blocking behavior (false positive rate = 0 for real secrets), one verifies the placeholder filter works (false positive rate = 0 for documentation).

---

## 10.7 layer_boundary_block.bats — SQL-in-Routes Detection

```bash
@test "layer boundary blocks HTTP imports in services layer" {
    cat > app/services/billing.py << 'EOF'
from fastapi import HTTPException

def charge():
    raise HTTPException(status_code=400, detail="bad")
EOF
    git add app/services/billing.py
    run run_gate GATE_TRIGGER=pre-commit \
        LINT_CMD='true' \
        TYPE_CMD='true' \
        COMPLEXITY_CMD='true'
    [ "$status" -eq 1 ]
    [[ "$output" == *"Layer boundary violation"* ]]
    [[ "$output" == *"SERVICE_HAS_HTTP"* ]]
}
```

The overrides `LINT_CMD='true'`, `TYPE_CMD='true'`, `COMPLEXITY_CMD='true'` disable those checks (by making them no-ops that always succeed). This isolates the test to the layer boundary check only — the test is testing one thing.

`true` is a Unix command that exits 0 immediately. `LINT_CMD='true'` makes the lint step run `true` (always passes). The test can then verify layer boundary behavior without worrying about whether the test repo's Python is properly configured for linting.

---

## 10.8 expired_bypass_block.bats — The Bypass TTL Enforcement

```bash
@test "expired bypass note blocks pre-push clock check" {
    OLD_EPOCH=$(( $(date +%s) - 90000 ))   # 25 hours ago
    git notes --ref=refs/notes/bypasses add -m "BYPASS | date=${OLD_EPOCH} | reason=test expired" HEAD
    run run_pre_push_hook
    [ "$status" -eq 1 ]
    [[ "$output" == *"Bypass deadline expired"* ]]
}

@test "active bypass note within 24h allows pre-push clock check" {
    NOW_EPOCH=$(date +%s)
    git notes --ref=refs/notes/bypasses add -m "BYPASS | date=${NOW_EPOCH} | reason=test active" HEAD
    run run_pre_push_hook
    [ "$status" -eq 0 ]
}
```

`90000 seconds = 25 hours` — just past the 24-hour limit. This test verifies the expiry logic works correctly.

`run_pre_push_hook` is defined in test_helper.bash and runs the bypass clock check in isolation (not the full gate.sh pre-push path). This keeps the test focused.

---

## 10.9 CI Integration — framework-tests.yml

The framework repo includes a GitHub Actions workflow (`.github/workflows/framework-tests.yml`) that runs the bats test suite on every push:

```yaml
name: Gate Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install bats-core
        run: |
          git clone https://github.com/bats-core/bats-core.git /tmp/bats
          /tmp/bats/install.sh /usr/local
      - name: Run gate tests
        run: |
          cd tests/gate
          bash run_tests.sh
```

`run_tests.sh` in `tests/gate/` orchestrates bats:
```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
bats --tap *.bats
```

The `--tap` flag outputs in TAP format (Test Anything Protocol), which CI systems understand.

---

## 10.10 CI Gate — gate.yml Walkthrough

`framework-tests.yml` (Module 10.9) tests the bats suite on the *framework repo itself*. This section covers the different file — `templates/ci-gate.yml`, deployed by install.sh to `.github/workflows/gate.yml` in the *user's project repo*. These serve different purposes.

```yaml
# CI parity gate — deployed by install.sh to .github/workflows/gate.yml
name: governance-gate

on:
  pull_request:
    branches: [main, master, develop, "release/**", production]
  push:
    branches: [main, master, develop, "release/**", production]

permissions:
  contents: read        # read-only — gate never writes back to the repo

jobs:
  gate:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout (full history — gate needs diff range)
        uses: actions/checkout@v4
        with:
          fetch-depth: 0   # ← required; see below

      - name: Set up Python (gate.sh json helpers)
        uses: actions/setup-python@v5
        with:
          python-version: "3.x"

      - name: Verify governance files are present and unmodified by the PR
        run: |
          set -euo pipefail
          test -f .githooks/gate.sh   || { echo "::error::.githooks/gate.sh missing"; exit 1; }
          test -f .claude/gate_state.json || { echo "::error::.claude/gate_state.json missing"; exit 1; }
          echo "Governance files present."

      - name: Run governance gate (mechanical — tests forced on in CI)
        env:
          GATE_TRIGGER: ci          # ← puts gate.sh in CI mode
          RUN_TESTS: "true"         # ← forces full test suite regardless of receipt
        run: |
          set -euo pipefail
          chmod +x .githooks/gate.sh
          bash .githooks/gate.sh
```

### Four CI-Specific Mechanics Worth Understanding

**1. `fetch-depth: 0` — full history is required**

By default, `actions/checkout@v4` does a shallow clone (depth 1). gate.sh's STEP 4 computes `git diff LAST_SHA..HEAD` to determine which files changed incrementally. With depth 1, commits before the current HEAD don't exist locally — `git diff` against a SHA not in the shallow history exits with an error. Full history (`fetch-depth: 0`) ensures every commit referenced in `gate_state.json` is available.

**2. `GATE_TRIGGER=ci` — gate knows it's in CI**

Gate.sh checks `$GATE_TRIGGER` in several places. The CI mode behaves like `pre-push` (full verification, not just incremental) but skips some hooks that are only meaningful locally (TTY prompts, process tree traversal for `_is_claude_agent_process`). In CI, all commits are treated as agent commits for gate-check purposes.

**3. `RUN_TESTS=true` — the receipt fast path is disabled**

Locally, `pre-push` can exit early if a receipt exists for the committed tree (Module 8). In CI, the receipt in `gate_state.json` cannot be trusted: the file is from the repo at checkout time, not from the developer's live session. `RUN_TESTS=true` bypasses the receipt check and forces the full test suite, coverage measurement, and complexity check on every CI run.

**4. Governance file integrity step**

The first job step checks that `.githooks/gate.sh` and `.claude/gate_state.json` are present. This prevents a PR that deletes or renames these files from silently disabling CI governance. If a PR removes `gate.sh`, CI fails loudly before the gate even runs.

### Why CI Is the Backstop, Not the Primary Gate

The local gate runs in under 90 seconds with receipt caching. CI takes 3–5 minutes (checkout + Python setup + full test suite). If CI were the primary gate, developers would wait minutes for feedback they could have gotten in seconds.

The division of responsibility:
- **Local gate** — developer feedback loop, fast, receipt-optimized
- **CI gate** — authoritative backstop, catches bypassed commits, runs on pushes to protected branches, full test suite always on

An attacker who bypasses the local gate (SKIP_GATE=1) still cannot merge to main without CI passing. CI admin access is required to disable CI — and that action is logged by GitHub at the organization level.

---

<a name="module-11"></a>
# MODULE 11 — The v1 Release Packages

**Time investment:** 1–2 hours.

---

## 11.1 Basket 1 (Brownfield) vs Basket 2 (Greenfield) — Why the Split

The `v1_release/` directory contains two complete implementation packages:

```
v1_release/
├── basket-1-brownfield/
│   ├── v1_implementation_package_existing.md   # PM-facing doc
│   └── v1_engineering_guide_existing.md         # Engineer-facing doc
└── basket-2-greenfield/
    ├── v1_implementation_package_new.md
    └── v1_engineering_guide_new.md
```

**Brownfield** (existing project): Has technical debt, existing lint violations, running tests that may not all pass. Installation must not break current workflows.

**Greenfield** (new project): Clean slate. Zero-tolerance linting from day 1. Test coverage gate matters immediately.

The split exists because the installation instructions, baseline configuration, and expectation-setting are fundamentally different for each case.

---

## 11.2 The Implementation Package — What a PM Receives

The `v1_implementation_package_*.md` is a business-facing document:
- **Problem statement:** why this is needed (AI coding risks, compliance posture)
- **Timeline:** what happens week 1, month 1, month 3
- **Metrics:** what to measure (gate pass rate, bypass frequency, token spend)
- **Team impact:** what changes for developers
- **Rollback plan:** how to uninstall if needed

This document exists because engineers don't implement governance tools in a vacuum. A PM or engineering manager needs to understand the initiative and sponsor it. The implementation package is that sponsorship artifact.

---

## 11.3 The Development Guide — What an Engineer Receives

The `v1_engineering_guide_*.md` is a technical implementation guide:
- **Installation steps:** exact commands to run
- **Initial configuration:** what to set in `CLAUDE.md`, `gate_state.json`
- **Stack-specific setup:** how to configure `TEST_CMD`, `LINT_CMD` for Python/Node/Go
- **Test run:** how to verify the gate works
- **Ongoing maintenance:** how to update thresholds, add core_files, upgrade the gate

---

## 11.4 The Init Prompt — The One Human Step That Cannot Be Automated

Install.sh automates everything EXCEPT one thing: writing `CLAUDE.md`.

`CLAUDE.md` is the engineering constitution — the list of architectural rules, naming contracts, security invariants, and coding standards that are specific to this project. No automation can generate these because they are the accumulated wisdom of the team.

### The Two-Phase Process

Writing CLAUDE.md is not a single AI prompt. It is a **two-phase process** designed so a human reviews the recon before the AI writes anything.

**Phase 1 — Reconnaissance (read-only)**

The tech lead runs the init prompt's Half 1 in a fresh Claude Code session with no prior context. The AI performs a read-only sweep of the project:

- Reads the full directory tree
- Reads all existing route, service, repository, and model files
- Identifies the actual layer structure as it exists in code (not as assumed)
- Finds all existing naming patterns (function names, class names, module names)
- Identifies security-sensitive files (auth dependencies, credential readers, SQL queries)
- Locates existing test files and the test runner configuration
- Reads any existing CLAUDE.md, README, or ADR documents

The AI outputs a structured **discovery report** — what it found, organized as:
```
LAYERS IDENTIFIED: ...
NAMING PATTERNS: ...
SECURITY-SENSITIVE FILES: ...
TEST CONFIGURATION: ...
AMBIGUITIES (things I cannot determine from code alone): ...
```

**The human review step:** The tech lead reads the discovery report and corrects any misidentified layers, missed invariants, or wrong naming patterns before proceeding. The AI cannot know what the team considers "non-negotiable" — only a human who has lived with the codebase can answer that.

**Phase 2 — Generation**

The tech lead runs the init prompt's Half 2, passing the corrected discovery report as context. The AI generates four files:

1. **`CLAUDE.md`** — The engineering constitution. Sections:
   - Architecture enforcement (layer definitions + what each layer must/must not do)
   - Naming contracts (repository: fetch_*/find_*, service: get_*/calculate_*, etc.)
   - Security invariants (credential handling, auth enforcement, SQL parameterisation)
   - Dependency governance (approved packages, version pinning policy)
   - Testing requirements (coverage threshold, mock policy, eval rules)
   - Hard stops (changes requiring human approval)
   - Default execution protocol (auto-pipeline behavior)

2. **`.claude/settings.json`** — Hook registrations for this project:
   - `PreToolUse` write guard (blocks writes to release branches)
   - Any project-specific hook the tech lead requested during Phase 1 review

3. **`.claude/baseline.json`** — Lint debt snapshot (brownfield only):
   - Run the linter once against the full codebase
   - Record existing findings as the baseline
   - Future runs block only NEW findings (the ratchet)

4. **`.githooks/gate.sh` configuration section** — The `LINT_CMD`, `TYPE_CMD`, `TEST_CMD`, and `COVERAGE_CMD` variables at the top of gate.sh, filled from the Phase 1 discovery of what tools this project actually uses.

### Why Automation Cannot Replace This Step

Automation could generate a CLAUDE.md that describes the code structure as-found. What it cannot generate:

- **Rules that don't exist yet in code.** "Never call os.environ directly in routes" — if no route currently violates this, there's no code evidence for the rule.
- **The severity hierarchy.** Which violations block immediately vs warn vs are deferred. This is a judgment call about risk tolerance.
- **Business-context security invariants.** "The SESSION_TOKEN is never logged" — this requires knowing that SESSION_TOKEN is sensitive, which requires understanding the product.
- **What constitutes a "core file" for Tier 3 escalation.** `auth.py` is obvious. But is `config.py`? Is the ORM base model? These are team decisions.

The init prompt exists precisely at the boundary where code analysis ends and human knowledge begins.

### The CLAUDE.md Hash as Continuity Guarantee

After CLAUDE.md is written, `_verify_context_anchoring` (Module 4.7) stores its SHA-256 hash in `gate_state.json`. Every subsequent gate run checks whether CLAUDE.md has changed. If it has, the AI is warned to re-read the constitution before continuing. This closes the loop: the init prompt creates the constitution; the hash check ensures the AI stays aligned to it as it evolves.

---

## 11.5 The Upgrade Path — UPGRADE.md and Backward Compatibility

`install.sh --upgrade` handles version upgrades. The design principles:

1. **Upgrade the engine, preserve the configuration:** gate.sh is overwritten; gate_state.json receipts, thresholds, and baselines are preserved.
2. **Bump framework_version in gate_state.json:** Tracks which version of the gate is installed.
3. **CI workflow is force-overwritten:** `.github/workflows/gate.yml` is always the latest version.
4. **CLAUDE.md is never touched:** The team's constitution is their property.

Backward compatibility: `gate_state.json` is designed with optional fields. New gate.sh versions add new fields with sensible defaults; old data in existing installations is preserved. The gate never fails because a field is missing — it uses `_json_get` which returns empty string on missing keys, and the code has `${var:-default}` fallbacks throughout.

---

<a name="module-12"></a>
# MODULE 12 — Security Posture

**Time investment:** 2–3 hours.

---

## 12.1 The Attacker Model — A Developer Who Wants to Skip the Gate

The primary threat model is NOT an external attacker. It is:

**An internal developer (or AI agent acting as one) who wants to commit code without the gate running.**

Why? Speed. The gate takes 60–90 seconds. On a deadline, a developer might be tempted to bypass it.

Secondary threat model: **an AI agent that has found the bypass code path and uses it to avoid being blocked.**

The gate is NOT designed to resist an attacker with root access to the machine, who could modify git, gate.sh, or the OS. That threat model requires different controls (signed commits, remote attestation, etc.).

---

## 12.2 Defense in Depth — Hooks + Gate + CI

Three independent layers, each of which can catch what the others miss:

| Layer | What it catches | Can be bypassed by |
|-------|----------------|-------------------|
| Claude Code PreToolUse hook | Writes to release branches | Running git directly (not via Claude Code) |
| git pre-commit (gate.sh) | Security violations, architecture violations, budget exhaustion | SKIP_GATE=1 (leaves audit trail) |
| CI gate (gate.yml) | Everything gate.sh checks, runs on the remote | Requires CI bypass (admin action, fully logged) |

An attacker must bypass all three layers to commit malicious code without any audit trail. This requires: running outside Claude Code, using SKIP_GATE=1, AND having CI admin privileges. Each step is logged and requires human authority.

---

## 12.3 Secret Scanning — Patterns, False Positives, Tuning

The secrets scan pattern (STEP 5) is intentionally broad:
```
(api[_-]?key|secret|password|token|private[_-]?key|aws_access|BEGIN (RSA|EC|OPENSSH|PGP))
```

False positive handling:
- `grep -v '#'` excludes commented-out lines
- `grep -v 'placeholder\|example\|REDACTED'` excludes documentation

Teams can tune the pattern by modifying gate.sh's STEP 5 regex. Common additions:
- Company-specific secret prefixes
- AWS account IDs
- Stripe/Twilio/Sendgrid API key patterns

The default pattern has a low false negative rate (few secrets slip through) at the cost of moderate false positive rate (some valid code is flagged). The design choice favors security over developer convenience — a false positive can be fixed in seconds; a false negative (leaked secret) can require credential rotation and security incident response.

---

## 12.4 Branch Protection — Why release/* Has code_writes_permitted=false

Release branches serve a specific purpose: they are the snapshot of code going to production. No new features, no refactors, no "quick fixes" that haven't been properly tested on a feature branch.

`code_writes_permitted: false` on release branches enforces this contract:
- Any attempt to write code on a release branch is blocked at the Claude Code hook level (before the file is written)
- Any attempt to commit code on a release branch is blocked at gate.sh STEP 1
- The only permitted operations on release branches are documentation updates, cherry-picks that have already gone through the full gate on a feature branch, and version bumps

This prevents "hotfix on release branch" anti-patterns that bypass the full review process.

---

## 12.5 Token Budget Enforcement — Why This Is a Security Control

Token budget enforcement is typically framed as cost management. It is also a security control:

1. **DoS prevention:** An AI agent that enters an infinite loop, repeatedly calling `read_file` on the entire codebase, would exhaust an organization's budget and potentially shut down AI-assisted development for the entire day.

2. **Exfiltration detection:** An AI session consuming 10× the normal token budget is reading unusual amounts of data. The audit log records this.

3. **Scope control:** The token budget implicitly limits the AI's "blast radius" — an AI with only 200,000 tokens/day cannot load the entire codebase as context on every operation.

---

## 12.6 The Process Tree Traversal — Detecting Agent vs Human Commits

`_is_claude_agent_process` (Module 4.10) traverses the process tree to determine if gate.sh was invoked from a Claude Code session.

**Why does this matter for security?** Several gate checks apply only to AI agents:
- Brainstorming checkpoint requirement (STEP 4.4)
- Pre-push checkpoint gate (STEP 4.6)
- Token budget hard block (STEP 2)

Human developers are not subjected to these checks. The distinction respects developer autonomy while enforcing governance on AI-generated code.

The traversal cannot be fooled by process name spoofing at the bash level (a script named `claude-code`) because `ps -o command=` reads from the kernel's process table, not from the shell's environment.

---

## 12.7 SECURITY_POSTURE.md Walkthrough

The framework includes `v1_release/basket-1-brownfield/SECURITY_POSTURE.md` (and greenfield equivalent) documenting:
- The threat model
- Each defense and what it prevents
- Known limitations (this system cannot prevent a developer with sudo access from modifying the gate)
- Monitoring recommendations (alert on bypass frequency, alert on CI gate failures)
- Incident response (how to trace a bypassed commit back to the bypass audit trail)

This document is provided to security teams who need to review the governance implementation. It is written in language that a CISO can understand, with technical detail in an appendix.

---

<a name="module-13"></a>
# MODULE 13 — Design Challenge Mode

**Prerequisite:** All prior modules.  
**Time investment:** 5–8 hours (each challenge is 1 hour minimum).  
**Philosophy:** The goal is not to get the "right answer." The goal is to reason about trade-offs at the level of the original engineer.

For each challenge: write out your solution completely before reading the discussion. Then compare.

---

## 13.1 Challenge: Add Support for Detecting SQL Injection in Go Files

**The task:** Extend STEP 6.5's layer boundary scan to detect SQL injection patterns in Go code.

**What to detect:**
```go
// Vulnerable: string concatenation in query
db.Query("SELECT * FROM users WHERE id = " + userId)
db.QueryRow(fmt.Sprintf("SELECT * FROM users WHERE name = '%s'", name))
```

**Your design questions before reading further:**
1. Where in gate.sh would you add this? (Layer: which check, which lines?)
2. What regex pattern would catch the vulnerability without false positives on safe parameterized queries?
3. How would you scope it to changed files only?

**Discussion:**

The layer boundary scan at lines 760–817 is the right place. The pattern:

```bash
if echo "$_lf" | grep -qiE '\.go$'; then
    _SQL_INJECTION=$(grep -nE '(db\.(Query|QueryRow|Exec)\(.*\+.*\)|fmt\.Sprintf.*SELECT|fmt\.Sprintf.*INSERT|fmt\.Sprintf.*UPDATE|fmt\.Sprintf.*DELETE)' "$_lf" 2>/dev/null | head -3 || true)
    if [ -n "$_SQL_INJECTION" ]; then
        LAYER_VIOLATIONS="${LAYER_VIOLATIONS}GO_SQL_INJECTION ${_lf}:\n${_SQL_INJECTION}\n"
    fi
fi
```

The challenge with this pattern: Go's `db.Query` can use parameterized queries (`db.Query("SELECT * FROM users WHERE id = ?", id)`) which are safe. The pattern above would only match when there's actual string concatenation (`+`) or `fmt.Sprintf` with SQL keywords.

False positive risk: `db.Query("SELECT count(*) FROM " + tableName)` where `tableName` comes from a whitelist. The pattern would flag this. The developer would need to add a comment to suppress or restructure the query.

---

## 13.2 Challenge: Add a Per-Branch Token Budget Override

**The task:** Allow specific branches to have different token budgets. `feature/big-refactor` should be allowed to use 3× the normal budget.

**Your design:**
1. Where is the budget stored? How would per-branch overrides work?
2. What's the precedence: org policy → repo policy → branch policy?
3. What prevents an AI from overriding its own budget?

**Discussion:**

Add to `gate_state.json` under `branch_strategy`:
```json
{
  "branch_strategy": {
    "feature": {
      "token_budget_multiplier": 1.0
    }
  },
  "branch_budget_overrides": {
    "feature/big-refactor": {
      "token_budget": 600000
    }
  }
}
```

In STEP 2, after computing the base budget:
```bash
BRANCH_OVERRIDE=$(_json_get "$GATE_STATE" "branch_budget_overrides.${CURRENT_BRANCH}.token_budget")
if [ -n "$BRANCH_OVERRIDE" ] && [ "$BRANCH_OVERRIDE" != "null" ]; then
    # Use branch override, but org ceiling still wins
    if [ -n "$ORG_BUDGET" ] && [ "$ORG_BUDGET" -lt "$BRANCH_OVERRIDE" ] 2>/dev/null; then
        TOKEN_BUDGET="$ORG_BUDGET"
    else
        TOKEN_BUDGET="$BRANCH_OVERRIDE"
    fi
fi
```

**Preventing self-override:** `branch_budget_overrides` should be in the "agent-immutable" section of the CLAUDE.md constitution. An AI cannot raise its own budget because modifying `gate_state.json` to add a budget override would itself be a commit — which goes through gate.sh — which uses the existing (lower) budget limit. The override would only take effect after the commit, not during it.

---

## 13.3 Challenge: Make the Receipt System Tamper-Evident with HMAC

**The task:** A sophisticated developer could manually edit `gate_state.json` to add fake receipts. Make tampering detectable.

**Your design:**
1. What secret key would you use?
2. Where would the HMAC be computed?
3. Where would it be verified?

**Discussion:**

HMAC (Hash-based Message Authentication Code) signs data with a secret key. Anyone without the key cannot compute a valid HMAC.

**Key derivation:** The secret should be derived from something stable and non-obvious. One option: `git rev-parse --git-dir` + the repo's origin URL + a per-machine secret stored in `~/.claude/gate_key`. Another: an org-level signing key from the org_policy.

**Implementation:**
```python
import hmac, hashlib, json

def sign_receipt(tree_hash, timestamp, branch, secret_key):
    payload = f"{tree_hash}:{timestamp}:{branch}"
    return hmac.new(secret_key.encode(), payload.encode(), hashlib.sha256).hexdigest()

def verify_receipt(receipt, tree_hash, secret_key):
    expected = sign_receipt(tree_hash, receipt['timestamp'], receipt['branch'], secret_key)
    return hmac.compare_digest(receipt.get('hmac', ''), expected)
```

**The problem with this design for this project:** Where does the secret key live? If it's in the repo, anyone with repo access can compute valid HMACs. If it's per-machine (in `~/.claude/`), a developer can only verify their own receipts, not another developer's. If it's in org_policy.json (shared), it needs to be provisioned securely.

For this project's threat model (casual circumvention), the existing design is sufficient. HMAC adds significant complexity for marginal security gain against the actual threat.

---

## 13.4 Challenge: Support Monorepos With Multiple Gate Configs

**The task:** A monorepo with `packages/frontend/`, `packages/backend/`, `packages/ml/` needs different gate configurations (different lint rules, different coverage thresholds, different layer checks) per package.

**Your design:**
1. How would gate.sh know which config to use?
2. Where would configs live?
3. How would you handle a commit that touches multiple packages?

**Discussion:**

Approach: tiered config resolution — closest `gate_state.json` wins.

```bash
# Find the closest gate_state.json to each changed file
EFFECTIVE_CONFIG=$(for f in $CHANGED_FILES; do
    dir="$(dirname "$f")"
    while [ "$dir" != "." ] && [ "$dir" != "/" ]; do
        if [ -f "$dir/.claude/gate_state.json" ]; then
            echo "$dir/.claude/gate_state.json"
            break
        fi
        dir="$(dirname "$dir")"
    done
done | sort -u)
```

For a commit touching both frontend and backend: run each package's gate config against its own files. If any config produces a block, the commit is blocked.

**Complexity cost:** This turns gate.sh from a single-pass script into a multi-pass, multi-config orchestrator. The complexity might be worth it for a large monorepo but is overkill for projects with a single codebase.

---

## 13.5 Challenge: Design a Web Dashboard for Gate Audit Logs

**The task:** Build a read-only web dashboard that shows: gate pass/fail rates per developer, per branch, over time; bypass history; token spend by day; most common block reasons.

**Discussion:**

Data source: `gate_state.json.token.token_audit_log` (90-day rolling window in each repo).

**Aggregation challenge:** The audit log is per-repo. A team of 10 repos would require a centralized aggregator that reads each repo's gate_state.json. A GitHub Action that runs nightly and pushes aggregated data to a central store (S3, Postgres) would work.

**Dashboard design:**
- Time-series chart: gate pass rate per day (passes / (passes + blocks))
- Breakdown: block reasons (lint, layer violation, secrets, etc.) as a pie chart
- Bypass timeline: when bypasses happened and how long they took to resolve
- Token spend: daily token usage vs budget (per developer if session_spend.tmp is tracked per user)

**Privacy consideration:** Token spend data reveals developer activity levels. This is sensitive. The dashboard should require manager-level access and be explicit about what it shows.

---

## 13.6 Challenge: How Would You Scale This to 500 Engineers?

**The task:** The current design works well for teams of 5–20. What breaks at 500 engineers, and how do you fix it?

**What breaks:**
1. **`gate_state.json` contention:** Every commit from every developer writes to the same file. With 500 engineers making 10 commits/day each, that's 5,000 writes/day to the same JSON file in the same repo. Git conflicts would be constant.

2. **Token budget per-developer vs per-team:** A team-level token budget means one heavy user can exhaust everyone's budget.

3. **Receipt ledger size:** 50 receipts per repo × 100 repos = 5,000 receipts. Not a problem. But if the company uses a single monorepo with 500 engineers committing, the 50-receipt limit may cause false cache misses.

**Solutions:**

For `gate_state.json` contention: move per-developer state to a per-developer file (`~/.claude/gate_state_<repo_hash>.json`) and keep only policy/configuration in the repo's `gate_state.json`. Receipts become per-developer.

For token budget: move budgets to `~/.claude/org_policy.json` per-developer (already supported) rather than per-repo. Each developer has their own daily budget. The org policy is pushed via `git config` hooks or a managed settings deploy.

For receipt contention: increase the receipt limit to 500, or move receipts to a per-developer file.

---

## 13.7 Challenge: How Would You Make the Gate Language-Agnostic?

**The task:** gate.sh currently has Python-specific patterns (psycopg2, FastAPI) hardcoded in STEP 6.5. Design an extension that allows teams to define custom layer violation patterns without modifying gate.sh.

**Your design:**
1. Where would custom patterns live?
2. What format would they take?
3. How would gate.sh load and apply them?

**Discussion:**

Add a `layer_checks` section to `gate_state.json`:

```json
{
  "layer_checks": [
    {
      "name": "no_sql_in_routes",
      "description": "SQL belongs in repositories/ only",
      "file_pattern": "/(routes?|controllers?|handlers?)/",
      "forbidden_patterns": [
        "SELECT|INSERT|UPDATE|DELETE|cursor\\.execute|executemany",
        "JdbcTemplate|entityManager\\.createNativeQuery"
      ],
      "ignore_patterns": ["#.*", "//.*"]
    }
  ]
}
```

In STEP 6.5, load and apply custom checks:

```bash
python3 -c "
import json, re
with open('$GATE_STATE') as f:
    d = json.load(f)
checks = d.get('layer_checks', [])
violations = []
changed = '''$CHANGED_FILES'''.split('\n')
for check in checks:
    fp_re = re.compile(check['file_pattern'], re.IGNORECASE)
    forbidden_re = [re.compile(p, re.IGNORECASE) for p in check['forbidden_patterns']]
    ignore_re = [re.compile(p) for p in check.get('ignore_patterns', [])]
    for f in changed:
        if not f or not fp_re.search(f): continue
        try:
            for lineno, line in enumerate(open(f), 1):
                if any(r.search(line) for r in ignore_re): continue
                if any(r.search(line) for r in forbidden_re):
                    violations.append(f'{check[\"name\"]} {f}:{lineno}: {line.strip()[:80]}')
        except: pass
for v in violations:
    print(v)
" 2>/dev/null
```

This makes STEP 6.5 completely language-agnostic: the patterns live in `gate_state.json` (human-maintained, PR-required), and gate.sh applies them without knowing anything about the specific language or framework.

---

# APPENDIX: Quick Reference

## gate.sh STEP Summary

| STEP | Name | Blocks on | Notes |
|------|------|-----------|-------|
| Pre-run | Context anchoring | Never (warn only) | CLAUDE.md drift |
| 1 | Branch validation | protected branch + code_writes_permitted=false | |
| 2 | Token harness | budget exhausted + active AI session | Human commits pass |
| 3 | Graph staleness | Never (warn only) | |
| 4 | Scan scope | — | Sets CHANGED_FILES |
| 4.3 | Core files | — | Escalates to Tier 3 |
| 4.4 | Brainstorm checkpoint | ≥5 files + no LATEST.md (agent only) | |
| 4.5 | Fingerprints | — | Receipt fast-path at pre-push |
| 4.6 | Push checkpoint | No checkpoint file (agent push only) | |
| 5 | Secrets scan | Credential patterns in diff | |
| 6 | Lint | New findings vs baseline | Ratchet: old debt grandfathered |
| 6.5 | Layer boundary | SQL in routes/services, HTTP in services | |
| 7 | Frontend checks | Frontend lint/type failures | |
| Tests | Test suite | Test failures (when RUN_TESTS=true) | |
| Coverage | Coverage gate | Below threshold | |
| Complexity | Complexity gate | cc > 10 | |
| 8 | Pass | — | Writes receipt + advances ledger |

## gate_state.json Key Fields

```
last_pass_sha           → SHA of last gate-passing commit (for incremental scan)
receipts                → ledger of gate-verified tree hashes (max 50)
token.token_spent_today → accumulated today's token spend
token.token_budget      → daily limit (null = use org_policy.json)
thresholds.coverage_pct → minimum test coverage (default 80)
thresholds.complexity_max → maximum cyclomatic complexity (default 10)
branch_strategy         → per-prefix rules including code_writes_permitted
core_files              → globs that force Tier-3 escalation
claude_md_hash          → SHA-256 of CLAUDE.md for drift detection
```

## Bash Idioms Used in gate.sh

| Idiom | Meaning |
|-------|---------|
| `${VAR:-default}` | Use VAR, or default if unset/empty |
| `${VAR%%/*}` | Remove longest suffix matching `/*` |
| `$( ... )` | Command substitution |
| `[[ ... ]]` | Extended test (bash built-in) |
| `command -v foo` | Check if foo is in PATH |
| `2>/dev/null` | Discard stderr |
| `|| true` | Prevent set -e from aborting |
| `>&2` | Send to stderr |
| `read -r REPLY < /dev/tty` | Read from physical terminal |

---

*End of ultimate_harness.md — Curriculum complete.*

*All code verbatim from commit `a7d3c04` (HEAD), incorporating patches from `630d3ad` (process-tree detection + graph kill-restart lifecycle) and `b400d7d` (date spoofing fix).*

---

<a name="addenda"></a>
# ADDENDA — Post-Publication Corrections & Updates

*Added after initial publication. These sections address pedagogical gaps identified in review and document changes made after the curriculum was first written.*

---

## A1. The Three-Tree Model and Why git write-tree Reads the Index

**Fills gap in:** Module 1 (Git Internals) and Module 8.2 (Receipt System)

### The Three Trees

Git maintains three distinct data structures at all times:

```
WORKING TREE          GIT INDEX (Staging Area)     OBJECT STORE (Commits)
─────────────         ────────────────────────     ──────────────────────
Files on disk         .git/index (binary file)     .git/objects/
Dirty, uncommitted    Snapshot of what will         Immutable, hashed,
Changes visible to    be committed next              permanent history
your editor           git add moves here
```

These are three **separate states**. A file can simultaneously be:
- Modified in the working tree (editor changes)
- Staged in the index (git add)
- In the last commit (object store)

All three versions can be different. This is not a bug — it's a feature. The index is a scratchpad for assembling the next commit.

### What git write-tree Actually Reads

```bash
git write-tree
```

This command:
1. Reads the Git Index binary file (`.git/index`)
2. For each entry in the index, looks up the blob object SHA
3. Recursively builds tree objects for each directory
4. Returns the SHA-1 of the root tree object

**Critical:** `git write-tree` reads ONLY from the index. It does NOT read from the working tree. Unstaged changes to files on disk are completely invisible to it.

```bash
# Demonstration:
echo "clean content" > file.py
git add file.py                       # file.py enters the index
echo "dirty change" >> file.py        # working tree modified
git write-tree                        # produces hash of "clean content" version
                                      # "dirty change" is NOT in the hash
```

This is why `COMMIT_TREE_FP = git write-tree` in the pre-commit hook is the correct fingerprint for "what is about to be committed" — it hashes exactly the index contents, which is exactly what `git commit` will commit.

### Why This Matters for the Gate

```
Developer edits auth.py (working tree)
     ↓
git add auth.py  →  index now contains the edited auth.py
     ↓
pre-commit fires  →  gate.sh  →  git write-tree  →  hash of index
     →  COMMIT_TREE_FP = "4b825dc..."
     →  gate checks auth.py (from index)  →  pass
     →  receipt written for "4b825dc..."
     ↓
Developer edits auth.py AGAIN without staging (working tree dirty)
     ↓
git push  →  pre-push fires  →  git rev-parse HEAD^{tree}
     →  COMMIT_TREE_FP = "4b825dc..."  (same — the commit has the pre-edit version)
     →  receipt found  →  fast path  →  push proceeds

The un-staged second edit never touched the index, never entered the commit,
and is correctly excluded from the receipt fingerprint.
```

### The Index Binary Format (Brief)

`.git/index` is a binary file, not human-readable. Its structure:
- Header: magic bytes `DIRC`, version number, entry count
- Entries: each file's metadata (mode, ctime, mtime, size, SHA-1, flags, filename)
- Extensions: optional TREE extension (cached tree hashes), REUC (reuse undo conflict)

You can inspect it with: `git ls-files --stage` (human-readable dump of the index).

---

## A2. Python Dict Traversal Mechanics in _json_get and _json_set

**Fills gap in:** Module 4.5 (gate.sh helper functions)

### The Full _json_get Implementation Explained

```python
def _json_get(file, dotted_key):
    with open(file) as f:
        d = json.load(f)          # parse entire JSON file into Python dict
    keys = dotted_key.split('.')  # "token.token_spent_today" → ["token", "token_spent_today"]
    v = d                         # start at the root dict
    for k in keys:
        if k == '': break         # guard against trailing dot: "token." → ["token", ""]
        v = v.get(k, '')          # descend one level; return '' if key missing
    print(v if v is not None else '')
```

**`v.get(k, '')`** — Python's `dict.get(key, default)` returns `default` if `key` is absent. This is safe: a missing key returns `''`, not a KeyError. Bash receives the empty string and the gate treats it as null/missing.

**What happens when the value is a dict (not a leaf):**
```python
# gate_state.json: {"last_pass_sha": {"feature/billing": "abc123"}}
# _json_get gate_state.json "last_pass_sha"
keys = ["last_pass_sha"]
v = d.get("last_pass_sha", '') → {"feature/billing": "abc123"}   # returns the dict
print(v) → "{'feature/billing': 'abc123'}"  # Python repr of dict — not useful
```
This is why you always key down to a leaf: `_json_get gate_state.json "last_pass_sha.feature/billing"` returns the string `abc123`.

---

### The Full _json_set Implementation Explained

```python
def _json_set(file, dotted_key, value):
    with open(file) as f:
        d = json.load(f)
    keys = dotted_key.split('.')           # "last_pass_sha.feature/billing"
                                           # → ["last_pass_sha", "feature/billing"]
    obj = d
    for k in keys[:-1]:                    # iterate all keys EXCEPT the last
        obj = obj.setdefault(k, {})        # descend, creating missing dicts on the fly
    val = value                            # the raw string from bash: '"abc123"'
    try:
        obj[keys[-1]] = json.loads(val)    # try to parse as JSON: '"abc123"' → str "abc123"
    except:
        obj[keys[-1]] = val                # fallback: store the raw string
    with open(file, 'w') as f:
        json.dump(d, f, indent=2)
```

**`keys[:-1]`** — Python slice notation. For a list `["a", "b", "c"]`:
- `[:-1]` returns `["a", "b"]` (all but last)
- `[-1]` returns `"c"` (last element)
- `[1:]` returns `["b", "c"]` (all but first)

So `for k in keys[:-1]` iterates every level EXCEPT the final key — these are the "path" segments you need to descend into. The final key is the one you actually assign to.

**`setdefault(k, {})`** — Python's `dict.setdefault(key, default)`:
- If `key` exists: returns its current value (does NOT overwrite)
- If `key` missing: inserts `key: default` and returns `default`

This creates the entire nested path on the fly:
```python
d = {}
obj = d
obj = obj.setdefault("last_pass_sha", {})   # d is now {"last_pass_sha": {}}
                                              # obj is now the inner {}
obj["feature/billing"] = "abc123"            # inner dict now has the key
# d is now {"last_pass_sha": {"feature/billing": "abc123"}}
```

**`json.loads(val)`** — deserializes the bash-passed value. Bash passes `'"abc123"'` (a JSON string literal including its outer quotes). `json.loads('"abc123"')` returns the Python string `abc123` without quotes. If parsing fails (val is a plain bash variable like `true` without JSON syntax), the except clause stores the raw string.

---

## A3. Git Notes Remote Syncing — The Refspec Gap

**Fills gap in:** Module 1.6 (git notes) and Module 9 (Bypass System)

### The Problem: git fetch Ignores Notes by Default

```bash
# Developer A bypasses, logs reason, and pushes the note:
SKIP_GATE=1 git commit -m "hotfix: urgent"
# → git notes appended to refs/notes/bypasses
git push origin refs/notes/bypasses   # explicitly pushed

# Developer B runs:
git fetch origin   # standard fetch
git log --show-notes=bypasses   # shows nothing — note is invisible
```

Why? Git's default fetch refspec only maps:
```
+refs/heads/*:refs/remotes/origin/*
```
Heads (branches) map to remote-tracking branches. `refs/notes/*` is not in `refs/heads/*` — it's a completely separate namespace. Standard `git fetch` ignores it entirely.

### The Fix: Configure the Notes Fetch Refspec

Each team member needs this configuration in their local `.git/config`:
```ini
[remote "origin"]
    fetch = +refs/heads/*:refs/remotes/origin/*
    fetch = +refs/notes/*:refs/notes/*
```

Command to add it:
```bash
git config --add remote.origin.fetch '+refs/notes/*:refs/notes/*'
```

After this, `git fetch origin` also fetches all notes namespaces. Developer B can now see Developer A's bypass record.

### Automating This in install.sh

The bootstrap should configure the notes refspec automatically:
```bash
git config --add remote.origin.fetch '+refs/notes/*:refs/notes/*'
_success "Git notes fetch refspec configured for bypass audit trail sync"
```

This is not currently in install.sh (a known gap). Teams using multi-developer bypass auditing need to add this manually or add it to their setup script.

### What Happens Without This Config

```
Timeline on a 5-person team:

Day 1:  Alice bypasses → pushes note to refs/notes/bypasses
Day 2:  Bob, Carol, Dave, Eve all git fetch → notes NOT fetched
Day 3:  Manager runs "git log --show-notes=bypasses --all" → sees NOTHING
        The bypass audit trail is invisible to everyone except Alice.

This is a silent failure — no error, no warning. The audit trail exists on
the remote but nobody's local clone knows it.
```

### The Full Audit Flow With Correct Config

```bash
# Set up (once per clone):
git config --add remote.origin.fetch '+refs/notes/*:refs/notes/*'

# Now the flow works end-to-end:
# 1. Alice bypasses and pushes the note:
git push origin refs/notes/bypasses

# 2. Bob fetches (with refspec configured):
git fetch origin
# → refs/notes/bypasses is now synced locally

# 3. Bob audits:
git log --all --show-notes=bypasses | grep -A3 "BYPASS"
# → shows Alice's bypass record with timestamp and reason
```

---

## A4. Post-Creation Changes — Token Budget & Install.sh Update

*Changes made in the session after ultimate_harness.md was first committed.*

### What Changed

After the curriculum was written, a review of `~/.claude/org_policy.json` revealed that the installed token budget (50,000/day) did not match the intent of the $20/month per-seat plan (~250,000 tokens/day), and that `install.sh`'s `DEFAULT_WEEKLY_LIMIT` (1,000,000) was mathematically inconsistent with that target.

**Two files were updated:**

| File | Field | Before | After | Why |
|------|-------|--------|-------|-----|
| `~/.claude/org_policy.json` | `TOKEN_BUDGET` | 50,000 | 250,000 | Match $20/month seat plan |
| `install.sh` | `DEFAULT_WEEKLY_LIMIT` | 1,000,000 | 1,250,000 | 1,250,000 × 20% = 250,000/day |

The math invariant: `WEEKLY_LIMIT × DAILY_BUDGET_PCT ÷ 100 = TOKEN_BUDGET`. Previously: 1,000,000 × 20% = 200,000 ≠ 50,000 (two different mismatches in the same system). After: 1,250,000 × 20% = 250,000 = TOKEN_BUDGET (consistent everywhere).

### Three Codebase Bugs Patched in the Same Session

Also in the same session, three bugs identified in the post-publication review (see the "Original Product & Codebase Gaps" analysis) were patched in `templates/gate.sh`:

**Bug 1 — LAST_SHA cross-branch contamination (STEP 4 + STEP 8)**

`last_pass_sha` was a single global string. Switching branches could cause `git diff LAST_SHA..HEAD` to compute a diff across unrelated lineages, silently dropping files from the incremental scan.

Fix: `last_pass_sha` is now a dict keyed by branch name (dots in branch names replaced with underscores):
```json
"last_pass_sha": {
  "feature/billing": "abc123",
  "bugfix/auth-fix": "def456"
}
```
Read: `_json_get gate_state.json "last_pass_sha.feature/billing"`  
Write: `_json_set gate_state.json "last_pass_sha.feature/billing" '"abc123"'`

`gate_state.json` template updated: `"last_pass_sha": {}` (was `null`).

**Bug 2 — Audit log inflation (no intra-day cap)**

The 90-day pruning window cuts nothing when all entries share today's timestamp. An AI agent in a loop could generate thousands of entries per hour.

Fix: hard cap of 1,000 entries, applied after the 90-day filter:
```python
MAX_AUDIT_ENTRIES = 1000
if len(log) > MAX_AUDIT_ENTRIES:
    log = log[-MAX_AUDIT_ENTRIES:]   # keep the most recent 1,000
```

**Bug 3 — PID reuse zombie killer (low-probability, high-impact)**

`kill -9` was fired on any live PID found in `.claude/graph.pid` without verifying the process was actually `code-review-graph`. OS PID reuse could cause an unrelated process (IDE, database, SSH agent) to be killed.

Fix: verify process identity before killing:
```bash
_GF_CMD=$(ps -p "$_GF_PID" -o command= 2>/dev/null | tr -d '\n' || echo "")
if echo "$_GF_CMD" | grep -q "code-review-graph"; then
    kill -9 "$_GF_PID" 2>/dev/null || true
else
    # PID reused by unrelated process — skip kill, remove stale pid file
    rm -f "$_GF_PID_FILE"
    return 0
fi
```

### PR History

| PR | Branch | Target | Status | Contents |
|----|--------|--------|--------|----------|
| [#1](https://github.com/BankofLoyal/ai-dev-workflow/pull/1) | `init_release` | `develop` | Merged | Full v1 framework scaffolding |
| [#2](https://github.com/BankofLoyal/ai-dev-workflow/pull/2) | `feat/token-budget-limits` | `develop` | Open | Token budget fix + curriculum + bug patches |

---

*ultimate_harness.md is a living document. Addenda are appended as bugs are found and fixes are shipped.*

---

## A5. Post-Completion Gap Fill — Four Missing Sections (2026-07-01)

*Changes made in the session after A4 was committed.*

A completeness review of the curriculum (conducted after all prior addenda were merged) identified four gaps where a learner could not implement or reason about the system from the curriculum alone. All four were inserted inline at the appropriate modules in the same session.

### Gap A — MCP Graph Internals (inserted as § 3.8.1)

**What was missing:** Module 3.8 said `code-review-graph` "builds a graph of modules, their relationships, and their impact radii" without ever defining what a node or edge is. Module 5.3 listed five MCP tool names and `max_hops` values — which are meaningless without knowing what the graph traversal operates on.

**What was added (§ 3.8.1):** Definition of nodes (named symbols with file+line, not files), edge types (calls/imports/inherits/uses_sql), BFS hop mechanics (hop 0 = changed symbol, hop N = Nth-degree dependents), per-tool descriptions (what each of the 5 tools is for), and the enforcement model (server-side capability restriction, not CLAUDE.md instruction).

### Gap B — Init Prompt Two-Phase Flow (expanded § 11.4)

**What was missing:** Module 11.4 was 7 lines saying "a structured set of questions." A learner finishing the curriculum could not write a CLAUDE.md from scratch, which means they could not deploy the system.

**What was added (§ 11.4):** The two-phase process in full: Phase 1 (read-only recon → discovery report for human review), Phase 2 (generation of CLAUDE.md + settings.json + baseline.json + gate.sh config section from the corrected report), the actual content of each generated file, and the rationale for why automation cannot replace the human review step (rules that don't exist in code yet, severity hierarchies, business-context security invariants, core-file escalation decisions).

### Gap C — CI Gate YAML Walkthrough (inserted as § 10.10)

**What was missing:** `templates/ci-gate.yml` was referenced 5 times in the curriculum as "the authoritative backstop" but its YAML was never shown and its CI-specific mechanics were never explained.

**What was added (§ 10.10):** Full annotated YAML, four CI-specific mechanics with explanation (`fetch-depth: 0` for full history, `GATE_TRIGGER=ci`, `RUN_TESTS=true` disabling the receipt fast path, governance file integrity check), and the division of responsibility between local gate (fast, receipt-optimized feedback loop) and CI gate (authoritative backstop for protected branches).

### Gap D — `execution_mode_log` Field (inserted as § 5.5.1)

**What was missing:** `gate_state.json` contains `"execution_mode_log": []` which is never read or written by gate.sh v1.0. A learner reading the schema with no documentation for this field would assume it was a bug or a failed run.

**What was added (§ 5.5.1):** The field is a reserved schema slot for a future feature that would audit which execution mode (MUST OUTPUT / HARD STOP / EXECUTE) each agent session declared. An empty array is the correct state in v1.0 installations. The section explains why the slot is scaffolded now (forward-compatibility, avoids schema migration when the feature ships).
