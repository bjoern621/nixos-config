# The gaming desktop itself: identity, disks, boot.
#
# Imported by the running system and by the bootstrap config, so both agree on how the
# machine boots and mounts.
#
# Windows owns the other NVMe disk together with its own ESP; this file never touches it
# apart from the games partition Windows left unallocated.

{ inputs, ... }:

{
  imports = [
    inputs.disko.nixosModules.disko
    ./disko.nix
  ];

  networking.hostName = "fractal";
  nixpkgs.hostPlatform = "x86_64-linux";

  # UEFI with the firmware boot menu choosing the disk.
  # The full system swaps systemd-boot for lanzaboote (modules/secureboot.nix);
  # the bootstrap boots unsigned with Secure Boot still off.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # LUKS volume on the Windows disk, created by hand (docs/fractal.md) with partlabel `games`.
  # The key file lives on the encrypted root, so the volume opens after root with no prompt.
  environment.etc.crypttab.text = ''
    games /dev/disk/by-partlabel/games /etc/luks/games.key luks,discard,nofail
  '';
  fileSystems."/games" = {
    device = "/dev/mapper/games";
    fsType = "ext4";
    options = [
      "nofail"
      "x-systemd.device-timeout=10s"
    ];
  };

  system.stateVersion = "26.11";
}
