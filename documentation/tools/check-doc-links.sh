#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
fail=0
while IFS= read -r -d '' file; do
  while IFS= read -r link; do
    # strip optional title / anchors
    target="${link%%#*}"
    [[ -z "$target" || "$target" == http* || "$target" == mailto:* ]] && continue
    dir="$(dirname "$file")"
    if [[ ! -e "$dir/$target" && ! -e "$ROOT/$target" ]]; then
      echo "Broken link in $file -> $link"
      fail=1
    fi
  done < <(grep -oE '\[[^]]+\]\([^)]+\)' "$file" | sed -E 's/.*\(([^)]+)\)/\1/' || true)
done < <(find documentation AGENTS.md README.md -name '*.md' -print0 2>/dev/null)
if [[ "$fail" -ne 0 ]]; then
  exit 1
fi
echo "Documentation links OK"
