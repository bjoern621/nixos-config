{ config, pkgs, ... }:

let
  sysconf-pull = pkgs.writeShellScriptBin "sysconf-pull" ''
    # Pull latest changes from git, then reload
    # set -e: exit immediately when a command fails
    # set -u: treat unset variables as an error
    # set -o pipefail: a pipeline fails if any command in it fails
    set -euo pipefail

    NIXOS_CONFIG="${config.sysconf.configPath}"
    HARD=0

    while [[ $# -gt 0 ]]; do
      case "$1" in
        --hard)
          HARD=1
          shift
          ;;
        -h|--help)
          echo "Usage: sysconf-pull [--hard]"
          echo ""
          echo "  (default)  Fast-forward to origin. Aborts on local commits."
          echo "  --hard     Reset to origin, discarding local commits and changes."
          exit 0
          ;;
        *)
          echo "Unknown argument: $1" >&2
          echo "Usage: sysconf-pull [--hard]" >&2
          exit 1
          ;;
      esac
    done

    if [[ ! -d "$NIXOS_CONFIG" ]]; then
      echo "Missing source repo: $NIXOS_CONFIG" >&2
      exit 1
    fi

    if [[ ! -d "$NIXOS_CONFIG/.git" ]]; then
      echo "Source path exists but is not a git repo: $NIXOS_CONFIG" >&2
      exit 1
    fi

    cd "$NIXOS_CONFIG"

    # Git runs as the invoking user (the repo owner), not via sudo, so the
    # working tree stays owned by that user. Only nixos-rebuild needs root.
    BRANCH=$(git rev-parse --abbrev-ref HEAD)

    echo "Fetching origin/$BRANCH in $NIXOS_CONFIG..."
    git fetch origin "$BRANCH"

    AHEAD=$(git rev-list --count "origin/$BRANCH..HEAD")

    if [[ "$HARD" -eq 1 ]]; then
      # Deployment mirrors of origin are never hand-edited, so matching upstream
      # exactly is safe there. A hard reset is idempotent and immune to local
      # drift such as an uncommitted flake.lock override or a half-applied pull.
      # It destroys unpushed commits, so it is opt-in.
      if [[ "$AHEAD" -gt 0 ]]; then
        echo "WARNING: discarding $AHEAD local commit(s) not on origin/$BRANCH:" >&2
        git log --oneline "origin/$BRANCH..HEAD" >&2
      fi

      if ! git diff --quiet || ! git diff --cached --quiet; then
        echo "WARNING: discarding local changes in $NIXOS_CONFIG:" >&2
        git status --short >&2
      fi

      echo "Resetting to origin/$BRANCH..."
      git reset --hard "origin/$BRANCH"
    else
      if [[ "$AHEAD" -gt 0 ]]; then
        echo "Refusing to pull: $AHEAD local commit(s) not on origin/$BRANCH:" >&2
        git log --oneline "origin/$BRANCH..HEAD" >&2
        echo "" >&2
        echo "Push them, or rerun with --hard to discard them." >&2
        exit 1
      fi

      # No explicit dirty check. sysconf-reload copies hardware-configuration.nix
      # into the repo and runs `git add -N .`, so a working tree is routinely
      # dirty for reasons unrelated to the pull. --ff-only aborts on its own when
      # the incoming commits would overwrite a local edit, and carries the rest through.
      echo "Fast-forwarding to origin/$BRANCH..."
      git merge --ff-only "origin/$BRANCH"
    fi

    echo "Pull complete. Reloading system..."
    sysconf-reload
  '';
in
{
  environment.systemPackages = with pkgs; [
    sysconf-pull
  ];
}
