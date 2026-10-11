{ pkgs, ... }:

# Note: the launchers live in home/modules/gaming.nix.
{
  programs.steam = {
    enable = true;
    extraCompatPackages = [ pkgs.proton-ge-bin ];
  };

  programs.gamemode.enable = true;

  # Proton takes NT synchronisation from /dev/ntsync when the kernel offers it.
  # The stock nixpkgs kernel leaves NTSYNC out; zen builds it in.
  boot.kernelPackages = pkgs.linuxPackages_zen;
}
