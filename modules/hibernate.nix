{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.system.hibernate;
in
{
  options.system.hibernate = {
    enable = lib.mkEnableOption "hibernate support with lid close action";

    swapFile = {
      path = lib.mkOption {
        type = lib.types.str;
        default = "/swapfile";
        description = "Path to the swap file for hibernation";
      };

      resumeDevice = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Block device containing the swap file (e.g. /dev/disk/by-uuid/XXXX). Leave null on first boot to create the swap file first, then set after reading the UUID.";
      };

      size = lib.mkOption {
        type = lib.types.int;
        default = 32;
        description = "Size of the swap file in GB (should be >= RAM size)";
      };

      resumeOffset = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        description = "Resume offset for the swap file (get with: filefrag -v /swapfile)";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # Create swap file
    swapDevices = [
      {
        device = cfg.swapFile.path;
        size = cfg.swapFile.size * 1024;
      }
    ];

    # Add resume kernel parameters
    boot.kernelParams = lib.optionals (cfg.swapFile.resumeOffset != null) [
      "resume_offset=${toString cfg.swapFile.resumeOffset}"
    ];

    # Set resume device (generates the resume= kernel parameter)
    boot.resumeDevice = lib.mkIf (cfg.swapFile.resumeOffset != null && cfg.swapFile.resumeDevice != null) cfg.swapFile.resumeDevice;

    # Hibernation copies in-use RAM into a snapshot held in RAM, which needs free
    # pages to copy into. The default image_size (~2/5 of RAM) pre-frees too
    # little under memory pressure, so the copy fails with "Error -12 creating
    # image" and the machine silently wakes. 0 = pre-free maximally so it always
    # fits, at the cost of a few extra seconds of swap-out.
    systemd.tmpfiles.rules = [ "w /sys/power/image_size - - - - 0" ];

    # Hibernate on lid close (ignore when docked to keep external monitors on)
    services.logind.settings.Login = {
      HandleLidSwitch = "hibernate";
      HandleLidSwitchDocked = "ignore";
      HandleLidSwitchExternalPower = "hibernate";
    };
  };
}
