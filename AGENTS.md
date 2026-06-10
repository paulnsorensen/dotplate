# dotplate — unpersonalized dotfiles template

This is an **unpersonalized dotfiles template repository**. It ships with
machinery but no personal configuration. Your task as the onboarding agent
is to interview the user socratically and build their personalized setup.

## Start here

Before doing anything else, read `onboard/state.yaml` to check whether
onboarding is already in progress. If any passes are `done`, resume from
the first `pending` pass rather than starting over.

```bash
bash onboard/lib/state.sh next onboard/state.yaml
```

Then open `onboard/GUIDE.md` and follow the pass it tells you to run next
(or Pass 0 if everything is `pending`).

## Key files

- `onboard/GUIDE.md` — the complete socratic onboarding script (eight passes)
- `onboard/state.yaml` — resumable progress: per-pass status and recorded answers
- `onboard/catalog/` — offerable items for each concern (mcp, hooks, skills, plugins, packages, zsh, mac-extras)
- `onboard/lib/state.sh` — tiny helper for reading/resuming state
- `bin/dots` — dotfiles management command (`dots sync`, `dots doctor`, `dots test`)

## What this repo is NOT yet

- It is not a personalized dotfiles repo.
- It does not yet have a name, email, preferred editor, or shell modules configured.
- The agent registries are empty by design; onboarding populates them.

When graduation (Pass 7) completes, you will rewrite this file into a
normal project-instructions file for the now-personalized repo.
