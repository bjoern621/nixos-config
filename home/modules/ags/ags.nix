{ inputs, pkgs, ... }:

{
  # https://aylur.github.io/ags/guide/nix.html#using-home-manager

  # add the home manager module
  imports = [ inputs.ags.homeManagerModules.default ];

  programs.ags = {
    enable = true;

    # symlink to ~/.config/ags
    configDir = ../ags;

    # additional packages and executables to add to gjs's runtime
    extraPackages = with pkgs; [
      astal.battery
      astal.powerprofiles
      astal.wireplumber
      astal.network
      astal.tray
      astal.mpris
      astal.apps
      fzf
      networkmanager
    ];
  };

  wayland.windowManager.hyprland.settings.exec-once = [ "ags" ];

  fonts.fontconfig.enable = true;

  home.packages = with pkgs; [
    font-awesome # Icons
    inter # Text
  ];
}