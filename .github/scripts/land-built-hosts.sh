#!/usr/bin/env bash
# Lands the checked-out lock update pull request host by host.
#
# With every changed host built, the pull request merges.
# With a failed host, the locks of the built hosts go straight to main.
# The pull request branch then holds the failed locks on top of main,
# and the title and body name those hosts and this run.
# The next run updates the same branch, which rewrites that title and body.
#
# A host without a marker file in <built-dir> counts as failed, whatever stopped its build job.
#
# Needs GH_TOKEN, GITHUB_REPOSITORY, PR_NUMBER and RUN_URL.
#
# Usage: land-built-hosts.sh <built-dir>
set -euo pipefail

BRANCH="automated/flake-lock-update"

built_dir="$1"

mapfile -t changed_locks < <(git diff --name-only origin/main...HEAD -- 'hosts/*/flake.lock')

built_hosts=()
built_locks=()
failed_hosts=()
failed_locks=()
for lock in "${changed_locks[@]}"; do
  host=$(basename "$(dirname "$lock")")
  if [[ -e "$built_dir/$host" ]]; then
    built_hosts+=("$host")
    built_locks+=("$lock")
  else
    failed_hosts+=("$host")
    failed_locks+=("$lock")
  fi
done

commit_as_bot() {
  git -c user.name="github-actions[bot]" \
    -c user.email="41898282+github-actions[bot]@users.noreply.github.com" \
    commit --quiet -m "$1"
}

split_update_onto_main() {
  local update_sha
  update_sha=$(git rev-parse HEAD)
  git checkout --quiet --detach origin/main

  if ((${#built_locks[@]} > 0)); then
    git checkout "$update_sha" -- "${built_locks[@]}"
    # A rerun of the job finds these locks on main already.
    if ! git diff --cached --quiet; then
      commit_as_bot "chore: stable flake.lock update of ${built_hosts[*]}"
      git push origin HEAD:refs/heads/main
    fi
  fi

  # GitHub lists a pull request against its merge base,
  # so the branch must start at this main to show the failed locks alone.
  git checkout "$update_sha" -- "${failed_locks[@]}"
  commit_as_bot "chore: stable flake.lock update of ${failed_hosts[*]}"
  git push --force origin "HEAD:refs/heads/$BRANCH"
}

# Reads a body that update-stable-locks.sh wrote and prints the sections of the failed hosts.
failed_host_sections() {
  awk -v hosts="${failed_hosts[*]}" '
    BEGIN {
      split(hosts, names, " ")
      for (i in names) wanted["### `hosts/" names[i] "`"]
    }
    /^### / { keep = ($0 in wanted) }
    keep
  '
}

mark_pull_request_broken() {
  local pull_request="repos/$GITHUB_REPOSITORY/pulls/$PR_NUMBER"
  local failed_list sections
  printf -v failed_list "\`%s\`, " "${failed_hosts[@]}"
  failed_list=${failed_list%, }
  sections=$(gh api "$pull_request" --jq .body | failed_host_sections)

  gh api --silent -X PATCH "$pull_request" \
    -f title="BROKEN: stable flake.lock update of ${failed_hosts[*]}" \
    -f body="**BROKEN.** Failed to build and kept the old pins: $failed_list.

Latest pipeline run: $RUN_URL

$sections"
}

if ((${#failed_hosts[@]} == 0)); then
  gh pr merge --merge -R "$GITHUB_REPOSITORY" "$PR_NUMBER"
  exit 0
fi

echo "Failed to build: ${failed_hosts[*]}"
split_update_onto_main
mark_pull_request_broken
