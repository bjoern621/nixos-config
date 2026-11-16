{
  config,
  lib,
  pkgs,
  ...
}:

# Windows sits on its own disk with its own ESP, and lanzaboote carries no entry for it.
# BootNext points the firmware at the Windows Boot Manager for one boot, then the default returns.
let
  rebootToWindows = pkgs.writeShellApplication {
    name = "reboot-to-windows";
    runtimeInputs = [
      pkgs.efibootmgr
      pkgs.gnused
      pkgs.systemd
    ];
    text = ''
      entry=$(efibootmgr | sed -n 's/^Boot\([0-9A-Fa-f]\{4\}\)\*\? *Windows Boot Manager.*/\1/p' | head -n 1)
      if [ -z "$entry" ]; then
        echo "The firmware boot list holds no Windows Boot Manager entry. Check it with efibootmgr." >&2
        exit 1
      fi
      efibootmgr --quiet --bootnext "$entry"
      systemctl reboot
    '';
  };
  rebootToWindowsEntry = pkgs.makeDesktopItem {
    name = "reboot-to-windows";
    desktopName = "In Windows neu starten";
    comment = "Startet einmal Windows, danach wieder NixOS";
    exec = "systemctl start --no-block reboot-to-windows.service";
    icon = "distributor-logo-windows";
    categories = [ "System" ];
    keywords = [
      "windows"
      "reboot"
      "neustart"
      "dualboot"
    ];
  };
in
{
  environment.systemPackages = [ rebootToWindowsEntry ];

  systemd.services.reboot-to-windows = {
    description = "Reboot into Windows once";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = lib.getExe rebootToWindows;
    };
  };

  # Writing BootNext needs root.
  # Launcher starts unit as user.
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (action.id == "org.freedesktop.systemd1.manage-units" &&
          action.lookup("unit") == "reboot-to-windows.service" &&
          subject.user == "${config.sysconf.user}") {
        return polkit.Result.YES;
      }
    });
  '';
}
