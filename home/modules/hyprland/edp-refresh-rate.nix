{ pkgs, ... }:

let
  edp-refresh-rate = pkgs.writeShellScriptBin "edp-refresh-rate" ''
    # Sets eDP-1 to 90 Hz on AC, 60 Hz on battery.
    # --watch applies it again on every power_supply uevent.
    # Partial hl.monitor spec latches: position, scale, bitdepth, cm and disabled stay.
    # Rates and ADP0 must match edp_mode() in monitors.lua.
    set -euo pipefail

    apply() {
      if [ "$(cat /sys/class/power_supply/ADP0/online)" = 1 ]; then hz=90; else hz=60; fi
      if [ "$hz" = "''${last:-}" ]; then return; fi
      hyprctl eval "hl.monitor({ output = \"eDP-1\", mode = \"2944x1840@$hz\" })" > /dev/null
      last=$hz
    }

    apply
    if [ "''${1:-}" != --watch ]; then exit 0; fi
    ${pkgs.systemd}/bin/udevadm monitor --udev --subsystem-match=power_supply | while read -r _; do apply; done
  '';
in
{
  home.packages = [ edp-refresh-rate ];

  systemd.user.services.edp-refresh-rate = {
    Unit = {
      Description = "eDP-1 refresh rate by power source";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${edp-refresh-rate}/bin/edp-refresh-rate --watch";
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
