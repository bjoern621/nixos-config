{ config, pkgs, ... }:

let
  sysconf-reload = pkgs.writeShellScriptBin "sysconf-reload" ''
    # set -e: exit immediately when a command fails
    # set -u: treat unset variables as an error
    # set -o pipefail: a pipeline fails if any command in it fails
    set -euo pipefail

    NIXOS_CONFIG_ROOT="/etc/nixos"
    NIXOS_CONFIG="$NIXOS_CONFIG_ROOT/nixos-config"

    if [[ ! -d "$NIXOS_CONFIG" ]]; then
      echo "Missing source repo: $NIXOS_CONFIG" >&2
      exit 1
    fi

    if [[ ! -d "$NIXOS_CONFIG_ROOT" ]]; then
      echo "Missing target config dir: $NIXOS_CONFIG_ROOT" >&2
      exit 1
    fi

    if [[ ! -f "$NIXOS_CONFIG_ROOT/hardware-configuration.nix" ]]; then
      echo "Missing $NIXOS_CONFIG_ROOT/hardware-configuration.nix" >&2
      exit 1
    fi

    echo "Copying $NIXOS_CONFIG_ROOT/hardware-configuration.nix -> $NIXOS_CONFIG/hosts/default/hardware-configuration.nix..."
    sudo mkdir -p "$NIXOS_CONFIG/hosts/default"
    sudo cp -f "$NIXOS_CONFIG_ROOT/hardware-configuration.nix" "$NIXOS_CONFIG/hosts/default/hardware-configuration.nix"

    echo "Rebuilding NixOS from $NIXOS_CONFIG..."
    sudo nixos-rebuild switch --flake "$NIXOS_CONFIG#nixos"

    echo "System reloaded successfully!"
    echo "You may want to reboot now."
  '';
in
{
  environment.systemPackages = with pkgs; [
    sysconf-reload
  ];
}
