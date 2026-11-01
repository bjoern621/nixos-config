{ config, lib, ... }:

# Way back in when boot hangs before root mounts.
# loader.timeout 0 hides systemd-boot menu; Space held from power-on opens it.
let
  cfg = config.boot.recovery;
in
{
  options.boot.recovery.emergencyShadowFile = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    example = "/etc/nixos/initrd-shadow";
    description = ''
      Root-only file on the host holding the initrd's `/etc/shadow` line, `root:<yescrypt hash>:::::::`.
      It unlocks the initrd emergency shell with that password.
      The bootloader install fails while the file is missing.
    '';
  };

  config = {
    # Hash stays off public repo: bootloader install appends file to initrd,
    # initrd-nixos-copy-secrets copies it over locked /etc/shadow at sysinit.
    # Shell without password hands out disk: TPM unseals LUKS key for any Secure Boot initrd (PCR 7).
    boot.initrd.secrets = lib.mkIf (cfg.emergencyShadowFile != null) {
      "/etc/shadow" = cfg.emergencyShadowFile;
    };

    # Boot entry with plain text output and USB4 driver off.
    specialisation.rescue.configuration = {
      # Menu title comes from label; untagged entry reads same as default.
      system.nixos.tags = [ "rescue" ];
      boot.plymouth.enable = lib.mkForce false;
      # mkAfter: kernel and systemd take last value, overriding quiet and loglevel=3 from fancy-boot.
      boot.kernelParams = lib.mkAfter [
        "loglevel=7"
        "systemd.show_status=true"
        "rd.systemd.show_status=true"
        # Firmware's dock tunnels survive without driver.
        "module_blacklist=thunderbolt"
        "pcie_port_pm=off"
      ];
    };
  };
}
