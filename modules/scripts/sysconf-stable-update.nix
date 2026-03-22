{ config, pkgs, ... }:

let
  sysconf-stable-update = pkgs.writeShellScriptBin "sysconf-stable-update" ''
    # Update all flake inputs to revisions that are at least N days old
    # This provides a "baking period" for updates to stabilize
    set -euo pipefail

    NIXOS_CONFIG="/etc/nixos/config"
    DELAY_DAYS=''${1:-7}  # Default 7 days, can be overridden

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
      echo "$commits_json" | ${pkgs.jq}/bin/jq -r '.commit.committer.date // empty' 2>/dev/null || true
    }

    # Known flake inputs: "name" "owner/repo" "branch"
    declare -A FLAKE_INPUTS=(
      ["nixpkgs"]="nixos/nixpkgs:nixos-unstable"
      ["home-manager"]="nix-community/home-manager:master"
      ["hyprland"]="hyprwm/Hyprland:main"
      ["quickshell"]="quickshell-mirror/quickshell:master"
      ["nix-search-tv"]="3timeslazy/nix-search-tv:master"
      ["caelestia-shell"]="caelestia-dots/shell:main"
    )

    UPDATED_COUNT=0
    SKIPPED_COUNT=0
    DOWNGRADE_COUNT=0

    for input_name in "''${!FLAKE_INPUTS[@]}"; do
      IFS=':' read -r owner_repo branch <<< "''${FLAKE_INPUTS[$input_name]}"

      echo "Checking $input_name ($owner_repo @ $branch)..."

      target_sha=$(get_delayed_revision "$owner_repo" "$branch")

      if [[ -z "$target_sha" ]]; then
        echo "  Skipping: no suitable revision found"
        ((SKIPPED_COUNT++))
        continue
      fi

      target_sha_short=''${target_sha:0:7}

      # Check if we already have a newer revision locked
      current_sha=$(get_current_revision "$input_name")

      if [[ -n "$current_sha" ]]; then
        current_sha_short=''${current_sha:0:7}

        if [[ "$current_sha" == "$target_sha" ]]; then
          echo "  Already at target revision: $target_sha_short"
          ((SKIPPED_COUNT++))
          continue
        fi

        # Compare commit dates to detect downgrade
        current_date=$(get_commit_date "$owner_repo" "$current_sha")
        target_date=$(get_commit_date "$owner_repo" "$target_sha")

        if [[ -n "$current_date" && -n "$target_date" ]]; then
          if [[ "$current_date" > "$target_date" ]]; then
            echo "  Warning: current revision ($current_sha_short from $current_date) is NEWER than target"
            echo "  Downgrading to $target_sha_short (from $target_date) for stability"
            ((DOWNGRADE_COUNT++))
          fi
        fi
      fi

      echo "  Updating to revision: $target_sha_short"
      sudo nix flake update "$input_name" --revision "$target_sha"
      ((UPDATED_COUNT++))
    done

    echo ""
    echo "Updated: $UPDATED_COUNT, Skipped: $SKIPPED_COUNT, Downgraded: $DOWNGRADE_COUNT"
    echo "Reloading system..."
    sysconf-reload
  '';
in
{
  environment.systemPackages = with pkgs; [
    sysconf-stable-update
  ];
}
