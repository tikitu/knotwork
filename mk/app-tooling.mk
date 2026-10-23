# app-tooling.mk — make targets for the conventions this project takes from
# app-tooling (https://github.com/tikitu/app-tooling), through peru.
#
# Imported by peru from the pattern `pattern-imports`. Never edit it here:
# `peru sync` refuses to overwrite a changed copy, and the change belongs in
# app-tooling. docs/app-tooling/pattern-imports/README.md says how this works.
#
# From the project's Makefile:   include mk/app-tooling.mk

# Leave the including Makefile's default goal alone, wherever the include is.
_app_tooling_default_goal := $(.DEFAULT_GOAL)

# Pinned, like every other dependency; uvx fetches it on first use.
PERU ?= uvx peru@1.3.5
APP_TOOLING_URL := https://github.com/tikitu/app-tooling

# APP_TOOLING_LOCAL=<checkout> makes peru read app-tooling from a local
# checkout instead of GitHub, for commits not pushed yet; peru.yaml still
# names GitHub, so push them before anyone else syncs.
_app_tooling_peru = $(if $(APP_TOOLING_LOCAL),GIT_CONFIG_COUNT=1 \
  GIT_CONFIG_KEY_0="url.$$(cd $(APP_TOOLING_LOCAL) && pwd).insteadOf" \
  GIT_CONFIG_VALUE_0="$(APP_TOOLING_URL)") $(PERU)

# The tree must be clean, except that peru.yaml may differ from HEAD in its
# `reup:` line and nothing else: that edit is how a project moves to a new
# release, and it changes no import, since a sync reads only `rev:`. Any other
# change to peru.yaml (a pattern added, a rule changed) is a commit of its own.
_app_tooling_dirty = git status --porcelain -- . ':(exclude)peru.yaml'
_app_tooling_peru_yaml_other = git diff -U0 HEAD -- peru.yaml \
  | grep -E '^[-+]' | grep -vE '^(\+\+\+|---) ' | grep -vE '^[-+][[:space:]]*reup:'

.PHONY: app-tooling-check app-tooling-update app-tooling-tools app-tooling-verify

app-tooling-tools:
	@command -v uvx >/dev/null 2>&1 || { echo "✗ uv not installed (brew install uv)"; exit 1; }

# Fails, naming them, if any imported file differs from what peru.yaml's rev
# has: edited or deleted in this project, or left over from an update that
# was not finished. It syncs the pinned files over the tree and reads the
# diff, so it needs a clean tree (but for a changed `reup:`, above); it puts
# the tree back either way.
app-tooling-verify: app-tooling-tools
	@[ -z "$$($(_app_tooling_dirty))" ] || { echo "✗ commit or stash first: the check reads the diff a sync leaves"; exit 1; }
	@[ -z "$$($(_app_tooling_peru_yaml_other))" ] || { echo "✗ peru.yaml has changes other than to reup:; commit them first"; exit 1; }
	@$(_app_tooling_peru) sync --force --no-overrides --quiet
	@changed="$$($(_app_tooling_dirty))"; \
	if [ -n "$$changed" ]; then \
	  git checkout -q -- . ':(exclude)peru.yaml' && git clean -q -fd -- .; \
	  echo "✗ these imported files differ from what peru.yaml's rev has:"; \
	  echo "$$changed" | sed 's/^.. /    /'; \
	  echo "  They were changed in this project, which imported files never are."; \
	  echo "  docs/app-tooling/pattern-imports/README.md, \"Local changes to imported"; \
	  echo "  files\", says what to do instead. Nothing was changed."; \
	  exit 1; \
	fi

app-tooling-check: app-tooling-verify
	@echo "✓ app-tooling imports match peru.yaml"

# Move to the newest commit of peru.yaml's `reup:` tag or branch, import it,
# and show what to do: the CHANGELOG entries the update added. Refuses if any
# imported file has been changed here (app-tooling-verify): an update would
# overwrite the change, and there is deliberately no merge. Needs a clean
# tree, so the update is a diff of its own; changing `reup:` first, to move
# to another release, is allowed.
app-tooling-update: app-tooling-verify
	@$(_app_tooling_peru) reup --no-overrides
	@git status --short -- .
	@echo "→ the catch-up steps: CHANGELOG entries this update added"
	@git --no-pager diff -- 'docs/app-tooling/*/CHANGELOG.md'

.DEFAULT_GOAL := $(_app_tooling_default_goal)
