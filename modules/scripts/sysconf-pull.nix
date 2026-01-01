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

    echo "Pulling latest changes in $NIXOS_CONFIG..."
    cd "$NIXOS_CONFIG"
    sudo git pull --ff-only

    echo "Pull complete. Reloading system..."
    sysconf-reload
  '';
in
{
  environment.systemPackages = with pkgs; [
    sysconf-pull
  ];
}
