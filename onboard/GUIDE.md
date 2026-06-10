# Onboarding Guide

You are the onboarding agent for a fresh clone of this dotfiles template.
Your reader is you — the agent — not the human directly. Read this guide,
ask the human the questions it specifies, and execute the steps.

**Resume protocol:** Before starting any pass, read `onboard/state.yaml`
(or run `bash onboard/lib/state.sh next onboard/state.yaml`) to find the
first pending pass. Skip passes whose status is `done`.

**Per-pass discipline:** Every pass ends with:

1. Materialize — write the chosen config into the relevant files
2. `dots sync` — apply everything to the machine
3. Verify — confirm the change is actually live before moving on

Never advance to the next pass without completing all three steps.

After completing a pass, update `onboard/state.yaml`:

- Set `.passes[N].status` to `"done"`
- Record key answers under `.passes[N].answers`

---

## Pass 0 — Prerequisites

**Goal:** Ensure the machine has every tool onboarding depends on. A silent
missing dependency will cause `dots sync` to partially succeed and leave the
user confused.

### Detect OS

Ask the human (or detect via `uname -s`):

- Are you on macOS or Linux?

Record in `onboard/state.yaml` as `.detected_os` (`macos` or `linux`).

### Install package manager

**macOS:** Check for Homebrew. If missing:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

**Linux (Debian/Ubuntu):** apt is the package manager. Confirm with:

```bash
apt-get --version
```

If not available, the user is on an unsupported Linux distribution — tell them
and stop this pass.

### Install git

```bash
# macOS
brew install git
# Linux
sudo apt-get install -y git
```

### Install uv (REQUIRED — do not skip)

`uv` is required by `agent-profile` (`ap`). The chezmoi base-profile hook
**silently skips** when `uv` is absent — no error, just no agent config
installed. This is the most common source of a "sync succeeded but nothing
happened" report.

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
# Restart shell or: source $HOME/.local/bin/env
```

Verify: `uv --version`

### Install agent CLI

Ask which agent harnesses the user wants (Claude Code, Codex, opencode, Cursor).
Install whichever are missing:

```bash
# Claude Code (macOS — prefer the cask for updates)
brew install --cask claude-code
# Claude Code (Linux)
curl -fsSL https://claude.ai/install.sh | sh
# Codex
npm install -g @openai/codex
# opencode (macOS via tap; Linux: check opencode.ai/docs)
brew install anomalyco/tap/opencode
```

### On Linux: run the full bootstrap

`bin/linux-install` installs everything that isn’t reachable through `apt`
in one shot (rustup, cargo CLIs, bun, duckdb, npm globals). It is idempotent.

```bash
bash bin/linux-install
```

The `packages/sync.sh` apt path is advisory-only for individual packages;
`bin/linux-install` is the real bootstrap.

### Materialize → `dots sync` → verify

```bash
# Bootstrap the package manager first, then:
dots sync
# Verify:
chezmoi --source chezmoi doctor
```

Record `.detected_os` and `.passes[0].status = "done"` in `onboard/state.yaml`.

---

## Pass 1 — Orientation

**Goal:** Understand the user’s context so you can calibrate question depth
for ALL later passes. A power user who has managed dotfiles before needs
less explanation; a newcomer needs more scaffolding.

### Questions to ask

1. **OS confirmed?** (should match what you detected in Pass 0 — just confirm)
2. **Terminal comfort level:** beginner / intermediate / advanced
   - Beginner: explain each tool briefly when offering it
   - Advanced: pitch only, no explanation needed
3. **Primary goals:** (check all that apply)
   - Faster shell / better CLI tools
   - Agent / AI coding assistant setup
   - Consistent config across machines
   - Other (ask)
4. **How many machines** will run this config?

Record answers under `.passes[1].answers`:

- `comfort`: beginner|intermediate|advanced
- `goals`: list
- `machines`: number or description

### Calibration

Based on the answers above, adjust for all later passes:

- **Beginner:** offer more context when explaining packages and MCPs;
  default to simpler choices (fewer packages, basic shell modules).
- **Advanced:** lead with capabilities, let them opt in/out fast.

### Materialize → `dots sync` → verify

Nothing to materialize in this pass. Run `dots sync` to confirm the
base state is clean before moving on.

```bash
dots sync
dots doctor
```

Record `.passes[1].status = "done"` in `onboard/state.yaml`.

---

## Pass 2 — Identity & git

**Goal:** Personalize git and chezmoi with the user's name, email, and
preferred editor. These are written into chezmoi templates so `dots sync`
materializes `~/.gitconfig` with `user.name`, `user.email`, and `core.editor`.

### Questions to ask

1. **Full name** (for git commits)
2. **Email address** (for git commits)
3. **Preferred editor** (vim / neovim / nano / code / other)

### Materialize

Write the answers into `chezmoi/.chezmoi.toml.tmpl` data section. The
template already has prompts — you are pre-answering them so `chezmoi apply`
doesn’t prompt interactively during `dots sync`:

```toml
# chezmoi/.chezmoi.toml.tmpl
[data]
  name  = "<full name>"
  email = "<email>"
  editor = "<editor>"
