{ lib, ... }:

# Switches a host flake flips on the shared user config.
# Defaults describe the laptop, so hosts/nixos sets none of them.
{
  options.host = {
    sessionLock = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Run the Quickshell session lock and the hypridle hooks that engage it.";
    };

    hibernate = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Offer hibernate in the power menu.";
    };

    usbguard = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Run the USBGuard session policy and prompts; needs modules/usbguard.nix on the host.";
    };

    hidpi = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Apply the Electron scale factors tuned for a scale 2 panel.";
    };
  };
}
