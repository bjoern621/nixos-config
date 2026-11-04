{
  # Read by HostFeatures.qml.
  # Shows battery pill, its menu and low-battery warnings.
  systemd.user.services.quickshell.Service.Environment = [ "QUICKSHELL_HAS_BATTERY=true" ];
}
