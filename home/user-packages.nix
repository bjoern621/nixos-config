{ pkgs, ... }:

{
  home.packages = with pkgs; [
    firefox
    kdePackages.kate
    mpv
    gimp
    go
    go-task
    buf
    gcc
  ];
}
