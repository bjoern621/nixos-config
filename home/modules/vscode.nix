{ pkgs, ... }:

{
  programs.vscode.enable = true;

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
