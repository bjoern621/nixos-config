#!/usr/bin/env bash
# Update host flake.lock files to github input revisions that are at least
# DELAY_DAYS old, giving updates a baking period before they reach the hosts.
# Writes only the lock files; it does not build or switch. Intended for CI,
# but runnable locally (needs nix, jq, curl).
#
# Usage: update-delayed-locks.sh <flake-dir> [<flake-dir> ...]
set -euo pipefail

DELAY_DAYS="${DELAY_DAYS:-7}"

# A GitHub token (CI provides GITHUB_TOKEN) raises the API rate limit.
gh_curl() {
  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    curl -fsSL -H "Authorization: Bearer $GITHUB_TOKEN" "$@"
  else
    curl -fsSL "$@"
  fi
}

THRESHOLD_DATE=$(date -u -d "$DELAY_DAYS days ago" +%Y-%m-%dT00:00:00Z)
echo "Pinning inputs to the newest revision before $THRESHOLD_DATE"

# Newest commit on $branch of $owner_repo that predates the threshold.
delayed_sha() {
  local owner_repo="$1" branch="$2"
  gh_curl "https://api.github.com/repos/$owner_repo/commits?sha=$branch&until=$THRESHOLD_DATE&per_page=1" \
    | jq -r '.[0].sha // empty'
}

update_flake() {
  local flake_dir="$1"
  if [[ ! -f "$flake_dir/flake.lock" ]]; then
    echo "skip $flake_dir (no flake.lock)"
    return
  fi
  echo "=== $flake_dir ==="

  # Direct github inputs of the root flake, as "name<TAB>owner/repo<TAB>ref".
  mapfile -t lines < <(jq -r '
    . as $r
    | $r.nodes.root.inputs
    | to_entries[]
    | . as $e
    | $r.nodes[.value].original
    | select(.type == "github")
    | "\($e.key)\t\(.owner)/\(.repo)\t\(.ref // "HEAD")"
  ' "$flake_dir/flake.lock")

  local override_args=()
  local line name owner_repo branch sha
  for line in "${lines[@]}"; do
    IFS=$'\t' read -r name owner_repo branch <<<"$line"
    if ! sha=$(delayed_sha "$owner_repo" "$branch"); then
      echo "  $name: GitHub API fetch failed, skipping"
      continue
    fi
    if [[ -z "$sha" ]]; then
      echo "  $name: no revision before threshold, skipping"
      continue
    fi
    echo "  $name ($owner_repo@$branch) -> ${sha:0:7}"
    override_args+=(--override-input "$name" "github:$owner_repo/$sha")
  done

  if [[ ${#override_args[@]} -eq 0 ]]; then
    echo "  nothing to update"
    return
  fi

  (cd "$flake_dir" && nix flake update "${override_args[@]}")
}

if [[ $# -eq 0 ]]; then
  echo "usage: $0 <flake-dir> [<flake-dir> ...]" >&2
  exit 1
fi

for dir in "$@"; do
  update_flake "$dir"
done
