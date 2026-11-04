#!/usr/bin/env bash
# Lands the checked-out lock update pull request host by host.
#
# With every changed host built, the pull request merges.
# With a failed host, the locks of the built hosts go straight to main.
# The pull request then stays open with the failed hosts alone,
# and its title and body name them and this run.
# The next run updates the same branch, which rewrites that title and body.
#
# A host without a marker file in <built-dir> counts as failed, whatever stopped its build job.
#
# Needs GH_TOKEN, GITHUB_REPOSITORY, PR_NUMBER and RUN_URL.
#
# Usage: land-built-hosts.sh <built-dir>
set -euo pipefail

built_dir="$1"

mapfile -t changed_locks < <(git diff --name-only origin/main...HEAD -- 'hosts/*/flake.lock')

built_hosts=()
built_locks=()
failed_hosts=()
for lock in "${changed_locks[@]}"; do
  host=$(basename "$(dirname "$lock")")
  if [[ -e "$built_dir/$host" ]]; then
    built_hosts+=("$host")
    built_locks+=("$lock")
  else
    failed_hosts+=("$host")
  fi
done

commit_built_locks_to_main() {
  local update_sha
  update_sha=$(git rev-parse HEAD)
  git checkout --quiet --detach origin/main
  git checkout "$update_sha" -- "${built_locks[@]}"

  # A rerun of the job finds these locks on main already.
  if git diff --cached --quiet; then
    return
  fi

  git -c user.name="github-actions[bot]" \
    -c user.email="41898282+github-actions[bot]@users.noreply.github.com" \
    commit --quiet -m "chore: stable flake.lock update of ${built_hosts[*]}"
  git push origin HEAD:refs/heads/main
}

mark_pull_request_broken() {
  local pull_request="repos/$GITHUB_REPOSITORY/pulls/$PR_NUMBER"
  local failed_list body
  printf -v failed_list "\`%s\`, " "${failed_hosts[@]}"
  failed_list=${failed_list%, }
  body=$(gh api "$pull_request" --jq .body)

  gh api --silent -X PATCH "$pull_request" \
    -f title="BROKEN: stable flake.lock update of ${failed_hosts[*]}" \
    -f body="**BROKEN.** Failed to build and kept the old pins: $failed_list. Every other host in the tables below landed on \`main\`.

Latest pipeline run: $RUN_URL

---

$body"
}

if ((${#failed_hosts[@]} == 0)); then
  gh pr merge --merge -R "$GITHUB_REPOSITORY" "$PR_NUMBER"
  exit 0
fi

echo "Failed to build: ${failed_hosts[*]}"
if ((${#built_locks[@]} > 0)); then
  commit_built_locks_to_main
fi
mark_pull_request_broken
