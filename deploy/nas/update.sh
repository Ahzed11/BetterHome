#!/usr/bin/env bash
# Updates the BetterHome stack on the server (T-0113): backs up, moves the images to a tag, pulls, and restarts.
# The migrations run first (the services wait for them) and are forward-only, so the backup comes before.
# Usage, from the folder of compose.yml: ./update.sh [tag]   (a commit SHA tag; without it the tags stay as they are)
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"
compose=(docker compose -f compose.yml)
tag="${1:-}"

if [[ -n "$tag" ]]; then
  [[ "$tag" =~ ^[A-Za-z0-9_.-]+$ ]] || { echo "update: '$tag' is not a valid image tag" >&2; exit 1; }
  cp compose.yml "compose.yml.before-update"
  sed -i -E "s#(image: ghcr\.io/ahzed11/betterhome-[a-z-]+):[A-Za-z0-9_.-]+#\1:${tag}#" compose.yml
  echo "update: images moved to :$tag (previous file kept as compose.yml.before-update)"
fi

# A fresh dump of every database before a migration can change it.
"${compose[@]}" up -d postgres backup
"${compose[@]}" exec -T backup /backup.sh
echo "update: backup done"

"${compose[@]}" pull
"${compose[@]}" up -d
"${compose[@]}" ps
