{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    alacritty
    foot
    wezterm
    gnome-terminal
    konsole
  ];
}
