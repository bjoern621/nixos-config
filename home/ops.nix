{ ... }:

{
  imports = [
    ./modules/shell.nix
    ./modules/git.nix
  ];

  home.username = "ops";
  home.homeDirectory = "/home/ops";

  home.stateVersion = "25.11";

  programs.home-manager.enable = true;
}
