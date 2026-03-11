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
        type = lib.types.path;
        default = "/swapfile";
        description = "Path to the swap file for hibernation";
      };

      size = lib.mkOption {
        type = lib.types.int;
        default = 32;
        description = "Size of the swap file in GB (should be >= RAM size)";
      };

      resumeOffset = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        description = "Resume offset for the swap file (get with: bmap #{cfg.swapFile.path})";
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

    # Add resume kernel parameter
    boot.kernelParams = lib.optionals (cfg.swapFile.resumeOffset != null) [
      "resume=${cfg.swapFile.path}"
      "resume_offset=${toString cfg.swapFile.resumeOffset}"
    ];

    # Add resume hook to initrd
    boot.resumeDevice = lib.mkIf (cfg.swapFile.resumeOffset != null) cfg.swapFile.path;

    # Hibernate on lid close
    services.logind = {
      lidSwitch = "hibernate";
      lidSwitchDocked = "hibernate";
      lidSwitchExternalPower = "hibernate";
    };

    # Ensure bmap tool is available for finding resume offset
    environment.systemPackages = [ pkgs.bmap ];
  };
}
