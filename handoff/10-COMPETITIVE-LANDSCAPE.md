# 10 — Competitive Landscape

_What this covers: an honest comparison of `Gate` against the tools it's most often confused with — gstack, ECC, rea, and Claude Code's own native controls — plus the newer direct competitors. Where this framework is stronger, where it's weaker, and why most of these are complementary, not either/or. Dated research (July 2026); sources at the bottom._

**Read [`09-FUTURE-ROADMAP.md`](09-FUTURE-ROADMAP.md) first if you haven't** — the strategic "so what" of this comparison lives there. This doc is the evidence.

## The one-paragraph summary

`Gate` competes in a specific lane: **deterministic, agent-agnostic, un-bypassable governance at the git + CI layer.** It is *not* a workflow/skills product (that's gstack and ECC's lane) and *not* a runtime MCP gateway (that's rea's). Its genuine edges are (1) enforcement that binds *humans and agents equally* because it lives in git/CI, not the agent; (2) deterministic architecture/debt/layer checks with a brownfield debt ratchet; and (3) unusual honesty about its own limits. Its genuine weaknesses are workflow depth, prompt-injection defense, no MCP gateway, Claude-only agent-side hooks today, and a trust anchor that isn't yet cryptographically externalized. Most of these tools are **complementary**: a mature team could run gstack for workflow, Claude Code's native sandboxing/permissions for agent-side control, and `Gate` as the un-bypassable floor underneath both.

## Category map — these are not all the same thing

| Tool | Category | Primary enforcement point | Agent scope |
|------|----------|---------------------------|-------------|
| **Gate** (this) | Deterministic git+CI governance | git hooks + CI gate | agent-agnostic at git; Claude-only agent hooks |
| **gstack** | Workflow / role orchestration | agent prompts + skills; git-hook team sync | Claude Code |
| **ECC** | Config / skills / agents mega-pack | Claude Code config | Claude Code |
| **rea** | Runtime zero-trust MCP gateway | MCP proxy + Claude hooks | Claude Code |
| **sworn** | Deterministic git+CI governance | git+CI, fail-closed | multi-agent (git-level) |
| **RipStop** | Multi-agent git-boundary policy | git boundaries (path/history) | Cursor/Claude/Codex/Amazon Q/human |
| **Claude Code native** | Platform controls | server-managed settings, hooks, sandbox | Claude Code |

## Head-to-head

### vs. Claude Code native permissions/hooks/sandboxing

This is the most important comparison because the platform is now the biggest "competitor" — it does natively much of what the framework's `.claude/` layer does by hand.

- **Where the platform is now stronger:** OS-level sandboxing (bubblewrap/Seatbelt, since Oct 2025; Docker microVMs Jan 2026) [CC-Sandboxing; TrueFoundry-2026]; server-managed, un-overridable permission/hook enforcement delivered from an org console (`allowManagedHooksOnly`, `disableBypassPermissionsMode`) [CC-ServerManaged; CC-Permissions]; and HTTP hooks streaming every event to a SIEM [CC-Hooks]. The framework's client-side `$CLAUDECODE` detection (`gate.sh:280-319`) and local token deterrent are simply weaker than what the platform can enforce centrally.
- **Where this framework is still stronger:** it governs the **git+CI boundary**, which the platform does not touch — so it binds *human* commits and *any* agent's output identically, and it survives even if someone swaps agents or edits outside the harness. It also enforces *architecture and debt* (layer boundaries, complexity ceilings, coverage floors, the brownfield debt ratchet) that Claude Code's permission model has no concept of.
- **Verdict: complementary.** Lean on the platform for agent-side sandboxing/permissions (roadmap P1.3, "don't reimplement"); keep the git+CI + architecture/debt backstop as the differentiator.

### vs. gstack (~90K stars)

- **What it is:** a role-based workflow/skills system (personas, skills, commands) with a git-hook "team mode" that syncs shared config across a team [gstack-Augment-2026].
- **Where gstack wins:** workflow depth, developer ergonomics, mindshare, and structuring *how* an agent works through a task.
- **Where this framework wins:** gstack's guidance is advisory/prompt-shaped; it does not deterministically *block* a non-compliant commit at CI regardless of the agent's cooperation, and it's Claude-specific. This framework does.
- **Verdict: complementary and non-overlapping** — gstack shapes the work; this enforces the floor.

### vs. ECC — "Everything Claude Code" (~224K stars)

- **What it is:** a large curated pack of agents/skills/commands/hooks for Claude Code [ECC-GitHub-2026].
- **Where ECC wins:** breadth of ready-made capability and community momentum.
- **Where this framework wins:** ECC is configuration/capability, not un-bypassable enforcement; it does not provide a CI backstop that holds when the agent (or a human) doesn't cooperate, nor a debt ratchet.
- **Verdict: complementary** — ECC expands what the agent can do; this constrains what any actor can land.

### vs. rea (the closest *governance* competitor)

