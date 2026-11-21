#!/usr/bin/env bash
# Writes a shields.io endpoint JSON file to the "badges" branch through the GitHub API.
# Usage: put-badge.sh <file> <label> <message> <color> [logo]
# Needs an authenticated gh CLI (GH_TOKEN in CI). Skips the commit when nothing changed.
set -euo pipefail

repo="${BADGE_REPO:-filooww/django-app}"
branch="${BADGE_BRANCH:-badges}"
file="$1"

json="$(jq -nc --arg l "$2" --arg m "$3" --arg c "$4" --arg logo "${5:-}" \
  '{schemaVersion: 1, label: $l, message: $m, color: $c, style: "for-the-badge"}
   + (if $logo == "" then {} else {namedLogo: $logo, logoColor: "white"} end)')"

current="$(gh api "repos/$repo/contents/$file?ref=$branch" 2>/dev/null || echo '{}')"
sha="$(jq -r '.sha // empty' <<<"$current")"
old="$(jq -r '.content // empty' <<<"$current" | tr -d '\n' | base64 -d 2>/dev/null || true)"

if [ "$old" = "$json" ]; then
  echo "$file unchanged"
  exit 0
fi

args=(-X PUT "repos/$repo/contents/$file"
  -f message="badge: $file"
  -f branch="$branch"
  -f content="$(printf '%s' "$json" | base64 | tr -d '\n')")
[ -n "$sha" ] && args+=(-f sha="$sha")

gh api "${args[@]}" > /dev/null
echo "$file updated: $json"