```

### `dots sync` → verify

```bash
dots sync
# Verify:
git config user.name    # should return the name you entered
git config user.email   # should return the email you entered
git config core.editor  # should return the chosen editor
```

Record `.passes[2].answers` with `name`, `email`, `editor`.
Record `.passes[2].status = "done"`.

> **Note on `localLLM`:** `chezmoi/.chezmoi.toml.tmpl` also prompts
> `localLLM` (bool, default false). This controls whether the local LLM
> stack (litellm, worker services) is deployed. Skip it in Pass 2 — it is
> addressed in Pass 6 when the user opts into agent MCPs.

---

## Pass 3 — Shell

**Goal:** Walk the user through available zsh modules. Each module is an
opt-in. Present the pitch from `onboard/catalog/zsh.yaml` for each item
and let the user decide.

### How to walk the catalog

Read `onboard/catalog/zsh.yaml`. For each entry:

1. Present the `pitch` (and explain more if `comfort == beginner`).
2. Ask: “Would you like to include this?”
3. On acceptance, add the module to the zsh loader (`zshrc` or the relevant
   include mechanism).

### vi-mode is an explicit opt-in

vi-mode changes the default key bindings and surprises newcomers. You MUST
ask the user explicitly: “Would you like vi-mode key bindings in your shell
(vim-style navigation in the command line)?” Do NOT enable it silently.

If the user asks “what is vi-mode?”: explain that it lets you navigate
and edit commands with vim motions (press Escape to enter normal mode,
i/a to enter insert mode). Recommend it only to vim users.

### OS filtering

Skip any catalog entry where `os: macos` when `detected_os == linux`, and
vice versa.

### Materialize → `dots sync` → verify

```bash
dots sync
# Verify: open a new shell and confirm modules load without errors
zsh -i -c 'echo shell ok'
```

Record accepted modules in `.passes[3].answers.modules`.
Record `.passes[3].status = "done"`.

---

## Pass 4 — Packages

**Goal:** Walk the user through additional packages from
`onboard/catalog/packages.yaml`. Filter by OS. Present each pitch.
On macOS, also walk `onboard/catalog/mac-extras.yaml` for macOS-specific
configuration items.

### How to walk the catalog

Read `onboard/catalog/packages.yaml`. For each entry:

1. Present the name and `pitch`.
2. If `os` is set and does not match `detected_os`, skip silently.
3. Ask: "Would you like to install this?"
4. On acceptance, add the entry to `packages/packages.yaml`.

### macOS extras (gated on detected_os == macos)

If `detected_os == macos`, also walk `onboard/catalog/mac-extras.yaml`.
For each entry:

1. Present the name and `pitch` (and explain more if `comfort == beginner`).
2. Ask: "Would you like to apply this?"
3. On acceptance, follow the `entry` block instructions to deploy the asset
   to the appropriate location (LaunchAgent, `~/.config/...`, etc.).

All `mac-extras` items have `os: macos` — skip silently on Linux.

### Materialize → `dots sync` → verify

```bash
dots sync
# Spot-check a few accepted binaries:
which <binary>   # for each accepted package
```

Record accepted packages in `.passes[4].answers.packages`.
Record accepted mac-extras in `.passes[4].answers.mac_extras` (macOS only).
Record `.passes[4].status = "done"`.

---

## Pass 5 — Secrets strategy

**Goal:** Decide how secrets (API keys) are managed. This choice GATES
which secret-requiring items are offerable in Pass 6.

### Present the options

Ask the user to choose one:

1. **1Password** — store secrets in 1Password; agent reads them via the
   1Password CLI (`op`) at runtime. Secrets never touch the filesystem
   in plain text. Best for users who already use 1Password.

2. **Plain `.env` file** — store secrets in `.env` at the repo root.
   The file is gitignored and never committed. Simpler to set up but
   secrets live on disk in plain text. Suitable for most users.

3. **Skip for now** — don’t configure secrets. Secret-requiring items
   (context7, tavily, todoist MCPs) will be skipped in Pass 6.
   You can add them later by re-running Pass 5.

**Important:** Never echo secret values into chat. Never write actual
API key values into any tracked file.

### Materialize

For **1Password**: record the choice; note which items in Pass 6 require
`op read` wiring.

For **plain `.env` file**:

- Confirm `.env` is in `.gitignore` (it already is)
- Show the user `.env.example` as a template
- Ask them to fill in their keys (outside this chat session — do not
  ask them to paste keys into the conversation)

Record `.secrets_strategy` in `onboard/state.yaml` as `onepassword`,
`envfile`, or `skip`.

### `dots sync` → verify

```bash
dots sync
# Verify (envfile path):
[[ -f .env ]] && echo ".env present (not committed)"
git status .env   # must NOT appear as tracked
```

Record `.passes[5].answers.strategy` and `.passes[5].status = "done"`.

---

## Pass 6 — Agent config

**Goal:** Walk the user through available MCPs, hooks, skills, and plugins.
Copy accepted items verbatim into the live registries.

### Secrets gate

Read `.secrets_strategy` from `onboard/state.yaml`.

- If `skip`: skip all items where `requires_secret` is set.
- If `onepassword` or `envfile`: offer all items.

### Walk each catalog

For each catalog file (mcp, hooks, skills, plugins), iterate entries:

1. Present the `pitch` (calibrate depth per Pass 1 comfort level).
2. If `os` is set and does not match `detected_os`, skip silently.
3. If `requires_secret` is set and `secrets_strategy == skip`, skip.
4. Ask: “Would you like to add this?”
5. On acceptance: copy the `entry` block VERBATIM into the corresponding
   registry file. Do not paraphrase or regenerate — copy it exactly.

   - MCP entries → `agents/mcp/registry.yaml` (under `mcps:`)
   - Hook entries → `agents/hooks/registry.yaml` (under `hooks:`)
   - Skill entries → `skills/_registry.yaml` (under `sources:`)
   - Plugin entries → `claude/plugins/registry.yaml` (under `plugins:`)

### Agent personality

Ask: “How would you like your agent to address you? (e.g., by first name,
a nickname, a title, or just leave it default)”

Write the answer into `agents/AGENTS.md` as the user’s personal agent
preferences file:

```markdown
# Agent preferences

