{ config, pkgs, ... }:

let
  sysconf-reload = pkgs.writeShellScriptBin "sysconf-reload" ''
    set -euo pipefail

    NIXOS_CONFIG="${config.sysconf.configPath}"
    TARGET_HOST=""
    REMOTE=0
    REMOTE_ADDRESS=""

    usage() {
      echo "Usage: sysconf-reload [<host>] [--remote <ssh-target>]" >&2
      echo "  <host>        a directory under hosts/, whose configuration is built" >&2
      echo "  <ssh-target>  where to activate it, e.g. root@203.0.113.9" >&2
    }

    if [[ ! -d "$NIXOS_CONFIG" ]]; then
      echo "[sysconf-reload] Missing source repo: $NIXOS_CONFIG" >&2
      echo "[sysconf-reload] Clone it there, or set sysconf.configPath to where it is." >&2
      exit 1
    fi

    while [[ $# -gt 0 ]]; do
      case "$1" in
        --remote)
          # Required, with no fallback to an address declared anywhere: one command reading two
          # different targets depending on what was typed is one whose target has to be worked
          # out rather than read.
          if [[ $# -lt 2 || "$2" == -* ]]; then
            echo "[sysconf-reload] --remote takes the address to activate on." >&2
            usage
            exit 1
          fi
          REMOTE=1
          REMOTE_ADDRESS="$2"
          shift
          ;;
        -h|--help)
          usage
          exit 0
          ;;
        -*)
          echo "[sysconf-reload] Unknown flag: $1" >&2
          usage
          exit 1
          ;;
        *)
          if [[ -n "$TARGET_HOST" ]]; then
            echo "[sysconf-reload] More than one host given: $TARGET_HOST and $1" >&2
            usage
            exit 1
          fi
          TARGET_HOST="$1"
          ;;
      esac
      shift
    done

    # Each host lives at $NIXOS_CONFIG/hosts/<host>/flake.nix.
    if [[ ! -d "$NIXOS_CONFIG/hosts" ]]; then
      echo "[sysconf-reload] Missing $NIXOS_CONFIG/hosts directory" >&2
      exit 1
    fi

    VALID_HOSTS=""
    for host_dir in "$NIXOS_CONFIG/hosts"/*/; do
      [[ -d "$host_dir" ]] || continue
      [[ -f "$host_dir/flake.nix" ]] || continue
      host_name=$(basename "$host_dir")
      VALID_HOSTS+="$host_name "
    done
    VALID_HOSTS=''${VALID_HOSTS% }

    if [[ -z "$VALID_HOSTS" ]]; then
      echo "[sysconf-reload] No hosts with flake.nix found under $NIXOS_CONFIG/hosts/" >&2
      exit 1
    fi

    if [[ -n "$TARGET_HOST" ]]; then
      if [[ " $VALID_HOSTS " != *" $TARGET_HOST "* ]]; then
        echo "[sysconf-reload] Invalid host argument: $TARGET_HOST" >&2
        echo "[sysconf-reload] Supported hosts: $VALID_HOSTS" >&2
        exit 1
      fi
      echo "[sysconf-reload] Host argument provided: $TARGET_HOST"
      echo "[sysconf-reload] Skipping host auto-detection because argument was provided."
    elif [[ $REMOTE -eq 1 ]]; then
      # The local hostname says which machine is running the script, which is not the
      # machine a remote deploy is about.
      echo "[sysconf-reload] --remote needs the host named: it is never the local one." >&2
      echo "[sysconf-reload] Supported hosts: $VALID_HOSTS" >&2
      exit 1
    else
      echo "[sysconf-reload] No host argument provided. Detecting active host..."

      if [[ ! -f /etc/hostname ]]; then
        echo "[sysconf-reload] Failed to detect host: /etc/hostname is missing." >&2
        exit 1
      fi

      DETECTED_HOST=$(tr -d '[:space:]' < /etc/hostname)
      echo "[sysconf-reload] Detected hostname: $DETECTED_HOST"

      if [[ " $VALID_HOSTS " == *" $DETECTED_HOST "* ]]; then
        TARGET_HOST="$DETECTED_HOST"
        echo "[sysconf-reload] Rebuild target resolved to flake host: $TARGET_HOST"
      else
        echo "[sysconf-reload] Failed to map detected hostname '$DETECTED_HOST' to a known flake host." >&2
        echo "[sysconf-reload] Supported hosts: $VALID_HOSTS" >&2
        exit 1
      fi
    fi

    HARDWARE_TARGET="$NIXOS_CONFIG/hosts/$TARGET_HOST/hardware-configuration.nix"

    if [[ $REMOTE -eq 1 ]]; then
      # /etc/nixos/hardware-configuration.nix describes the machine running the
      # script, so copying it onto a remote host would overwrite that host's layout
      # with this one's. A remote host keeps its own, committed with the host.
      if [[ ! -f "$HARDWARE_TARGET" ]]; then
        echo "[sysconf-reload] Missing $HARDWARE_TARGET" >&2
        echo "[sysconf-reload] Write it, or take the machine's own:" >&2
        echo "[sysconf-reload]   ssh <host> nixos-generate-config --dir /tmp/hw" >&2
        exit 1
      fi
      echo "[sysconf-reload] Remote deploy: keeping the committed hardware-configuration.nix."
    elif [[ ! -f /etc/nixos/hardware-configuration.nix && -f "$HARDWARE_TARGET" ]]; then
      # A host installed from a flake image never ran nixos-generate-config, so its hardware
      # description is the committed one and there is nothing here to capture.
      echo "[sysconf-reload] No /etc/nixos/hardware-configuration.nix: keeping the committed one."
    else
      if [[ ! -f /etc/nixos/hardware-configuration.nix ]]; then
        echo "Missing /etc/nixos/hardware-configuration.nix, and $HARDWARE_TARGET is not there either" >&2
        echo "[sysconf-reload] Write one, or take the machine's own:" >&2
        echo "[sysconf-reload]   nixos-generate-config --dir /tmp/hw" >&2
        exit 1
      fi

      # Git and file operations run as the invoking user (the repo owner) so the
      # working tree stays owned by that user. Only nixos-rebuild needs root.
      mkdir -p "$NIXOS_CONFIG/hosts/$TARGET_HOST"
      if [[ /etc/nixos/hardware-configuration.nix -ef "$HARDWARE_TARGET" ]]; then
        echo "[sysconf-reload] Skipping hardware-configuration.nix copy (source and target are the same file)."
      else
        echo "[sysconf-reload] Copying /etc/nixos/hardware-configuration.nix -> $HARDWARE_TARGET"
        cp -f /etc/nixos/hardware-configuration.nix "$HARDWARE_TARGET"
      fi
    fi

    NEW_FILES=$(git -C "$NIXOS_CONFIG" ls-files --others --exclude-standard | wc -l)
    git -C "$NIXOS_CONFIG" add -N .
    echo "[sysconf-reload] Marked $NEW_FILES untracked files as intent-to-add so Nix can see them."

    if [[ $REMOTE -eq 1 ]]; then
      DEPLOY_TARGET="$REMOTE_ADDRESS"
      echo "[sysconf-reload] Deploying to the address given: $DEPLOY_TARGET"

      # The flake attribute is named because nixos-rebuild otherwise picks the one
      # matching the local hostname.
      # The closure is built here and fetched there: --use-substitutes lets the target
      # take what the binary cache already has instead of pulling it over this uplink.
      echo "[sysconf-reload] Rebuilding flake target $TARGET_HOST on $DEPLOY_TARGET"
      nixos-rebuild switch \
        --flake "$NIXOS_CONFIG/hosts/$TARGET_HOST#$TARGET_HOST" \
        --target-host "$DEPLOY_TARGET" \
        --use-substitutes

      echo "[sysconf-reload] System reloaded successfully on $DEPLOY_TARGET (host: $TARGET_HOST)"
    else
      echo "[sysconf-reload] Rebuilding flake target: $TARGET_HOST"
      sudo nixos-rebuild switch --flake "$NIXOS_CONFIG/hosts/$TARGET_HOST"

      echo "[sysconf-reload] System reloaded successfully for host: $TARGET_HOST"
    fi
  '';
in
{
  environment.systemPackages = [
    sysconf-reload
  ];
}
