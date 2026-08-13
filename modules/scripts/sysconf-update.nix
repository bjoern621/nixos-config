{ config, pkgs, ... }:

let
  sysconf-update = pkgs.writeShellScriptBin "sysconf-update" ''
    # Update this host's flake inputs, then reload.
    # set -e: exit immediately when a command fails
    # set -u: treat unset variables as an error
    # set -o pipefail: a pipeline fails if any command in it fails
    set -euo pipefail

    NIXOS_CONFIG="${config.sysconf.configPath}"

    if [[ ! -f /etc/hostname ]]; then
      echo "[sysconf-update] Failed to detect host: /etc/hostname is missing." >&2
      exit 1
    fi
    DETECTED_HOST=$(tr -d '[:space:]' < /etc/hostname)

    HOST_FLAKE="$NIXOS_CONFIG/hosts/$DETECTED_HOST"
    if [[ ! -f "$HOST_FLAKE/flake.nix" ]]; then
      echo "[sysconf-update] No flake at $HOST_FLAKE/flake.nix for host '$DETECTED_HOST'." >&2
      exit 1
    fi

    echo "[sysconf-update] Updating flake inputs for $DETECTED_HOST ($HOST_FLAKE)..."
    cd "$HOST_FLAKE"
    sudo nix flake update

    echo "[sysconf-update] Updating complete. Reloading system..."
    sysconf-reload
  '';
in
{
  environment.systemPackages = [
    sysconf-update
  ];
}
