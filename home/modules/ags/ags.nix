{ inputs, pkgs, ... }:

{
  # https://aylur.github.io/ags/guide/nix.html#using-home-manager

  # add the home manager module
  imports = [ inputs.ags.homeManagerModules.default ];

  programs.ags = {
    enable = true;

    # symlink to ~/.config/ags
    configDir = ./.;

    # additional packages and executables to add to gjs's runtime
      #inputs.astal.packages.${pkgs.system}.battery
    extraPackages = with pkgs; [
      fzf
    ];
  };
}