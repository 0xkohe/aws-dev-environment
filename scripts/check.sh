#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
files=(cloud-init/bootstrap.sh scripts/*.sh scripts/asobi shell/asobi.bash tests/*.sh tests/mock-bin/aws tests/mock-bin/tmux)
for file in "${files[@]}"; do bash -n "$file"; done
if command -v shellcheck >/dev/null; then
  shellcheck -S error "${files[@]}"
fi
bash tests/test-operations.sh
bash tests/test-shell-setup.sh
git diff --check
