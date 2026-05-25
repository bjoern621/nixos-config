{ pkgs, ... }:

let
  sysconf-fix-monitors = pkgs.writeShellScriptBin "sysconf-fix-monitors" ''
    # Workaround for a Hyprland 0.55.0 mixed-scale coordinate bug.
    # When eDP-1 runs at scale=2 alongside scale=1 externals, internal
    # coordinate translation gets latched into a bad state, producing:
    #   - layer-shell surfaces on eDP-1 rendering with a small y-offset
    #     from the screen edge (Quickshell bar top-edge trigger fails)
    #   - an invisible cursor wall in the right half of the monitor
    #     immediately to the right of eDP-1 (DP-7 here, at x=2752)
    # Toggling eDP-1 scale 2 -> 1 -> 2 forces Hyprland to recompute the
    # translation and the bad state clears until the next latch event
    # (boot, lid open/close, monitor hotplug, suspend resume).
    set -euo pipefail

    hyprctl --batch "\
      keyword monitor eDP-1,2944x1840@90,0x0,1 ; \
      keyword monitor desc:LG Electronics LG ULTRAGEAR 308MAPN9YD64,2560x1440@144,2944x0,1 ; \
      keyword monitor desc:LG Electronics LG ULTRAGEAR 308MAVD9YD63,2560x1440@144,5504x0,1" > /dev/null

    hyprctl --batch "\
      keyword monitor eDP-1,2944x1840@90,0x0,2 ; \
      keyword monitor desc:LG Electronics LG ULTRAGEAR 308MAPN9YD64,2560x1440@144,1472x0,1 ; \
      keyword monitor desc:LG Electronics LG ULTRAGEAR 308MAVD9YD63,2560x1440@144,4032x0,1" > /dev/null

    echo "Monitors re-applied. Cursor wall and bar offset should be cleared."
  '';
in
{
  environment.systemPackages = [ sysconf-fix-monitors ];
}
