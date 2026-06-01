#!/usr/bin/env bash
# Update host flake.lock files to github input revisions that are at least
# DELAY_DAYS old, giving updates a baking period before they reach the hosts.
# Writes only the lock files; it does not build or switch. Intended for CI,
# but runnable locally (needs nix, jq, curl).
#
# When PR_BODY_FILE is set, a markdown summary of every input change (old/new
# revision, commit dates, links to GitHub) is written there for use as a pull
# request body.
#
# Usage: update-stable-locks.sh <flake-dir> [<flake-dir> ...]
set -euo pipefail

DELAY_DAYS="${DELAY_DAYS:-7}"
PR_BODY_FILE="${PR_BODY_FILE:-}"

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

summary() {
  [[ -n "$PR_BODY_FILE" ]] && printf '%s\n' "$1" >>"$PR_BODY_FILE"
}

if [[ -n "$PR_BODY_FILE" ]]; then
  : >"$PR_BODY_FILE"
  summary "Automated update of every github flake input in the host lock files"
  summary "to revisions at least **$DELAY_DAYS days** old (before \`$THRESHOLD_DATE\`)."
  summary ""
  summary "Merging lands the pins on \`main\`; the hosts converge on their next"
  summary "\`sysconf-auto-pull\`."
fi

# Newest commit on $branch of $owner_repo that predates the threshold.
stable_sha() {
  local owner_repo="$1" branch="$2"
  gh_curl "https://api.github.com/repos/$owner_repo/commits?sha=$branch&until=$THRESHOLD_DATE&per_page=1" \
    | jq -r '.[0].sha // empty'
}

# Committer date (YYYY-MM-DD) of a revision, or empty on failure.
commit_date() {
  local owner_repo="$1" sha="$2"
  [[ -z "$sha" ]] && return 0
  gh_curl "https://api.github.com/repos/$owner_repo/commits/$sha" \
    | jq -r '.commit.committer.date // empty' | cut -c1-10
}

# Currently locked revision of a root input from the lock file.
current_sha() {
  local flake_dir="$1" name="$2"
  jq -r --arg n "$name" '.nodes[$n].locked.rev // empty' "$flake_dir/flake.lock"
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
  local rows=()
  local line name owner_repo branch new_sha old_sha new_date old_date
  for line in "${lines[@]}"; do
    IFS=$'\t' read -r name owner_repo branch <<<"$line"
    if ! new_sha=$(stable_sha "$owner_repo" "$branch"); then
      echo "  $name: GitHub API fetch failed, skipping"
      continue
    fi
    if [[ -z "$new_sha" ]]; then
      echo "  $name: no revision before threshold, skipping"
      continue
    fi
    old_sha=$(current_sha "$flake_dir" "$name")
    if [[ "$old_sha" == "$new_sha" ]]; then
      echo "  $name ($owner_repo@$branch) already at ${new_sha:0:7}"
      continue
    fi
    new_date=$(commit_date "$owner_repo" "$new_sha")
    old_date=$(commit_date "$owner_repo" "$old_sha")
    echo "  $name ($owner_repo@$branch) ${old_sha:0:7} (${old_date:-unknown}) -> ${new_sha:0:7} (${new_date:-unknown})"
    override_args+=(--override-input "$name" "github:$owner_repo/$new_sha")

    # Markdown row. The change cell links to a GitHub compare view (old..new),
    # or to the bare commit when there is no prior revision to compare against.
    local repo_url="https://github.com/$owner_repo"
    local change
    if [[ -n "$old_sha" ]]; then
      change="[\`${old_sha:0:7}\` → \`${new_sha:0:7}\`]($repo_url/compare/$old_sha...$new_sha)"
    else
      change="(unlocked) → [\`${new_sha:0:7}\`]($repo_url/commit/$new_sha)"
    fi
    rows+=("| [$name]($repo_url) | $change | ${old_date:-unknown} | ${new_date:-unknown} |")
  done

  if [[ ${#override_args[@]} -eq 0 ]]; then
    echo "  nothing to update"
    summary ""
    summary "### \`$flake_dir\`"
    summary ""
    summary "No changes (already at the newest stable revisions)."
    return
  fi

  summary ""
  summary "### \`$flake_dir\`"
  summary ""
  summary "| Input | Change | Old date | New date |"
  summary "| ----- | ------ | -------- | -------- |"
  local row
  for row in "${rows[@]}"; do
    summary "$row"
  done

  (cd "$flake_dir" && nix flake update "${override_args[@]}")
}

if [[ $# -eq 0 ]]; then
  echo "usage: $0 <flake-dir> [<flake-dir> ...]" >&2
  exit 1
fi

for dir in "$@"; do
  update_flake "$dir"
done
