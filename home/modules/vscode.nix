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
  '';

  xdg.desktopEntries."code" = {
    name = "Visual Studio Code";
    genericName = "Text Editor";
    comment = "Code Editing. Redefined.";
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
