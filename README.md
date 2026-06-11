# ai-dev-workflow

**The master corporate home for all automated AI developer workflows.**

This repository is the single source of truth for deploying enterprise-grade AI development
governance across engineering teams. It currently covers **Claude Code** and is structured
to accommodate future tool integrations (Cursor, Copilot, and others) as they mature.

## Active Branch

`develop` is the active integration branch. All releases are cut from `develop` and all
feature contributions target `develop`. Never work directly on `main`.

## Where to Start

Everything you need is inside the [`v1_release/`](v1_release/) folder.

Start there. The README inside will route you to the correct deployment basket for your team.

## Repository Structure

```
ai-dev-workflow/
└── v1_release/                  ← V1 production release of the governance framework
    ├── basket-1-brownfield/     ← For teams with existing, active codebases
    └── basket-2-greenfield/     ← For teams starting brand-new projects
```

## Tooling Coverage

| Tool | Status |
|---|---|
| Claude Code | V1 — Available now |
| Cursor | Planned — future release |
| GitHub Copilot | Planned — future release |
