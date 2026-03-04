{ ... }:

{
  # System-level dependencies for quickshell.
  # NOTE: This module is paired with home/modules/quickshell/quickshell.nix
  # which contains the user-level quickshell configuration.

  # UPower D-Bus service for battery information (used by quickshell's UPower integration)
  services.upower.enable = true;
}
