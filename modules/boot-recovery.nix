{ lib, ... }:

# Way back in when boot hangs before root mounts.
# loader.timeout 0 hides systemd-boot menu; Space held from power-on opens it.
{
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
}
