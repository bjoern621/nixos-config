{ config, pkgs, ... }:

let
  sysconf-reload = pkgs.writeShellScriptBin "sysconf-reload" ''
    # Base operation: Sync hardware config and rebuild
    # set -e: exit immediately when a command fails
    # set -u: treat unset variables as an error
    # set -o pipefail: a pipeline fails if any command in it fails
    set -euo pipefail

    NIXOS_CONFIG="/etc/nixos/config"

    if [[ ! -d "$NIXOS_CONFIG" ]]; then
      echo "Missing source repo: $NIXOS_CONFIG" >&2
      exit 1
    fi

    if [[ ! -f /etc/nixos/hardware-configuration.nix ]]; then
      echo "Missing /etc/nixos/hardware-configuration.nix" >&2
      exit 1
    fi

    echo "Copying /etc/nixos/hardware-configuration.nix -> $NIXOS_CONFIG/hosts/default/hardware-configuration.nix..."
    sudo mkdir -p "$NIXOS_CONFIG/hosts/default"
    sudo cp -f /etc/nixos/hardware-configuration.nix "$NIXOS_CONFIG/hosts/default/hardware-configuration.nix"

    # git ls-files: list files in the repo
    #   --others: only show untracked files
    #   --exclude-standard: respect .gitignore rules
    # wc -l: count the number of lines (= number of files)
    NEW_FILES=$(sudo git -C "$NIXOS_CONFIG" ls-files --others --exclude-standard | wc -l)
    sudo git -C "$NIXOS_CONFIG" add -N .
    echo "Marked $NEW_FILES untracked files as intent-to-add so Nix can see them."

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
