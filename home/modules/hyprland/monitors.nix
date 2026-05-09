{ ... }:

{
  wayland.windowManager.hyprland.settings = {
    # https://wiki.hypr.land/Configuring/Monitors/
    monitor = [
      "eDP-1, 2944x1840@90, 0x0, 2"
      # 1440p144 works because services.amdgpuForceHbr3 forces HBR3
      # link training on every DP hotplug event, bypassing the broken
      # DPIA AUX cap probe through the CalDigit TS5 Plus dock.
      "desc:LG Electronics LG ULTRAGEAR 308MAPN9YD64,2560x1440@144,1472x0,1"
      "desc:LG Electronics LG ULTRAGEAR 308MAVD9YD63,2560x1440@144,4032x0,1"
      ",preferred,auto,1"
    ];

    # Disable internal display when lid closed, re-enable when opened
    bindl = [
      ", switch:on:Lid Switch, exec, hyprctl keyword monitor eDP-1, disable"
      ", switch:off:Lid Switch, exec, hyprctl keyword monitor eDP-1, 2944x1840@90, 0x0, 2"
    ];
  };
}
