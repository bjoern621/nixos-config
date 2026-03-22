{ pkgs, lib, ... }:

let
  settingsFile = "$HOME/.config/Code/User/settings.json";
in
{
  programs.vscode.enable = true;

  home.activation.vscodeSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    settings="${settingsFile}"

    if [ -L "$settings" ]; then
      rm "$settings"
    fi

    mkdir -p "$(dirname "$settings")"

    if [ ! -f "$settings" ]; then
      echo '{}' > "$settings"
    fi

    # Ensure "update.mode" is present; if not, inject before closing brace
    if ! ${pkgs.gnugrep}/bin/grep -q '"update.mode"' "$settings"; then
      ${pkgs.gnused}/bin/sed -i 's/}$/    "update.mode": "none"\n}/' "$settings"
    fi

    # Exclude update.mode from Settings Sync so it stays machine-local
    if ! ${pkgs.gnused}/bin/sed -n '/"settingsSync.ignoredSettings"/,/]/p' "$settings" | ${pkgs.gnugrep}/bin/grep -q '"update.mode"'; then
      if ${pkgs.gnugrep}/bin/grep -q '"settingsSync.ignoredSettings"' "$settings"; then
        # Array exists — append entry before the closing bracket
        ${pkgs.gnused}/bin/sed -i '/"settingsSync.ignoredSettings"/,/]/{
          s/]/        "update.mode"\n    ]/
        }' "$settings"
      else
        # Array doesn't exist — create it
        ${pkgs.gnused}/bin/sed -i 's/}$/    "settingsSync.ignoredSettings": ["update.mode"]\n}/' "$settings"
      fi
    fi
  '';

  xdg.desktopEntries."code" = {
    name = "Visual Studio Code";
    genericName = "Text Editor";
    exec = "code --password-store=\"gnome-libsecret\"";
    terminal = false;
    icon = "vscode";
    categories = [
      "Development"
      "IDE"
    ];
    type = "Application";
  };
}
