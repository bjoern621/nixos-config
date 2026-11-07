{ config, pkgs, ... }:

let
  sysconf-update = pkgs.writeShellScriptBin "sysconf-update" ''
    # Update this host's flake inputs, then reload.
    # set -e: exit immediately when a command fails
    # set -u: treat unset variables as an error
    # set -o pipefail: a pipeline fails if any command in it fails
    set -euo pipefail

    NIXOS_CONFIG="${config.sysconf.configPath}"

    usage() {
      echo "Usage: sysconf-update [<input>...]" >&2
      echo "  <input>  a flake input to update; none given updates all of them" >&2
    }

    for arg in "$@"; do
      case "$arg" in
        -h|--help)
          usage
          exit 0
          ;;
        -*)
          echo "[sysconf-update] Unknown flag: $arg" >&2
          usage
          exit 1
          ;;
      esac
    done

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

    if [[ $# -gt 0 ]]; then
      echo "[sysconf-update] Updating flake inputs $* for $DETECTED_HOST ($HOST_FLAKE)..."
    else
      echo "[sysconf-update] Updating all flake inputs for $DETECTED_HOST ($HOST_FLAKE)..."
    fi
    cd "$HOST_FLAKE"
    sudo nix flake update "$@"

    echo "[sysconf-update] Updating complete. Reloading system..."
    sysconf-reload
  '';

  # Completes input names from the lock file of the host that sysconf-update would pick.
  sysconf-update-completion = pkgs.writeTextDir "share/zsh/site-functions/_sysconf-update" ''
    #compdef sysconf-update

    local host lock
    local -a inputs
    host=$(tr -d '[:space:]' < /etc/hostname 2>/dev/null)
    lock="${config.sysconf.configPath}/hosts/$host/flake.lock"
    [[ -r $lock ]] || return 1

    inputs=( ''${(f)"$(${pkgs.jq}/bin/jq -r '.nodes[.root].inputs | keys[]' "$lock" 2>/dev/null)"} )
    # Drop inputs already on the command line.
    inputs=( ''${inputs:|words} )
    _wanted inputs expl 'flake input' compadd -a inputs
  '';
in
{
  environment.systemPackages = [
    sysconf-update
    sysconf-update-completion
  ];
}
