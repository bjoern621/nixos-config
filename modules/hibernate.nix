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
        type = lib.types.str;
        description = "Block device containing the swap file (e.g. /dev/disk/by-uuid/XXXX)";
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
    boot.resumeDevice = lib.mkIf (cfg.swapFile.resumeOffset != null) cfg.swapFile.resumeDevice;

    # Hibernate on lid close
    services.logind.settings.Login = {
      HandleLidSwitch = "hibernate";
      HandleLidSwitchDocked = "hibernate";
      HandleLidSwitchExternalPower = "hibernate";
    };
  };
}
