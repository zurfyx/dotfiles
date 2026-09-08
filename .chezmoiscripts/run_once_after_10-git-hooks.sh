#!/bin/bash
# Point the SOURCE repo (not $HOME) at its own hooks. Identity is inherited
# from the global git config; this repo overrides nothing.
# CHEZMOI_SOURCE_DIR is exported by chezmoi to every script it runs, so no
# template needed here.
set -eu

command -v git >/dev/null 2>&1 || exit 0

git -C "$CHEZMOI_SOURCE_DIR" config core.hooksPath .githooks

# Fresh clones lose the execute bit depending on how they arrive; restore it.
if [ -f "$CHEZMOI_SOURCE_DIR/.githooks/pre-commit" ]; then
  chmod +x "$CHEZMOI_SOURCE_DIR/.githooks/pre-commit"
fi
