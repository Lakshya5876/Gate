# 09 — Future Roadmap

_What this covers: a staff-engineer strategy memo for the next owner — where this framework sits versus the platform and the field as of mid-2026, a prioritized P0/P1/P2 roadmap grounded in real code gaps and dated external research, some moonshots, an explicit "don't do this" list, and a 30/60/90-day sequence._

This is opinionated on purpose. Every gap is tied to a specific file/mechanism; every external claim is dated and sourced (see [Sources](#sources)). Research was conducted July 2026.

---

## State of the world

**The ground shifted under this framework between its design and now.** When `Gate` was built, the strongest available governance surface for an AI coding agent was git hooks + CI + a hand-rolled Claude Code hook layer. That was the right bet. But in the last ~9 months the *platform itself* grew a serious, deterministic governance surface, and a crowd of competitors converged on the exact same "deterministic hooks + git/CI, not prompts" thesis.

Three things matter most:

1. **Claude Code now ships native, enterprise-grade, deterministic controls this framework partly re-implements.** Server-managed settings (org-console-delivered, un-overridable) can enforce `permissions.deny`/`allow`, force `allowManagedHooksOnly` / `allowManagedPermissionRulesOnly`, and set `disableBypassPermissionsMode` — centrally, above user/project settings [CC-Permissions; CC-ServerManaged]. There's a full lifecycle hook system (PreToolUse/PostToolUse/Stop/SessionStart/PreCompact and more) with `exit 2`/`deny` semantics identical to what this repo's hooks assume, plus **HTTP hooks** that stream every event to a SIEM with `allowedHttpHookUrls` [CC-Hooks]. And native **OS-level sandboxing** (bubblewrap/Seatbelt, since Oct 2025) with `sandbox.failIfUnavailable` and `allowUnsandboxedCommands`, extendable to the whole process via `@anthropic-ai/sandbox-runtime`, plus microVM Docker Sandboxes (Jan 2026) [CC-Sandboxing; CC-SandboxEnv; TrueFoundry-2026]. **Implication:** several of this framework's cleverest hacks — the client-side `$CLAUDECODE` detection, the deny-list, the local-only token deterrent — are now things the *platform* can do more robustly. The framework should **lean on** the platform for agent-side enforcement and **double down** on what the platform still doesn't do: the git+CI backstop, the architecture/debt/layer enforcement, and the cross-actor (agent *and* human) equivalence.

2. **The competitive field caught up to — and in places passed — the core thesis.** "Deterministic guardrails, not prompts" is now a consensus, not a differentiator [Endor-2026; RanTheBuilder-2026]. Direct governance competitors exist: **rea** ships a zero-trust MCP gateway with a HALT kill-switch, hash-chained audit log, and prompt-injection defense; **sworn** does deterministic fail-closed git+CI governance with tamper-evident logs and CMMC mapping; **RipStop** does multi-agent git-boundary policy with path-guards and a reflog witness. Meanwhile **gstack** (~90K stars) and **ECC** (~224K stars) own the *workflow/skills* mindshare this framework doesn't play in. See [`10-COMPETITIVE-LANDSCAPE.md`](10-COMPETITIVE-LANDSCAPE.md). **Implication:** the durable moat is not "we have hooks" — it's the *combination* of un-bypassable git+CI enforcement, deterministic architecture/debt checks, agent-agnosticism, and radical honesty about limits. Sharpen that; stop spending effort where the platform or an OSS competitor already wins.

3. **The surrounding compliance and supply-chain world moved from "keep logs" to "prove it, cryptographically, at runtime."** 2026 guidance (SOC 2, ISO 42001, EU AI Act Art. 12/13) converges on: runtime policy enforcement (not after-the-fact observation), cryptographically signed tamper-evident audit trails tied to agent identity, and policy-as-code with a deny-by-default posture [Omnithium-2026; DevTo-AuditTrail-2026; Diagrid-2026; CloudMatos-2026]. Supply-chain expectations jumped to SLSA provenance + SBOM/ML-BOM + signed attestations verified at admission [Cloudsmith-2026; CallSphere-2026; TechBytes-SLSA-2026]. Simultaneously, MCP became "one of the most rapidly weaponized attack surfaces" — an April 2026 OX Security disclosure found a design-level STDIO-transport RCE across every official SDK (~200k vulnerable instances), on top of tool-poisoning as the #1 OWASP LLM risk [CSA-MCP-RCE-2026; CSA-MCP-Crisis-2026; MCP-ThreatModel-2026; OWASP-MCP]. **Implication:** this framework already has the *skeleton* of what auditors now want (git-notes bypass trail, token audit log, deterministic policy). The opportunity is to harden that skeleton into signed, queryable, control-mapped evidence — and to treat its own pinned MCP dependency as a supply-chain risk to be attested, not just pinned.

**Net positioning:** `Gate` should reposition from "the hook layer that governs Claude Code" (a space the platform and OSS now crowd) to **"the deterministic, agent-agnostic, un-bypassable architecture-and-compliance backstop that sits under whatever agent and platform controls you already run."** Complementary, not competing, with Claude Code's native controls — and the thing that still works when the agent, the harness, or the human tries to route around them.

---

## Prioritized roadmap

Effort: **S** = days, **M** = 1–3 weeks, **L** = 1–3 months. Each item: Problem (grounded) · Approach · Why now · Effort · Risks/deps · Sources.

### P0 — do these first (close credibility gaps, cheap, high trust value)

**P0.1 — Ship a `verify-governed` / `doctor` command.**
- *Problem:* the framework's strongest guarantee (trust-root protection) depends on manual steps — CODEOWNERS with a real team + branch protection — that nothing verifies (`install.sh:920-950`, `1201-1213`). Notes refspecs, `org_policy.json`, and graph mode all degrade silently (`install.sh:952-955`, [`08-KNOWN-ISSUES-AND-DEBT.md`](08-KNOWN-ISSUES-AND-DEBT.md) #4, #22).
- *Approach:* one script that checks core.hooksPath, integrity manifest verify, refspec presence, org policy presence, graph node count, and — via the GitHub API with a token — whether branch protection + Code Owner review are actually on. Exit non-zero + a checklist. Wire it into `ci-gate.yml` as an advisory step.
- *Why now:* it's the difference between "we installed controls" and "the controls are active." Cheap, and every competitor's install story is judged on exactly this.
- *Effort:* S–M. *Risks:* the branch-protection check needs a token/permissions; degrade gracefully without one.
- *Sources:* internal (`docs/SECURITY_POSTURE.md:131`); [DevTo-AuditTrail-2026] (runtime-proof expectation).

**P0.2 — Reconcile the code/doc drift that erodes trust.**
- *Problem:* branch-name inconsistency (`develop` vs `init_release` vs working branch), the `refs/notes/gate-bypasses` vs `refs/notes/bypasses` naming error in `v1_release/README.md:48-51`, the "zero network at gate time" claim vs the latent S3 path (`gate.sh:393-441`), and CODEOWNERS listing paths absent from this repo while omitting `templates/` ([`08-KNOWN-ISSUES-AND-DEBT.md`](08-KNOWN-ISSUES-AND-DEBT.md) #9, #15, #16, #18).
- *Approach:* pick one integration branch; fix the refspec name; either wire or remove the S3 path (see P1.3); add a CODEOWNERS entry over the framework's *actual* trust root (`templates/`, `install.sh`, `uninstall.sh`, `v1_release/**`).
- *Why now:* a new owner and any security reviewer will hit these in the first hour; each one cheaply undermines an otherwise credible system.
- *Effort:* S. *Risks:* none material. *Sources:* internal.

**P0.3 — Add a real secrets scanner to the CI path (keep the fast one at commit).**
- *Problem:* the built-in scan is keyword+format only and says so (`gate.sh:736-763`, `docs/SECURITY_POSTURE.md:132`).
- *Approach:* add gitleaks (or trufflehog) as a standard step in `ci-gate.yml`, scoped to the diff; keep the in-gate grep for fast local feedback.
- *Why now:* secret leakage from AI agents is a top enterprise fear; this is a one-file change that closes the most-cited scan gap without slowing commits.
- *Effort:* S. *Risks:* tool availability in CI; pin the version (supply chain). *Sources:* [OWASP-MCP]; internal disclosure.

### P1 — the strategic core (where the moat actually is)

**P1.1 — Externalize the trust anchor: sign/attest the integrity manifest.**
- *Problem:* the manifest proves internal self-consistency only — one PR can move `gate.sh` and its pin together (`docs/SECURITY_POSTURE.md:131`). This is the single biggest hole and it's disclosed, not fixed.
- *Approach:* in CI, verify the manifest signature against an org-held key or a keyless Sigstore/cosign attestation tied to the workflow identity, and (P0.1) require branch protection so the workflow itself can't be edited un-reviewed. Emit a SLSA-style provenance statement for the governance file set.
- *Why now:* the whole industry moved to signed, non-falsifiable provenance verified at admission (SLSA L3/L4, cosign keyless, Kyverno) — this framework's core claim ("the agent can't weaken its own gate") is only as strong as this anchor [TechBytes-SLSA-2026; Cloudsmith-2026; CallSphere-2026].
- *Effort:* M. *Risks:* key management / Sigstore availability (need a break-glass path); adds a CI dependency. *Sources:* [SLSA/cosign refs above]; internal `install.sh:296-332`.

**P1.2 — First-class multi-harness support (agent-agnostic in fact, not just at git).**
- *Problem:* git-level enforcement is already tool-agnostic, but the *agent-hook hardening* (Bash guard, checkpoint capture, freshness) and detection are Claude-specific (`gate.sh:280-319`, `.claude/`), and `README.md:55-60` defers other tools.
- *Approach:* the hook contract this repo relies on (JSON on stdin, `exit 2` to block) is now the de-facto standard adopted by Cursor 1.7, OpenAI Codex, Gemini CLI, and Copilot CLI [RanTheBuilder-2026]. Add adapters that emit the same guards into Cursor/Codex hook configs; keep the git+CI gate identical across harnesses (RipStop and rea already market "same rules whoever produced the diff").
- *Why now:* teams run multiple agents; "one gate for all of them" is a genuine differentiator gstack/ECC don't offer and the platform can't (it's Claude-only). It also future-proofs against harness churn.
- *Effort:* L. *Risks:* per-harness hook-schema drift; scope creep — keep the git gate the source of truth and treat harness hooks as thin front-ends. *Sources:* [RanTheBuilder-2026]; [RipStop]; internal.

**P1.3 — Make the token/policy control real (or cut it).**
- *Problem:* the budget is a local, editable, per-machine file — explicitly *not* centrally enforced (`docs/SECURITY_POSTURE.md:118`), and the half-built S3 path (`gate.sh:393-441`) straddles fantasy and feature.
- *Approach:* replace the local file with a signed org policy fetched at CI/gate time (reuse P1.1's signing), or — better — delegate spend control to Claude Code's server-managed settings and make this framework *consume/verify* rather than reimplement it [CC-ServerManaged]. If neither, remove the S3 code and market the budget honestly as a local deterrent.
- *Why now:* auditors now expect central, tamper-evident policy tied to identity, not a machine-local file [CloudMatos-2026; Diagrid-2026; CIO-AgenticConstitution-2026].
- *Effort:* M–L. *Risks:* org-infra dependency; don't over-build — deleting the S3 path is a legitimate outcome.

**P1.4 — Turn the audit trail into signed, control-mapped, queryable evidence.**
- *Problem:* the bones exist (`refs/notes/bypasses`, `token_audit_log`, deterministic outcomes) and `docs/SECURITY_POSTURE.md:113-123` already maps to SOC 2, but the evidence isn't cryptographically signed or exportable as an auditor bundle.
- *Approach:* hash-chain the token audit log (rea already does hash-chained logs); sign bypass notes; add an `evidence export` that bundles gate outcomes tagged with control refs (CC6.1/6.8/7.2/8.1, EU AI Act Art. 12) for a given date range.
- *Why now:* "runtime governance, not an observer; signed, not just logs" is the explicit 2026 bar [DevTo-AuditTrail-2026; Omnithium-2026; CloudMatos-2026].
- *Effort:* M. *Risks:* scope; start with hash-chaining + export, defer full GRC integration. *Sources:* above + internal.

**P1.5 — Treat the pinned MCP server as a supply-chain risk, not just a pin.**
- *Problem:* `code-review-graph==2.3.6` is pinned by version only (`install.sh:34`), its CLI has drifted before (`install.sh:1046-1078`), and MCP is a top 2026 attack surface (tool poisoning, STDIO RCE) [CSA-MCP-RCE-2026].
- *Approach:* pin by hash (not just version), verify on install; run the graph server under Claude Code's sandbox-runtime (deny-by-default network/fs); treat its tool responses as untrusted; add a post-install "graph has N nodes" assertion so silent-failure (#11) is loud.
- *Why now:* the MCP threat landscape is active and severe; a governance tool that ships an unhardened MCP dependency is a bad look [MCP-ThreatModel-2026; OWASP-MCP; IETF-MCP-2026].
- *Effort:* M. *Risks:* hash pinning breaks on legit upstream updates (that's the point — force a review).

### P2 — valuable, later

**P2.1 — Inferred lint/type defaults for Node/Go (close the multi-language gap).** Python is first-class; other stacks silently no-op lint/type unless configured (`gate.sh:995-1017` vs the test-only inference at `845-923`, [`08-KNOWN-ISSUES-AND-DEBT.md`](08-KNOWN-ISSUES-AND-DEBT.md) #21). Add eslint/tsc and `go vet`/staticcheck inference. *Effort:* M.

**P2.2 — Cross-file layer-boundary via the graph.** The grep + AST supplements can't resolve re-export shims (`docs/SECURITY_POSTURE.md:134`). Use code-review-graph's resolve tooling to close it — a natural payoff for already shipping the graph. *Effort:* M–L.

**P2.3 — Checkpoint index rotation + a hermetic fast test target.** Index grows unbounded (#14); pty/network tests are flaky locally (#19, #20). Add rotation and a `make test-fast` that skips the non-hermetic files. *Effort:* S–M.

**P2.4 — SBOM/ML-BOM emission for governed repos.** As a value-add, have the gate (or CI) emit a CycloneDX SBOM on release so governed repos inherit supply-chain provenance. *Effort:* M. *Sources:* [CallSphere-2026; Cloudsmith-2026].

---

## Moonshots / creative bets

- **"Governance-as-code you can prove."** Compile the whole gate into a signed, versioned policy bundle (à la OPA) with per-decision signed artifacts, so any blocked/allowed event replays to the exact policy version that decided it — the Aegis/OPA pattern, but for the *dev-time* boundary instead of runtime API calls [CloudMatos-2026]. This turns the framework from "a gate" into "a queryable compliance system of record" for AI-authored code. High differentiation; large effort.
- **Prompt-injection-aware gate.** MCP tool-poisoning and indirect prompt injection now persist across sessions [CSA-MCP-Crisis-2026; OWASP-MCP]. A `PostToolUse`/graph-query hook that flags when *external tool output* preceded a suspicious trust-root-adjacent action could catch the injected-instruction class that a pre-commit grep never will. Research-grade, but nobody in the git-gate space is doing it.
- **A `HALT` kill-switch + org-wide freeze.** rea ships one; this framework doesn't. A signed org flag that fail-closes every governed repo's gate (or drops agents to read-only) within minutes — the "agentic constitution" enforcement arm [CIO-AgenticConstitution-2026; rea]. Powerful for incident response; needs the central-policy channel from P1.3.
- **Self-governing framework repo.** Dogfood: install a (lightweight) version of the gate on `Gate` itself so its own PRs are governed by its own rules ([`08-KNOWN-ISSUES-AND-DEBT.md`](08-KNOWN-ISSUES-AND-DEBT.md) #17). The best demo is the tool trusting itself.

---

## Explicitly NOT worth doing (and why)

- **A native Windows/PowerShell port.** Huge surface, ongoing dual-maintenance, and WSL2 already works (`README.md:11-13`). The bash/POSIX floor is a *feature* (portable, auditable). Recommend documenting WSL2 well and closing the door on native Windows.
- **Reimplementing Claude Code's native sandboxing/permissions in bash.** The platform now does OS-level sandboxing and server-managed permission enforcement far better than a hook can [CC-Sandboxing; CC-ServerManaged]. Building a home-grown equivalent would be inferior and a maintenance sink. *Consume* it; don't rebuild it.
- **Putting an LLM in the enforcement loop.** It would break the determinism/zero-network/auditability guarantees that are the entire value proposition (D2 in [`07-DESIGN-DECISIONS.md`](07-DESIGN-DECISIONS.md)). Keep LLMs on the *informing* side (graph), never the *gating* side.
- **Competing with gstack/ECC on workflow depth or skill breadth.** They have ~90K/~224K stars and a head start on personas/skills [gstack-Augment-2026; ECC-GitHub-2026]. That's a different product. Integrate alongside them (they set up the workflow; you set up the un-bypassable floor), don't chase them.
- **A hand-rolled central telemetry/SIEM backend.** Claude Code's HTTP hooks already stream events to any endpoint [CC-Hooks]; emit into that rather than building a bespoke pipeline.

---

## Suggested 30 / 60 / 90-day sequence

**Days 1–30 — earn trust, stop the bleeding.** Ship P0.1 (`verify-governed`), P0.2 (doc/branch/CODEOWNERS reconciliation), P0.3 (CI secret scanner). Decide P1.3's fate for the S3 path (wire or delete). Land the self-gate moonshot in its cheapest form (CODEOWNERS + branch protection on `templates/`). Confirm the integration branch with the team. Outcome: a new owner can prove any repo is *actually* governed, and the obvious credibility gaps are closed.

**Days 31–60 — harden the moat.** Ship P1.1 (signed/attested integrity manifest — the biggest disclosed hole) and P1.4 (hash-chained, signed, control-mapped audit evidence + export). Start P1.5 (hash-pin + sandbox the MCP server). Outcome: the "agent can't weaken its own gate" claim becomes true against a PR-level attacker, and the audit story meets the 2026 bar.

**Days 61–90 — expand reach.** Ship P1.2 (Cursor/Codex adapters over the same git+CI gate) and finish P1.5. Begin P2.1 (Node/Go lint/type) and P2.2 (graph-backed cross-file layer boundary). Outcome: genuinely agent-agnostic, multi-language, and positioned as the deterministic backstop under any harness — the repositioning in "State of the world."

---

## Sources

All accessed July 2026. Distinguish confirmed platform facts (Claude Code docs) from third-party analysis.

- **[CC-Hooks]** Claude Code — *Hooks reference*, code.claude.com/docs/en/hooks (living doc; `allowManagedHooksOnly`, HTTP hooks, `exit 2`).
- **[CC-Permissions]** Claude Code — *Configure permissions*, code.claude.com/docs/en/permissions (deny-first precedence, `allowManagedPermissionRulesOnly`, `disableBypassPermissionsMode`).
- **[CC-ServerManaged]** Claude Code — *Configure server-managed settings*, code.claude.com/docs/en/server-managed-settings (Teams/Enterprise; CC ≥ 2.1.x).
- **[CC-Sandboxing]** Claude Code — *Configure the sandboxed Bash tool*, code.claude.com/docs/en/sandboxing (bubblewrap/Seatbelt; `failIfUnavailable`; no TLS inspection).
- **[CC-SandboxEnv]** Claude Code — *Choose a sandbox environment*, code.claude.com/docs/en/sandbox-environments (`@anthropic-ai/sandbox-runtime`; Claude Code on the web).
- **[TrueFoundry-2026]** TrueFoundry — *Claude Code Sandboxing…* (native sandboxing Oct 2025; Docker microVM Sandboxes Jan 2026; ~84% fewer prompts).
- **[CSA-MCP-RCE-2026]** Cloud Security Alliance — *MCP Design-Level RCE: Protocol Architecture as Attack Surface*, 2026-04-25 (OX Security STDIO RCE; ~150M downloads; ~7,000 exposed servers).
- **[CSA-MCP-Crisis-2026]** Cloud Security Alliance — *MCP Security Crisis: Systemic Design Flaws*, 2026-05-04 (~200k vulnerable instances; cross-server tool shadowing).
- **[MCP-ThreatModel-2026]** arXiv 2603.22489 — *MCP Threat Modeling / Tool Poisoning* (tool poisoning = #1 OWASP LLM; DREAD critical).
- **[IETF-MCP-2026]** IETF draft-mohiuddin-mcp-security-considerations-00 (treat all tool params/responses as untrusted; egress controls).
- **[OWASP-MCP]** OWASP www-community — *MCP Tool Poisoning* (connect-time vs runtime trust gap).
- **[Cloudsmith-2026]** Cloudsmith — *The 2026 Guide to Software Supply Chain Security: from static SBOMs to agentic governance*.
- **[CallSphere-2026]** CallSphere — *SBOM + SLSA Provenance for AI Builds (CycloneDX + ML-BOM), 2026*.
- **[TechBytes-SLSA-2026]** TechBytes — *Automated Supply Chain Security: SLSA Level 4 in 2026* (non-falsifiable provenance; two-party review of CI config).
- **[gstack-Augment-2026]** Augment Code — *Garry Tan's gstack hits ~89.7K stars* + github.com/garrytan/gstack (role-based skills; git-hook team-mode sync).
- **[ECC-GitHub-2026]** github.com/affaan-m/ECC — *Everything Claude Code* (~224K stars; 38 agents/156 skills/72 commands; multi-harness).
- **[rea]** github.com/bookedsolidtech/rea — *Zero-trust governance layer for Claude Code* (MCP gateway, HALT kill-switch, hash-chained audit log, prompt-injection defense, fail-closed).
- **[RipStop]** github.com/jonverrier/RipStop — *policy checks at git boundaries* (path-guard, history-guard, reflog-witness; Cursor/Claude/Codex/Amazon Q/human).
- **[sworn]** github.com/cjchanh/sworn — *deterministic, fail-closed AI code governance* (tamper-evident logs; CMMC).
- **[Endor-2026]** Endor Labs — *Introducing Agent Governance: Using Hooks…* (model layer can't be the control; deterministic + centralized audit).
- **[RanTheBuilder-2026]** RanTheBuilder / bitbytebit — *Agentic Coding Hooks: Deterministic AI Guardrails* (Cursor 1.7 / Codex / Gemini / Copilot hook parity; April 2026 PyPI SessionStart-hook worm; Stop-hook ratchet).
- **[Omnithium-2026]** Omnithium — *AI Agent Compliance: SOC2, ISO 42001, EU AI Act* (unified evidence; policy-as-code; continuous controls monitoring).
- **[DevTo-AuditTrail-2026]** dev.to (Ganapolsky) — *Your compliance team will ask for an AI agent audit trail…* (EU AI Act Art. 12; runtime governance, not observer).
- **[Diagrid-2026]** Diagrid — *AI Agent Identity: The Missing Layer* (SPIFFE/mTLS identity; signed chain of custody; deny-by-default).
- **[CloudMatos-2026]** CloudMatos — *SOC 2 for Multi-Agent AI Systems* (Aegis/OPA; signed decision artifacts; automated evidence bundles).
- **[CIO-AgenticConstitution-2026]** CIO.com — *Why your 2026 IT strategy needs an agentic constitution* (policy-as-code; machine-readable constitution; dual-key approvals).

---

next: [`10-COMPETITIVE-LANDSCAPE.md`](10-COMPETITIVE-LANDSCAPE.md)
