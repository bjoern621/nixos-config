{ pkgs, ... }:

{
  home.packages = with pkgs; [
    firefox
    kdePackages.kate
    mpv
    gimp
    obsidian
    python3
    feh
  ];
}
