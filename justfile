# dotplate task runner

# list available recipes
default:
    @just --list

# run all linters
lint: lint-shell lint-markdown

# shellcheck on shell scripts
lint-shell:
    shellcheck -x -e SC1091 bin/* .sync
    shellcheck -x -e SC1091 -s bash agents/mcp/sync.sh agents/hooks/sync.sh agents/hooks/lib.sh claude/plugins/sync.sh claude/lib/sync-common.sh chezmoi/lib/install-base-profile.sh chezmoi/lib/install-agents-doc.sh chezmoi/lib/install-shared-assets.sh
    shellcheck -x -e SC1091 -s bash tests/run-tests.sh tests/install-bats.sh
    @echo "shellcheck: ok"

# markdownlint on markdown files
lint-markdown:
    markdownlint-cli2 '**/*.md'

# autofix where supported
lint-fix: lint-markdown-fix

# markdownlint --fix
lint-markdown-fix:
    markdownlint-cli2 --fix '**/*.md'

# run all tests
test *ARGS:
    ./tests/run-tests.sh {{ARGS}}

# pre-push gate: lint + unit tests
check: lint test
