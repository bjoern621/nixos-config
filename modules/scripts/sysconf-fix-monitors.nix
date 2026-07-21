{ pkgs, ... }:

let
  sysconf-fix-monitors = pkgs.writeShellScriptBin "sysconf-fix-monitors" ''
    # Workaround for a Hyprland 0.55.0 mixed-scale coordinate bug.
    # When eDP-1 runs at scale=2 alongside scale=1 externals, internal
    # coordinate translation gets latched into a bad state, producing:
    #   - layer-shell surfaces on eDP-1 rendering with a small y-offset
    #     from the screen edge (Quickshell bar top-edge trigger fails)
    #   - an invisible cursor wall in the right half of an adjacent monitor
    # Toggling eDP-1 scale 2 -> 1 -> 2 forces Hyprland to recompute the
    # translation and the bad state clears until the next latch event
    # (boot, lid open/close, monitor hotplug, suspend resume).
    #
    # Positions must match home/modules/hyprland/monitors.lua: externals in a
    # row at the top, eDP-1 centered below. The intermediate scale-1 pass uses
    # x=1088 because eDP-1 is 2944 logical wide at that scale (2560 - 1472).
    #
    # Runtime monitor changes go through `hyprctl eval` + hl.monitor. `hyprctl
    # keyword monitor` is dead under the Lua parser ("keyword can't work with
    # non-legacy parsers. Use eval."). Two separate eval passes preserve the
    # scale 2 -> 1 -> 2 toggle that forces the recompute.
    set -euo pipefail

    hyprctl eval 'hl.monitor({ output = "eDP-1", mode = "2944x1840@90", position = "1088x1440", scale = 1 }); hl.monitor({ output = "desc:LG Electronics LG ULTRAGEAR 308MAPN9YD64", mode = "2560x1440@144", position = "0x0", scale = 1 }); hl.monitor({ output = "desc:LG Electronics LG ULTRAGEAR 308MAVD9YD63", mode = "2560x1440@144", position = "2560x0", scale = 1 })' > /dev/null

    hyprctl eval 'hl.monitor({ output = "eDP-1", mode = "2944x1840@90", position = "1824x1440", scale = 2 }); hl.monitor({ output = "desc:LG Electronics LG ULTRAGEAR 308MAPN9YD64", mode = "2560x1440@144", position = "0x0", scale = 1 }); hl.monitor({ output = "desc:LG Electronics LG ULTRAGEAR 308MAVD9YD63", mode = "2560x1440@144", position = "2560x0", scale = 1 })' > /dev/null

    echo "Monitors re-applied. Cursor wall and bar offset should be cleared."
  '';
in
{
  environment.systemPackages = [ sysconf-fix-monitors ];
}
