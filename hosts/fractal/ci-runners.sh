# Lends this host to the pidgemail GitLab group as CI runner, plus LAN SSH.
#   ci-runners up      start sshd, unpause runner, start runner container
#   ci-runners down    pause runner, let running jobs finish, stop everything
#   ci-runners down --now   same, aborting running jobs
#   ci-runners status
#   ci-runners toggle  down while the runner container runs, up otherwise
# ci-runner.nix installs this as `ci-runners` and sets up the host side. Nothing starts at boot.

GITLAB_URL="https://gitlab.bjoernblessin.de"
GROUP_ID=4
RUNNER_NAME="fractal"
RUNNER_IMAGE="gitlab/gitlab-runner:v19.5.3"
CONTAINER="gitlab-runner-fractal"
STATE_DIR="$HOME/.local/share/gitlab-runner-fractal"
# Created and pruned by ci-runner.nix.
CACHE_DIR=/var/lib/gitlab-runner-fractal/cache
SYSTEMCTL=/run/current-system/sw/bin/systemctl
# Matches the runner's job timeout.
DRAIN_TIMEOUT_S=3600

log() { echo "[ci-runners] $*"; }

json_field() {
  grep -o "\"$1\":\"\?[^\",}]*" | head -1 | sed -E "s/^\"$1\":\"?//"
}

runner_id() { cat "$STATE_DIR/runner-id" 2>/dev/null || true; }

runner_exists() {
  local id
  id=$(runner_id)
  [[ -n "$id" && -s "$STATE_DIR/token" ]] && glab api "runners/$id" >/dev/null 2>&1
}

register_runner() {
  local response
  log "Registering group runner '$RUNNER_NAME' in group $GROUP_ID"
  response=$(glab api --method POST user/runners \
    -f runner_type=group_type \
    -f group_id="$GROUP_ID" \
    -f description="$RUNNER_NAME" \
    -f run_untagged=true \
    -f maintenance_note="Docker runner on fractal (LAN desktop), switched with ~/Desktop/ci-runners")
  mkdir -p "$STATE_DIR"
  (
    umask 077
    json_field id <<<"$response" >"$STATE_DIR/runner-id"
    json_field token <<<"$response" >"$STATE_DIR/token"
  )
  log "Registered runner $(runner_id)"
}

# Rewritten on every `up`, so edits here reach the runner.
write_config() {
  (
    umask 077
    cat >"$STATE_DIR/config.toml" <<EOF
# 16 cores; beyond this the load passed 30 and Playwright suites timed out.
concurrent = 12
check_interval = 3
log_format = "json"

[[runners]]
  name = "$RUNNER_NAME"
  url = "$GITLAB_URL"
  token = "$(cat "$STATE_DIR/token")"
  executor = "docker"
  limit = 12
  request_concurrency = 4

  [runners.docker]
    image = "alpine:3.23"
    privileged = false
    cgroup_parent = "gitlab-ci.slice"
    # Rootless BuildKit unshares namespaces, which Docker's default seccomp profile blocks.
    security_opt = ["seccomp=unconfined", "apparmor=unconfined"]
    memory = "8g"
    memory_swap = "10g"
    shm_size = 1073741824
    # One host directory for every slot, so a job restores what any earlier job here saved.
    volumes = ["$CACHE_DIR:/cache"]
    pull_policy = ["if-not-present"]
EOF
  )
}

set_paused() {
  local id
  id=$(runner_id)
  [[ -n "$id" ]] || return 0
  glab api --method PUT "runners/$id" -f paused="$1" >/dev/null ||
    log "Could not set paused=$1 on runner $id"
}

remove_job_containers() {
  docker ps -aq --filter label=com.gitlab.gitlab-runner.managed=true | xargs -r docker rm -f >/dev/null
}

up() {
  sudo -n "$SYSTEMCTL" start sshd.service
  log "sshd listening on port 22 (LAN only)"

  runner_exists || register_runner
  write_config
  set_paused false

  docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
  docker run -d -q --name "$CONTAINER" --restart no \
    -v "$STATE_DIR:/etc/gitlab-runner" \
    -v /var/run/docker.sock:/var/run/docker.sock \
    "$RUNNER_IMAGE" >/dev/null
  log "Runner $(runner_id) up"
}

running_jobs() {
  docker ps -q --filter label=com.gitlab.gitlab-runner.managed=true | wc -l
}

# SIGQUIT makes gitlab-runner take no new jobs and exit once running ones finish.
drain() {
  local waited=0
  docker kill -s QUIT "$CONTAINER" >/dev/null 2>&1 || return 0
  while [[ "$(docker inspect -f '{{.State.Running}}' "$CONTAINER" 2>/dev/null)" == true ]]; do
    if ((waited >= DRAIN_TIMEOUT_S)); then
      log "Jobs still running after ${DRAIN_TIMEOUT_S}s, aborting them"
      return 0
    fi
    log "Waiting for $(running_jobs) job containers to finish ('down --now' aborts them)"
    sleep 15
    waited=$((waited + 15))
  done
}

down() {
  set_paused true
  # --now aborts running jobs; GitLab marks them failed.
  [[ "${1:-}" == --now ]] || drain
  docker stop -t 10 "$CONTAINER" >/dev/null 2>&1 || true
  docker rm "$CONTAINER" >/dev/null 2>&1 || true
  remove_job_containers
  log "Runner $(runner_id) paused and stopped"

  sudo -n "$SYSTEMCTL" stop sshd.service
  log "sshd stopped"
}

status() {
  local id runner container
  container=$(docker inspect -f '{{.State.Status}}' "$CONTAINER" 2>/dev/null) || container=absent
  echo "sshd:      $($SYSTEMCTL is-active sshd.service || true)"
  echo "container: $container"
  echo "jobs:      $(running_jobs) containers"
  id=$(runner_id)
  if [[ -n "$id" ]] && runner=$(glab api "runners/$id" 2>/dev/null); then
    echo "gitlab:    runner $id $(json_field status <<<"$runner"), paused=$(json_field paused <<<"$runner")"
  else
    echo "gitlab:    no runner registered"
  fi
}

toggle() {
  if [[ "$(docker inspect -f '{{.State.Running}}' "$CONTAINER" 2>/dev/null)" == true ]]; then
    down
  else
    up
  fi
}

case "${1:-}" in
  up) up ;;
  down) down "${2:-}" ;;
  status) status ;;
  toggle) toggle ;;
  *)
    echo "Usage: ci-runners up | down [--now] | status | toggle" >&2
    exit 1
    ;;
esac
