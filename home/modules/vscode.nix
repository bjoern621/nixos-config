{ pkgs, ... }:

{
  programs.vscode.enable = true;

  programs.vscode.profiles.default.extensions = with pkgs.vscode-extensions; [
    anthropic.claude-code
  ];

  xdg.desktopEntries."code" = {
    name = "Visual Studio Code";
    genericName = "Text Editor";
    comment = "Code Editing. Redefined.";
    exec = "code --password-store=\"gnome-libsecret\" --touch-events %F";
    terminal = false;
    icon = "vscode";
    categories = [
      "Development"
      "IDE"
    ];
    type = "Application";
  };
}
