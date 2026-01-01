{ config, pkgs, ... }:

let
  sysconf-update = pkgs.writeShellScriptBin "sysconf-update" ''
    # Update flake inputs, then reload
    # set -e: exit immediately when a command fails
    # set -u: treat unset variables as an error
    # set -o pipefail: a pipeline fails if any command in it fails
    set -euo pipefail

    NIXOS_CONFIG="/etc/nixos/config"

    if [[ ! -d "$NIXOS_CONFIG" ]]; then
      echo "Missing source repo: $NIXOS_CONFIG" >&2
      exit 1
    fi

    echo "Updating flake in $NIXOS_CONFIG..."
    cd "$NIXOS_CONFIG"
    sudo nix flake update

    echo "Updating complete. Reloading system..."
    sysconf-reload
  '';
in
{
  environment.systemPackages = with pkgs; [
    sysconf-update
  ];
}
