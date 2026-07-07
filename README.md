# Gate

**The master corporate home for all automated AI developer workflows.**

This repository is the single source of truth for deploying enterprise-grade AI development
governance across engineering teams. It currently covers **Claude Code** and is structured
to accommodate future tool integrations (Cursor, Copilot, and others) as they mature.

## Prerequisites

This framework is **bash + POSIX-tool based** and has no Windows-native path.

- **OS:** macOS or Linux. Windows users must run it inside **WSL2** (Ubuntu or similar) — a native `cmd.exe`/PowerShell shell is not supported and install.sh/uninstall.sh will fail or behave unpredictably there.
- **Required on `PATH`:** `git`, `bash` (3.2+, the macOS-default version is fine — nothing here requires bash 4), `python3` (stdlib only, no pip packages required by the framework itself).
- **Required to actually use it:** the [Claude Code CLI](https://claude.ai/download) — `install.sh` only *warns* if it's missing (not a hard block), so it's possible to run the whole installer and only discover at the final step (`/init-governance`) that Claude Code was never installed. Install it before you start.
- **Optional:** `pipx` (only needed for the MCP graph-server integration; the framework degrades gracefully without it).

If `git` or `python3` is missing, `install.sh` fails fast with a message naming the missing dependency — it does not partially install.

## Active Branch

`develop` is the active integration branch. All releases are cut from `develop` and all
feature contributions target `develop`. Never work directly on `main`.

## Where to Start

Everything you need is inside the [`v1_release/`](v1_release/) folder.

Start there. The README inside will route you to the correct deployment basket for your team.

## Repository Structure

```
Gate/
└── v1_release/                  ← V1 production release of the governance framework
    ├── basket-1-brownfield/     ← For teams with existing, active codebases
    └── basket-2-greenfield/     ← For teams starting brand-new projects
```

## 🧪 Testing — Opt-In at Commit, Mechanical at Push

Tests are **opt-in at pre-commit** to keep day-to-day commits fast, but **mandatory and
mechanical** at the enforcement boundaries — code cannot leave a machine or merge untested.

| Stage | Tests run? |
|---|---|
| `git commit` (normal) | Opt-in — add `--run-tests=true` to the commit message |
| `git commit` touching a **CORE_FILES** path | Always (full suite, forced) |
| `git push` | Always (full suite, or a verified pre-commit receipt) |
| CI (`.github/workflows/gate.yml`) | Always (authoritative backstop) |

Example: `git commit -m "feat: added login logic --run-tests=true"`. A coverage gate
(default 80%) blocks when configured and unmet. See each basket README for details.

## Tooling Coverage

| Tool | Status |
|---|---|
| Claude Code | V1 — Available now |
| Cursor | V1 — Available (IDE extension crash guard + full handoff; see handoff_cursor.md) |
