{ ... }:

{
  wayland.windowManager.hyprland.settings = {
    # https://wiki.hypr.land/Configuring/Monitors/
    monitor = [
      "eDP-1, 2944x1840@90, 0x0, 2"
      # 75Hz keeps each stream under HBR (~8.64 Gbps) so DP tunneling
      # over the TS5 Plus stays stable even when DPIA AUX cap probe
      # fails and the link trains down to HBR instead of HBR2/HBR3.
      "desc:LG Electronics LG ULTRAGEAR 308MAPN9YD64,2560x1440@75,1472x0,1"
      "desc:LG Electronics LG ULTRAGEAR 308MAVD9YD63,2560x1440@75,4032x0,1"
      ",preferred,auto,1"
    ];

    # Disable internal display when lid closed, re-enable when opened
    bindl = [
      ", switch:on:Lid Switch, exec, hyprctl keyword monitor eDP-1, disable"
      ", switch:off:Lid Switch, exec, hyprctl keyword monitor eDP-1, 2944x1840@90, 0x0, 2"
    ];
  };
}
