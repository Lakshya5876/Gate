#!/usr/bin/env python3
"""PreToolUse guard (mcp__code-review-graph__* matcher) — warns, never blocks,
when a graph query tool is about to answer against a possibly-stale index.

_ensure_graph_freshness/_ensure_graph_alive (gate.sh) only rebuild at commit
boundaries. A live session querying get_impact_radius_tool mid-task has no
guarantee the index reflects HEAD, let alone uncommitted changes. This script
closes that visibility gap at the one point it actually matters: query time.

Reuses gate_state.json's existing mcp_graph.last_build_timestamp — no new
schema field for "indexed sha" needed, since commit recency is enough to
detect drift. Receives tool input JSON on stdin, same contract as
pre_bash_trust_root_guard.sh. Always exits 0 (allow) — a query answering
"here's what's stale" is more useful than a blocked query; this is
resilience/visibility, not an enforcement gate.
"""
import json
import shutil
import subprocess
import sys
from datetime import datetime, timezone

GATE_STATE = ".claude/gate_state.json"
GRAPH_EXTENSIONS = (".ts", ".tsx", ".py", ".go", ".java")
# Below this line count, a synchronous rebuild-on-demand is attempted for
# STALE_COMMITS (not STALE_DIRTY — uncommitted work was never going to be
# indexed by a rebuild anyway). Above it, fall back to warn-only so an
# interactive query never hangs on a multi-minute rebuild for a 1M-LOC repo.
SYNC_REBUILD_LOC_CEILING = 50_000


def _run(cmd):
    # Deliberately no .strip() here: git status --porcelain's status columns
    # are fixed-width and start at column 0 — stripping the blob would eat
    # the leading status characters off the FIRST line only (str.strip()
    # trims the whole string's ends, not each line), corrupting exactly the
    # line most callers care about. Callers that want a single scalar value
    # (rev-parse, log --format) strip at the call site instead.
    try:
        return subprocess.run(
            cmd, capture_output=True, text=True, timeout=10
        ).stdout
    except Exception:
        return ""


def _read_gate_state():
    try:
        with open(GATE_STATE) as f:
            return json.load(f)
    except Exception:
        return None


def _repo_loc():
    out = _run(["git", "ls-files"])
    if not out:
        return None
    files = [f for f in out.splitlines() if f.endswith(GRAPH_EXTENSIONS)]
    if not files:
        return 0
    wc = _run(["wc", "-l", *files])
    if not wc:
        return None
    last_line = wc.strip().splitlines()[-1]
    try:
        return int(last_line.strip().split()[0])
    except Exception:
        return None


def main():
    try:
        json.load(sys.stdin)  # tool_input isn't needed, but drain stdin per hook contract
    except Exception:
        pass

    state = _read_gate_state()
    if state is None:
        return 0  # framework not fully installed — nothing to check

    last_build = state.get("mcp_graph", {}).get("last_build_timestamp")
    if not last_build:
        print(
            "[GRAPH STALE] No graph build recorded yet (mcp_graph.last_build_timestamp "
            "is null) — query results are not backed by any index.",
            file=sys.stderr,
        )
        return 0

    last_commit_iso = _run(["git", "log", "-1", "--format=%cI"]).strip()
    dirty = _run(["git", "status", "--porcelain"])
    dirty_graph_files = [
        line[3:] for line in dirty.splitlines()
        if line[3:].endswith(GRAPH_EXTENSIONS)
    ]

    try:
        build_dt = datetime.fromisoformat(last_build.replace("Z", "+00:00"))
        commit_dt = (
            datetime.fromisoformat(last_commit_iso) if last_commit_iso else None
        )
    except Exception:
        build_dt = commit_dt = None

    stale_commits = bool(commit_dt and build_dt and commit_dt > build_dt)

    if dirty_graph_files:
        print(
            f"[GRAPH STALE] {len(dirty_graph_files)} uncommitted change(s) to "
            f"indexed-extension files since the last build — results may not "
            f"reflect your current working tree: {', '.join(dirty_graph_files[:5])}"
            + (" ..." if len(dirty_graph_files) > 5 else ""),
            file=sys.stderr,
        )

    if stale_commits and not shutil.which("code-review-graph"):
        print(
            "[GRAPH STALE] HEAD has moved since the last build, and "
            "code-review-graph isn't on PATH to rebuild — query is answering "
            "against a stale index.",
            file=sys.stderr,
        )
    elif stale_commits:
        loc = _repo_loc()
        if loc is not None and loc <= SYNC_REBUILD_LOC_CEILING:
            print(
                "[GRAPH STALE] HEAD has moved since the last build — "
                "rebuilding synchronously before answering (repo is "
                f"{loc} indexed LOC, below the {SYNC_REBUILD_LOC_CEILING} sync-rebuild ceiling).",
                file=sys.stderr,
            )
            try:
                subprocess.run(
                    ["code-review-graph", "build"],
                    capture_output=True,
                    timeout=120,
                )
            except (subprocess.TimeoutExpired, OSError):
                print(
                    "[GRAPH STALE] Synchronous rebuild failed or timed out — "
                    "query is answering against the last-known-good index.",
                    file=sys.stderr,
                )
        else:
            print(
                "[GRAPH STALE] HEAD has moved since the last build and the repo "
                f"is above the {SYNC_REBUILD_LOC_CEILING}-LOC synchronous-rebuild "
                "ceiling — a background rebuild will run at the next commit; "
                "this query is answering against the last-built index.",
                file=sys.stderr,
            )

    return 0


if __name__ == "__main__":
    sys.exit(main())
