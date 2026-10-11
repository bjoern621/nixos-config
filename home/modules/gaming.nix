{ pkgs, ... }:

# Note: Steam, gamemode and the kernel live in modules/gaming.nix.
{
  home.packages = with pkgs; [
    heroic
    lutris
    prismlauncher
  ];
}
