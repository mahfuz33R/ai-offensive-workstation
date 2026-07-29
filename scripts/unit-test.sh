#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

while IFS= read -r -d '' script; do
  bash -n "$script"
done < <(find scripts -type f -name '*.sh' -print0)

if command -v zsh >/dev/null 2>&1; then
  zsh -n .zshrc
else
  printf '[SKIP] zsh is not installed on this host; Python architecture tests still validate its image wiring.\n'
fi

if command -v ruby >/dev/null 2>&1; then
  ruby tests/test_compose_contract.rb
else
  printf '[SKIP] ruby is not installed on this host; Compose invariants still have Python text-level unit coverage.\n'
fi

python3 -c '
import ast
from pathlib import Path
for root in (Path("scripts"), Path("tests")):
    for path in root.rglob("*.py"):
        ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
'

python3 -m unittest discover -s tests -p 'test_*.py' -v
python3 scripts/verify-knowledge-base.py

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git diff --check
fi

printf 'Offline unit tests passed. No image was built and no container was started.\n'
