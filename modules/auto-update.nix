{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.nixos-auto-update;
in
{
  options.services.nixos-auto-update = {
    enable = lib.mkEnableOption "automatic weekly NixOS updates using delayed stable strategy";

    user = lib.mkOption {
      type = lib.types.str;
      description = "User that owns the config repo (runs nix flake update as this user)";
    };

    delayDays = lib.mkOption {
      type = lib.types.int;
      default = 7;
      description = "Minimum age in days for updates before they are applied";
    };

    schedule = lib.mkOption {
      type = lib.types.str;
      default = "Mon 03:00";
      description = "Systemd timer schedule (default: Monday 3 AM)";
    };
  };

  config = lib.mkIf cfg.enable {
    # Allow the repo owner to run nixos-rebuild as root without a password,
    # so the service can do the full update + rebuild without running as root.
    security.sudo.extraRules = [
      {
        users = [ cfg.user ];
        commands = [
          {
            command = "/run/current-system/sw/bin/nixos-rebuild";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ];

    systemd.services.nixos-stable-update = {
      description = "Update NixOS to stable (week-old) nixpkgs revision";
      serviceConfig = {
        Type = "oneshot";
        User = cfg.user;
        WorkingDirectory = "/etc/nixos/config";
      };
      path = [
        pkgs.nix
        pkgs.git
        pkgs.curl
        pkgs.jq
        pkgs.coreutils
      ];
      script = ''
        set -euo pipefail

        NIXOS_CONFIG="/etc/nixos/config"
        DELAY_DAYS="${toString cfg.delayDays}"

        if [[ ! -d "$NIXOS_CONFIG" ]]; then
          echo "Missing source repo: $NIXOS_CONFIG" >&2
          exit 1
        fi

        cd "$NIXOS_CONFIG"

        # Calculate the date threshold
        THRESHOLD_DATE=$(date -d "$DELAY_DAYS days ago" +%Y-%m-%dT00:00:00Z 2>/dev/null || \
                         date -v-''${DELAY_DAYS}d +%Y-%m-%dT00:00:00Z 2>/dev/null)

        if [[ -z "$THRESHOLD_DATE" ]]; then
          echo "Failed to calculate threshold date" >&2
          exit 1
        fi

        echo "Updating flake inputs to revisions from before $THRESHOLD_DATE..."
        echo ""

        # Function to get delayed revision from GitHub
        get_delayed_revision() {
          local owner_repo="$1"
          local branch="$2"

          local commits_json
          commits_json=$(curl -s \
            "https://api.github.com/repos/$owner_repo/commits?sha=$branch&until=$THRESHOLD_DATE&per_page=1")

          # Check for API error (rate limit, etc.)
          if echo "$commits_json" | ${pkgs.jq}/bin/jq -e '.message // empty' >/dev/null 2>&1; then
            local api_message
            api_message=$(echo "$commits_json" | ${pkgs.jq}/bin/jq -r '.message')
            echo "  API error: $api_message" >&2
            return 1
          fi

          echo "$commits_json" | ${pkgs.jq}/bin/jq -r '.[0].sha // empty'
        }

        # Function to get current locked revision from flake.lock
        get_current_revision() {
          local input_name="$1"
          if [[ -f "flake.lock" ]]; then
            ${pkgs.jq}/bin/jq -r ".nodes[\"$input_name\"].locked.rev // empty" flake.lock 2>/dev/null || true
          fi
        }

        # Function to get commit date from GitHub
        get_commit_date() {
          local owner_repo="$1"
          local sha="$2"
          local commits_json
          commits_json=$(curl -s "https://api.github.com/repos/$owner_repo/commits/$sha")

          # Check for API error
          if echo "$commits_json" | ${pkgs.jq}/bin/jq -e '.message // empty' >/dev/null 2>&1; then
            return 1
          fi

          echo "$commits_json" | ${pkgs.jq}/bin/jq -r '.commit.committer.date // empty' 2>/dev/null || true
        }

        # Known flake inputs: "name" "owner/repo" "branch"
        declare -A FLAKE_INPUTS=(
          ["nixpkgs"]="nixos/nixpkgs:nixos-unstable"
          ["home-manager"]="nix-community/home-manager:master"
          ["hyprland"]="hyprwm/Hyprland:main"
          ["quickshell"]="quickshell-mirror/quickshell:master"
          ["nix-search-tv"]="3timeslazy/nix-search-tv:main"
          ["caelestia-shell"]="caelestia-dots/shell:main"
        )

        UPDATED_COUNT=0
        SKIPPED_COUNT=0
        DOWNGRADE_COUNT=0

        for input_name in "''${!FLAKE_INPUTS[@]}"; do
          IFS=':' read -r owner_repo branch <<< "''${FLAKE_INPUTS[$input_name]}"

          echo "Checking $input_name ($owner_repo @ $branch)..."

          target_sha=$(get_delayed_revision "$owner_repo" "$branch") || {
            echo "  Skipping: failed to fetch revision"
            SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
            continue
          }

          if [[ -z "$target_sha" ]]; then
            echo "  Skipping: no suitable revision found"
            SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
            continue
          fi

          target_sha_short=''${target_sha:0:7}

          # Check if we already have a newer revision locked
          current_sha=$(get_current_revision "$input_name")

          if [[ -n "$current_sha" ]]; then
            current_sha_short=''${current_sha:0:7}

            if [[ "$current_sha" == "$target_sha" ]]; then
              echo "  Already at target revision: $target_sha_short"
              SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
              continue
            fi

            # Compare commit dates to detect downgrade
            current_date=$(get_commit_date "$owner_repo" "$current_sha") || true
            target_date=$(get_commit_date "$owner_repo" "$target_sha") || true

            if [[ -n "$current_date" && -n "$target_date" ]]; then
              if [[ "$current_date" > "$target_date" ]]; then
                echo "  Warning: current revision ($current_sha_short from $current_date) is NEWER than target"
                echo "  Downgrading to $target_sha_short (from $target_date) for stability"
                DOWNGRADE_COUNT=$((DOWNGRADE_COUNT + 1))
              fi
            fi
          fi

          echo "  Updating to revision: $target_sha_short (from $target_date)"
          nix flake update --override-input "$input_name" "github:$owner_repo/$target_sha"
          UPDATED_COUNT=$((UPDATED_COUNT + 1))
        done

        echo ""
        echo "Updated: $UPDATED_COUNT, Skipped: $SKIPPED_COUNT, Downgraded: $DOWNGRADE_COUNT"
        echo "Rebuilding system..."

        # Copy hardware config first (like sysconf-reload does)
        cp /etc/nixos/hardware-configuration.nix "$NIXOS_CONFIG/hosts/default/hardware-configuration.nix"

        # Rebuild requires root; use NixOS setuid wrapper and full nixos-rebuild path
        /run/wrappers/bin/sudo /run/current-system/sw/bin/nixos-rebuild switch --flake "$NIXOS_CONFIG#nixos"

        echo "System updated successfully"
      '';
    };

    systemd.timers.nixos-stable-update = {
      description = "Weekly timer for stable NixOS updates";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.schedule;
        Persistent = true; # Run if missed during downtime
        RandomizedDelaySec = "1h"; # Spread load on GitHub API
      };
    };
  };
}
