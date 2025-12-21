{ config, pkgs, ... }:

let
  sysconf-update = pkgs.writeShellScriptBin "sysconf-update" ''
    # set -e: exit immediately when a command fails
    # set -u: treat unset variables as an error
    # set -o pipefail: a pipeline fails if any command in it fails
    set -euo pipefail

    SOURCE_REPO="/etc/nixos/nixos-config"
    NIXOS_CONFIG_ROOT="/etc/nixos"
    NIXOS_CONFIG="$NIXOS_CONFIG_ROOT/nixos-config"

    if [[ ! -d "$SOURCE_REPO" ]]; then
      echo "Missing source repo: $SOURCE_REPO" >&2
      exit 1
    fi

    if ! sudo test -d "$SOURCE_REPO/.git"; then
      echo "Source path exists but is not a git repo: $SOURCE_REPO" >&2
      echo "Create it with: sudo git clone <remote> $SOURCE_REPO" >&2
      exit 1
    fi

    if [[ ! -d "$NIXOS_CONFIG_ROOT" ]]; then
      echo "Missing target config dir: $NIXOS_CONFIG_ROOT" >&2
      exit 1
    fi

    echo "Pulling latest changes in $SOURCE_REPO..."
    cd "$SOURCE_REPO"
    sudo git pull --ff-only

    echo "Syncing $SOURCE_REPO -> $NIXOS_CONFIG..."
    sudo rm -rf "$NIXOS_CONFIG"
    sudo mkdir -p "$NIXOS_CONFIG"
    sudo cp -a "$SOURCE_REPO/." "$NIXOS_CONFIG/" # cp -a: archive mode (preserves permissions/ownership/timestamps and copies directories recursively)
    sudo rm -rf "$NIXOS_CONFIG/.git"

    if [[ ! -f "$NIXOS_CONFIG_ROOT/haconf.nix" ]]; then
      echo "Missing $NIXOS_CONFIG_ROOT/haconf.nix" >&2
      exit 1
    fi

    echo "Copying $NIXOS_CONFIG_ROOT/haconf.nix -> $NIXOS_CONFIG/hosts/default/hardware-configuration.nix..."
    sudo mkdir -p "$NIXOS_CONFIG/hosts/default"
    sudo cp -f "$NIXOS_CONFIG_ROOT/haconf.nix" "$NIXOS_CONFIG/hosts/default/hardware-configuration.nix"

    echo "Rebuilding NixOS from $NIXOS_CONFIG..."
    sudo nixos-rebuild switch --flake "$NIXOS_CONFIG#nixos"

    echo "System updated successfully!"
    echo "You may want to reboot now."
  '';
in
{
  environment.systemPackages = with pkgs; [
    sysconf-update
  ];
}