- **What it is:** a zero-trust governance layer for Claude Code — a policy-enforcing MCP gateway with a HALT kill-switch, hash-chained tamper-evident audit log, prompt-injection defense, and fail-closed behavior [rea].
- **Where rea wins:** it governs the **runtime/tool-call** path this framework barely touches — MCP gateway, live prompt-injection defense, an org kill-switch, and hash-chained logs (this framework's audit trail is git-notes-based and unsigned today — [`08-KNOWN-ISSUES-AND-DEBT.md`](08-KNOWN-ISSUES-AND-DEBT.md)).
- **Where this framework wins:** rea is Claude-hook-bound and runtime-focused; it doesn't own the **git+CI + architecture/debt** boundary or bind human commits. Different layer of the stack.
- **Verdict: complementary, and rea is the clearest source of roadmap ideas** — hash-chained logs, kill-switch, prompt-injection awareness all appear as roadmap items in [`09-FUTURE-ROADMAP.md`](09-FUTURE-ROADMAP.md) (P1.4, moonshots).

### vs. sworn and RipStop (direct git-boundary competitors — newer)

- **sworn:** deterministic, fail-closed AI code governance with tamper-evident logs and CMMC mapping [sworn] — nearly the same thesis as this framework. It's ahead on tamper-evident logging; this framework is arguably ahead on the brownfield debt ratchet, the checkpoint/graph integration, and the two-basket install story.
- **RipStop:** multi-agent policy at git boundaries (path-guard, history-guard, reflog-witness) across Cursor/Claude/Codex/Amazon Q/human [RipStop] — explicitly multi-harness, which is this framework's P1.2 aspiration but RipStop's shipping reality.
- **Verdict: direct competition on thesis.** The differentiators to defend are architecture/debt enforcement, honesty, and the install/upgrade UX; the gap to close is multi-harness (P1.2) and signed logs (P1.4).

## Honest scorecard

Rough, opinionated, mid-2026. ✅ strong · ◓ partial · ❌ absent/weak.

| Capability | this | gstack | ECC | rea | sworn | RipStop | CC native |
|---|---|---|---|---|---|---|---|
| Un-bypassable CI backstop | ✅ | ❌ | ❌ | ◓ | ✅ | ◓ | ◓ (managed) |
| Binds humans == agents | ✅ | ❌ | ❌ | ❌ | ✅ | ✅ | ❌ |
| Architecture/layer/debt enforcement | ✅ | ❌ | ❌ | ❌ | ◓ | ◓ | ❌ |
| Brownfield debt ratchet | ✅ | ❌ | ❌ | ❌ | ◓ | ❌ | ❌ |
| Deterministic (no LLM in loop) | ✅ | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ |
| Agent-agnostic | ◓ (git yes / hooks no) | ❌ | ❌ | ❌ | ✅ | ✅ | ❌ |
| Workflow/skills depth | ❌ | ✅ | ✅ | ❌ | ❌ | ❌ | ◓ |
| Prompt-injection defense | ❌ | ❌ | ❌ | ✅ | ◓ | ◓ | ◓ |
| MCP gateway / runtime tool control | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ | ◓ |
| Signed / tamper-evident audit log | ❌ (git notes, unsigned) | ❌ | ❌ | ✅ | ✅ | ◓ | ◓ (HTTP hooks) |
| OS-level sandboxing | ❌ (defers to platform) | ❌ | ❌ | ◓ | ❌ | ❌ | ✅ |
| Honest self-disclosed limits | ✅ | — | — | ◓ | ◓ | — | ◓ |

(Note: the ◓ glyph = partial. Star counts and features are as researched in July 2026 and move fast — re-verify before quoting externally.)

## Takeaways for the new owner

1. **Don't fight gstack/ECC.** Different product. Integrate: they own workflow, you own the floor.
2. **Watch sworn and RipStop closely** — they share your exact thesis and are ahead on tamper-evident logs / multi-harness respectively. Those are your P1 priorities for a reason.
3. **Position with, not against, Claude Code native.** The platform is your sandboxing/permission engine; you're the git+CI + architecture backstop that outlives any single agent.
4. **Your defensible core:** deterministic architecture/debt enforcement + human-equals-agent + brownfield ratchet + honesty. Everything in the roadmap sharpens one of those.

## Sources

All accessed July 2026 (same reference list as [`09-FUTURE-ROADMAP.md`](09-FUTURE-ROADMAP.md#sources); condensed here):

- Claude Code docs — *Hooks*, *Permissions*, *Server-managed settings*, *Sandboxing*, *Sandbox environments* (code.claude.com/docs).
- TrueFoundry — *Claude Code Sandboxing* (native sandboxing Oct 2025; Docker Sandboxes Jan 2026).
- github.com/garrytan/gstack + Augment Code writeup (~89.7K stars; role/skills + git-hook team sync).
- github.com/affaan-m/ECC — *Everything Claude Code* (~224K stars).
- github.com/bookedsolidtech/rea — zero-trust MCP gateway, HALT kill-switch, hash-chained audit log, prompt-injection defense.
- github.com/cjchanh/sworn — deterministic fail-closed governance, tamper-evident logs, CMMC.
- github.com/jonverrier/RipStop — multi-agent git-boundary policy (path/history/reflog guards).
- Endor Labs — *Introducing Agent Governance: Using Hooks* (2026).
- RanTheBuilder — *Agentic Coding Hooks: Deterministic AI Guardrails* (2026; Cursor/Codex/Gemini/Copilot hook parity).

---

next: [`11-PITCH-ASSETS.md`](11-PITCH-ASSETS.md)
