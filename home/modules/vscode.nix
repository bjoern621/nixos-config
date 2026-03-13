{ pkgs, ... }:

{
  programs.vscode.enable = true;

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

  # Needed by Claude Code Vscode Extension.
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    stdenv.cc.cc.lib
    zlib
    zlib.dev
    fuse3
    icu
    nss
    openssl
    curl
    expat
  ];
}
