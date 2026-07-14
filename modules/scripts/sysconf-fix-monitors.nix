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
    # Positions must match home/modules/hyprland/monitors.nix: externals in a
    # row at the top, eDP-1 centered below. The intermediate scale-1 pass uses
    # x=1088 because eDP-1 is 2944 logical wide at that scale (2560 - 1472).
    set -euo pipefail

    hyprctl --batch "\
      keyword monitor eDP-1,2944x1840@90,1088x1440,1 ; \
      keyword monitor desc:LG Electronics LG ULTRAGEAR 308MAPN9YD64,2560x1440@144,0x0,1 ; \
      keyword monitor desc:LG Electronics LG ULTRAGEAR 308MAVD9YD63,2560x1440@144,2560x0,1" > /dev/null

    hyprctl --batch "\
      keyword monitor eDP-1,2944x1840@90,1824x1440,2 ; \
      keyword monitor desc:LG Electronics LG ULTRAGEAR 308MAPN9YD64,2560x1440@144,0x0,1 ; \
      keyword monitor desc:LG Electronics LG ULTRAGEAR 308MAVD9YD63,2560x1440@144,2560x0,1" > /dev/null

    echo "Monitors re-applied. Cursor wall and bar offset should be cleared."
  '';
in
{
  environment.systemPackages = [ sysconf-fix-monitors ];
}
