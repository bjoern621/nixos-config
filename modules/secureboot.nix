{
  pkgs,
  lib,
  inputs,
  ...
}:

# Manual setup needed, see:
# https://nix-community.github.io/lanzaboote/introduction.html
{
  imports = [ inputs.lanzaboote.nixosModules.lanzaboote ];

  environment.systemPackages = [
    # For debugging and troubleshooting Secure Boot.
    pkgs.sbctl
  ];

  # Lanzaboote installs signed systemd-boot itself.
  # NixOS systemd-boot module sets `system.build.installBootLoader` too.
  boot.loader.systemd-boot.enable = lib.mkForce false;

  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/var/lib/sbctl";
    autoGenerateKeys.enable = true;
    autoEnrollKeys = {
      enable = true;
      autoReboot = true;
    };
  };
}
