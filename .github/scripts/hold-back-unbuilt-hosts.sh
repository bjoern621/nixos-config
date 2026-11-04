#!/usr/bin/env bash
# Restores the main flake.lock of every host on the checked-out lock update branch
# that has no marker file in <built-dir>, then pushes that commit.
# The pull request then lands the passing hosts alone.
# The next run offers a held-back host its update again.
#
# A host without a marker counts as failed, whatever stopped its build job.
#
# Writes has-changes=true to GITHUB_OUTPUT if a host keeps its update.
#
# Usage: hold-back-unbuilt-hosts.sh <built-dir>
set -euo pipefail

BRANCH="automated/flake-lock-update"

built_dir="$1"

mapfile -t changed_locks < <(git diff --name-only origin/main...HEAD -- 'hosts/*/flake.lock')

held_back=()
for lock in "${changed_locks[@]}"; do
  host=$(basename "$(dirname "$lock")")
  if [[ ! -e "$built_dir/$host" ]]; then
    echo "$host: no passing build, keeping the main lock"
    git checkout origin/main -- "$lock"
    held_back+=("$host")
  fi
done

if ((${#held_back[@]} == ${#changed_locks[@]})); then
  echo "No host keeps an update, leaving the pull request open"
  echo "has-changes=false" >>"$GITHUB_OUTPUT"
  exit 0
fi

if ((${#held_back[@]} > 0)); then
  git -c user.name="github-actions[bot]" \
    -c user.email="41898282+github-actions[bot]@users.noreply.github.com" \
    commit --quiet -m "chore: hold back flake.lock update of ${held_back[*]}"
  git push origin "HEAD:refs/heads/$BRANCH"
fi

echo "has-changes=true" >>"$GITHUB_OUTPUT"
