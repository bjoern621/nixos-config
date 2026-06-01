{ config, pkgs, ... }:

let
  sysconf-pull = pkgs.writeShellScriptBin "sysconf-pull" ''
    # Pull latest changes from git, then reload
    # set -e: exit immediately when a command fails
    # set -u: treat unset variables as an error
    # set -o pipefail: a pipeline fails if any command in it fails
    set -euo pipefail

    NIXOS_CONFIG="/etc/nixos/config"

    if [[ ! -d "$NIXOS_CONFIG" ]]; then
      echo "Missing source repo: $NIXOS_CONFIG" >&2
      exit 1
    fi

    if [[ ! -d "$NIXOS_CONFIG/.git" ]]; then
      echo "Source path exists but is not a git repo: $NIXOS_CONFIG" >&2
      exit 1
    fi

    cd "$NIXOS_CONFIG"

    # Host repos are deployment mirrors of origin, never hand-edited, so match
    # upstream exactly instead of merging. A hard reset is idempotent and
    # immune to local drift such as an uncommitted flake.lock override or a
    # half-applied pull. sysconf-reload re-copies the live
    # hardware-configuration.nix before building, so resetting that file to its
    # committed version does not affect the resulting configuration.
    #
    # Git runs as the invoking user (the repo owner), not via sudo, so the
    # working tree stays owned by that user. Only nixos-rebuild needs root.
    BRANCH=$(git rev-parse --abbrev-ref HEAD)

    echo "Fetching origin/$BRANCH in $NIXOS_CONFIG..."
    git fetch origin "$BRANCH"

    if ! git diff --quiet || ! git diff --cached --quiet; then
      echo "WARNING: discarding local changes in $NIXOS_CONFIG:" >&2
      git status --short >&2
    fi

    echo "Resetting to origin/$BRANCH..."
    git reset --hard "origin/$BRANCH"

    echo "Pull complete. Reloading system..."
    sysconf-reload
  '';
in
{
  environment.systemPackages = with pkgs; [
    sysconf-pull
  ];
}
