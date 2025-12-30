{ ... }:

{
    # https://wiki.hypr.land/Configuring/Monitors/
    monitor = eDP-1, disable
    #monitor = eDP-1, 2944x1840@90, 0x0, 2, bitdepth, 10, cm, wide, disable
    monitor = desc:LG Electronics LG ULTRAGEAR 308MAPN9YD64, 2560x1440@144, 1472x0, 1, disable # Left side LG monitor
    monitor = desc:LG Electronics LG ULTRAGEAR 308MAVD9YD63, 2560x1440@144, 4032x0, 1 # Right side LG monitor
    monitor = , preferred, auto, 1 # Fallback
}