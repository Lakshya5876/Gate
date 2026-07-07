<div align="center">
  <h1>Gate 🛡️</h1>
  <p><strong>The deterministic, agent-agnostic, un-bypassable governance framework for AI-driven development.</strong></p>

  [![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
  [![Platform: macOS | Linux | WSL2](https://img.shields.io/badge/Platform-macOS%20%7C%20Linux%20%7C%20WSL2-lightgrey)]()
  [![Coverage: Claude Code | Cursor](https://img.shields.io/badge/Coverage-Claude%20%7C%20Cursor-green)]()
  [![Build Status](https://img.shields.io/badge/build-passing-brightgreen)]()

</div>

---

## 📖 Overview

Gate is a **stack-agnostic governance framework** that brings engineering discipline and safety to autonomous AI coding agents at scale. Instead of relying purely on prompts—which agents can ignore, bypass, or hallucinate around—Gate enforces deterministic architecture, security, testing, and deployment rules at the **git and CI layer**.

Whether you're starting a greenfield project or integrating AI into a mature brownfield codebase, Gate ensures that no automated changes violate your critical constraints.

### 🌟 Key Features
- **Un-bypassable Governance**: Rules are enforced via Git hooks and CI, meaning humans and AI agents are held to the exact same rigorous standards.
- **Agent-Agnostic Core**: Designed to secure any AI tool (Claude Code, Cursor, Copilot) without deep platform lock-in.
- **Deterministic Checkpoints**: Catch stray layer boundaries, secret leakage, or missing tests *before* the commit leaves the machine.
- **Graceful Adoption**: Distinct deployment strategies (Baskets) tailor the framework's strictness to brand-new repos vs. legacy codebases.

---

## 🚀 Quick Start & Installation

This framework operates primarily via POSIX-compliant shell scripts (`bash`). 
> **Note**: Windows users must run Gate inside **WSL2** (Ubuntu or similar).

### Prerequisites
- `git`
- `bash` (3.2+)
- `python3` (Standard library only; no `pip` dependencies required)
- *Optional:* Claude Code CLI

### Deployment

Everything you need to deploy Gate is inside the [`v1_release/`](v1_release/) folder. We offer two core deployment strategies depending on your codebase:

1. **[Basket 1: Brownfield](v1_release/basket-1-brownfield/)** — For existing, active codebases. Introduces a "baseline ratchet" that prevents regressions without breaking on legacy technical debt.
2. **[Basket 2: Greenfield](v1_release/basket-2-greenfield/)** — For brand-new projects. Enforces strict layer boundaries, immutable trust roots, and maximum security from day one.

Choose your basket and follow the specific `install.sh` workflow documented within.

---

## 🧪 Testing & CI Integration

Gate emphasizes high velocity without sacrificing safety. Tests are **opt-in at commit** but **mechanically forced** before pushing.

| Action | Execution Requirement |
|---|---|
| `git commit` | **Opt-in** — Add `--run-tests=true` to your commit message |
| `git commit` (Core paths) | **Forced** — Touching CORE_FILES triggers mandatory full suite |
| `git push` | **Forced** — Requires a verified local test receipt or blocks the push |
| **CI Workflow** | **Authoritative** — The final backstop (`.github/workflows/gate.yml`) |

---

## 🤝 Handoff & Architecture

For a deep dive into the inner workings, design philosophy, and competitive landscape of Gate, refer to the exhaustive [Engineer Handoff Package](handoff/README.md). It contains everything you need to maintain, extend, and defend the framework.

---
<div align="center">
  <sub>Built with precision to scale AI engineering safely.</sub>
</div>
