{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    gnome-keyring
    seahorse
  ];
}
