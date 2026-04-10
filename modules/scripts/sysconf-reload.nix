{ config, pkgs, ... }:

let
  sysconf-reload = pkgs.writeShellScriptBin "sysconf-reload" ''
    set -euo pipefail

    NIXOS_CONFIG="/etc/nixos/config"
    TARGET_HOST="''${1:-}"

    if [[ ! -d "$NIXOS_CONFIG" ]]; then
      echo "Missing source repo: $NIXOS_CONFIG" >&2
      exit 1
    fi

    if [[ $# -gt 1 ]]; then
      echo "Usage: sysconf-reload [nixos|homelab]" >&2
      exit 1
    fi

    if [[ -n "$TARGET_HOST" ]]; then
      case "$TARGET_HOST" in
        nixos|homelab)
          echo "[sysconf-reload] Host argument provided: $TARGET_HOST"
          echo "[sysconf-reload] Skipping host auto-detection because argument was provided."
          ;;
        *)
          echo "[sysconf-reload] Invalid host argument: $TARGET_HOST" >&2
          echo "Usage: sysconf-reload [nixos|homelab]" >&2
          exit 1
          ;;
      esac
    else
      echo "[sysconf-reload] No host argument provided. Detecting active host..."

      if [[ ! -f /etc/hostname ]]; then
        echo "[sysconf-reload] Failed to detect host: /etc/hostname is missing." >&2
        exit 1
      fi

      DETECTED_HOST=$(tr -d '[:space:]' < /etc/hostname)
      echo "[sysconf-reload] Detected hostname: $DETECTED_HOST"

      case "$DETECTED_HOST" in
        nixos|homelab)
          TARGET_HOST="$DETECTED_HOST"
          echo "[sysconf-reload] Rebuild target resolved to flake host: $TARGET_HOST"
          ;;
        *)
          echo "[sysconf-reload] Failed to map detected hostname '$DETECTED_HOST' to a known flake host." >&2
          echo "[sysconf-reload] Supported hosts: nixos, homelab" >&2
          exit 1
          ;;
      esac
    fi

    if [[ ! -f /etc/nixos/hardware-configuration.nix ]]; then
      echo "Missing /etc/nixos/hardware-configuration.nix" >&2
      exit 1
    fi

    HARDWARE_TARGET="$NIXOS_CONFIG/hosts/$TARGET_HOST/hardware-configuration.nix"
    echo "[sysconf-reload] Copying /etc/nixos/hardware-configuration.nix -> $HARDWARE_TARGET"
    sudo mkdir -p "$NIXOS_CONFIG/hosts/$TARGET_HOST"
    sudo cp -f /etc/nixos/hardware-configuration.nix "$HARDWARE_TARGET"

    NEW_FILES=$(sudo git -C "$NIXOS_CONFIG" ls-files --others --exclude-standard | wc -l)
    sudo git -C "$NIXOS_CONFIG" add -N .
    echo "[sysconf-reload] Marked $NEW_FILES untracked files as intent-to-add so Nix can see them."

    echo "[sysconf-reload] Rebuilding flake target: $TARGET_HOST"
    sudo nixos-rebuild switch --flake "$NIXOS_CONFIG#$TARGET_HOST"

    echo "[sysconf-reload] System reloaded successfully for host: $TARGET_HOST"
  '';
in
{
  environment.systemPackages = with pkgs; [
    sysconf-reload
  ];
}
