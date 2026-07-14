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

    # Disable the internal display on lid close only while an external monitor
    # is connected (docked case, where logind ignores the lid). Undocked, the
    # lid close triggers suspend-then-hibernate (modules/hibernate.nix), and
    # tearing down eDP-1 concurrently with the hibernation snapshot leaves
    # amdgpu in an inconsistent state that corrupts the image. The monitor
    # count includes eDP-1 itself, so > 1 means externals are present.
    #
    # The guard uses `test`, not `[ ... ]`: Hyprland parses a leading `[` in an
    # exec command as a window-rule prefix and strips it, which would leave the
    # shell with a dangling `&& ...` and silently skip the disable.
    bindl = [
      ", switch:on:Lid Switch, exec, test \"$(hyprctl monitors | grep -c '^Monitor ')\" -gt 1 && hyprctl keyword monitor \"eDP-1, disable\""
      ", switch:off:Lid Switch, exec, hyprctl keyword monitor eDP-1, 2944x1840@90, 0x0, 2"
    ];
  };
}
