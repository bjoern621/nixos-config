{ pkgs, ... }:

let
  # Wrapper around `cliphist store`: detects the KDE password-manager hint MIME
  # type (set by Bitwarden, KeePassXC, etc.) and records the resulting cliphist
  # id in a sidecar file so the Quickshell UI can mask the entry.
  cliphistStoreFiltered = pkgs.writeShellApplication {
    name = "cliphist-store-filtered";
    runtimeInputs = with pkgs; [ cliphist wl-clipboard coreutils gnugrep gawk ];
    text = ''
      set -u
      sidecar="''${XDG_CACHE_HOME:-$HOME/.cache}/cliphist/sensitive-ids"
      mkdir -p "$(dirname "$sidecar")"

      sensitive=0
      if wl-paste --list-types 2>/dev/null | grep -qi 'x-kde-passwordManagerHint'; then
        sensitive=1
      fi

      tmp="$(mktemp)"
      trap 'rm -f "$tmp"' EXIT
      cat > "$tmp"

      cliphist store "$@" < "$tmp"

      if [ "$sensitive" = "1" ]; then
        id="$(cliphist list | head -n1 | awk -F'\t' '{print $1}')"
        if [ -n "$id" ]; then
          printf '%s\n' "$id" >> "$sidecar"
        fi
      fi
    '';
  };
in
{
  # See also: https://wiki.hypr.land/Useful-Utilities/Clipboard-Managers/

  home.packages = with pkgs; [
    cliphist
    wl-clipboard
    wtype
    cliphistStoreFiltered
  ];

  # Watch for new clipboard content and store it in the history.
  # The wrapper also records sensitive ids (KDE password-manager hint) so the
  # Quickshell UI can render them masked.
  wayland.windowManager.hyprland.settings = {
    exec-once = [
      "wl-paste -t text --watch cliphist-store-filtered -max-items 100"
      "wl-paste -t image --watch cliphist-store-filtered -max-items 100"
    ];

    # Routed via Hyprland's `global` dispatcher to the running quickshell.
    # ~125ms faster than `qs ipc call` (cold-start avoidance).
    # Selecting an entry copies it to the clipboard and pastes via Ctrl+Shift+V.
    bind = [
      "SUPER, V, exec, hyprctl dispatch global quickshell:clipboard"
    ];

    layerrule = [
      "blur on, match:namespace quickshell-clipboard"
      "ignore_alpha 0.01, match:namespace quickshell-clipboard"
      "no_anim on, match:namespace quickshell-clipboard"
    ];
  };
}
