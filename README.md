# dotplate

An agent-driven dotfiles template. Clone it, open your agent, and let it
build your personalized setup through a socratic interview.

No shell wizard, no long manual. The agent asks what you want, explains
each choice, and materializes working config incrementally — you see real
results after every step.

## Getting started

**Three steps:**

1. **Install an agent CLI** — any harness that reads `AGENTS.md` works:
   [Claude Code](https://claude.ai/download), [Codex](https://github.com/openai/codex),
   [opencode](https://opencode.ai), or [Cursor](https://cursor.sh).

2. **Clone via GitHub “Use this template”** — click the button on the
   GitHub repo page to create your own copy, then clone it locally.

3. **Open your agent and say hi** — start a session in the repo root.
   Your agent will read `AGENTS.md`, detect the template state, and begin
   the onboarding interview.

That’s it. The agent handles the rest.

## What happens during onboarding

Onboarding runs eight passes, each ending with a `dots sync` so you see
working results before moving on:

| Pass | What it does |
|---|---|
| 0 — Prerequisites | Installs the package manager, git, `uv`, and your agent CLI |
| 1 — Orientation | Learns your comfort level and goals; calibrates all later passes |
| 2 — Identity & git | Sets your name, email, and editor in git and chezmoi |
| 3 — Shell | Walks available zsh modules; vi-mode is an explicit opt-in |
| 4 — Packages | Offers productivity CLI tools filtered to your OS |
| 5 — Secrets | Picks a secrets strategy (1Password, `.env`, or skip) |
| 6 — Agent config | Offers MCPs, hooks, skills, and plugins; copies entries verbatim |
| 7 — Graduation | Health check, full test suite, rewrites AGENTS.md, initial commit |

Onboarding is resumable — if you close the session mid-way, your agent
will pick up where it left off using `onboard/state.yaml`.

## Supported platforms

- **macOS** — full support; Homebrew is the package manager
- **Linux** (Debian/Ubuntu) — full support; `bin/linux-install` bootstraps
  everything that isn’t in `apt`

Windows and WSL are not supported.

## What’s inside

```
bin/dots             — main CLI (dots sync, dots doctor, dots test, dots profile …)
bin/linux-install    — one-shot Linux bootstrap (rustup, cargo CLIs, bun, duckdb …)
agent-profile/       — ap: harness-agnostic agent config renderer (vendored)
agents/              — hook scripts, MCP registry, sub-agent definitions
chezmoi/             — dotfiles source (gitconfig, shell settings, MCP wiring)
packages/            — package registry and sync script
profiles/            — agent install profiles (base, global, _permissions)
skills/              — skill source registry
claude/plugins/      — Claude Code plugin registry
tests/               — bats test suite (run with: dots test)
onboard/             — socratic onboarding flow (GUIDE, state, catalog)
```

## Requirements

Before running onboarding, you need:

- A terminal
- An internet connection
- macOS or Linux (Debian/Ubuntu)

The onboarding agent installs everything else.
