{ pkgs, ... }:

{
  home.packages = with pkgs; [
    firefox
    kdePackages.kate
    mpv
    gimp
  ];
}