Address me as: <their answer>
```

They can expand this file later with any other agent preferences.

### Materialize → `dots sync` → verify

```bash
dots sync
# Verify the global profile installs cleanly:
dots profile install global
# Or:
bash bin/dots profile install global
```

If it fails, check the registry YAML for syntax errors (the entry blocks
must be valid YAML at the proper indentation level).

Record accepted items in `.passes[6].answers` (by catalog name).
Record `.passes[6].status = "done"`.

---

## Pass 7 — Graduation

**Goal:** Confirm everything is working, personalize the remaining
onboarding scaffolding, and commit the user’s initial state.

### Health check

```bash
dots doctor
```

Fix any issues reported before proceeding.

### Full test suite

```bash
dots test
# Or:
bash tests/run-tests.sh
```

All tests must be green. If any fail, investigate and fix before continuing.

### Rewrite AGENTS.md

The current `AGENTS.md` is the onboarding interviewer. Now that onboarding
is complete, rewrite it into a normal lean project-instructions file for
the user’s personalized repo. It should:

- Describe what the repo is (their personalized dotfiles)
- Note any conventions they want their agent to follow
- Remove all references to onboarding, GUIDE.md, and state.yaml

Do NOT include cheese flair, personal identifiers, or personal addresses
in this file — it is a project-instructions file, not a personal one.
(The user can add preferences to `agents/AGENTS.md` which they own.)

### Archive onboarding

```bash
git mv onboard .onboard-archive
# Or, if the user prefers to delete it:
# rm -rf onboard
```

Ask the user which they prefer (archive or delete).

### Initial commit

```bash
git add -A
git commit -m "chore: personalized dotfiles setup via onboarding"
```

This is the user’s initial commit of their personalized state.

### Materialize → `dots sync` → verify

```bash
dots sync
dots doctor
```

Confirm everything is still working after the commit.

### Done

Onboarding is complete. The user now has a personalized dotfiles repo.
Remind them:

- `dots sync` applies changes from the repo to the machine
- `dots update` pulls and syncs
- `dots doctor` runs health checks
- `dots test` runs the test suite
- The agent is now configured via their normal project AGENTS.md

Record `.passes[7].status = "done"`.
