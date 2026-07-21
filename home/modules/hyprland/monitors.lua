-- https://wiki.hypr.land/Configuring/Basics/Monitors/
-- Docked layout: the externals form a row along the top, the internal
-- display sits centered beneath them. eDP-1 is 1472 logical wide
-- (2944 at scale 2) and the externals span 5120, so centering it puts
-- its origin at 2560 - 736 = 1824.
hl.monitor({ output = "eDP-1", mode = "2944x1840@90", position = "1824x1440", scale = 2 })
-- 1440p144 works because services.amdgpuForceHbr3 forces HBR3
-- link training on every DP hotplug event, bypassing the broken
-- DPIA AUX cap probe through the CalDigit TS5 Plus dock.
hl.monitor({ output = "desc:LG Electronics LG ULTRAGEAR 308MAPN9YD64", mode = "2560x1440@144", position = "0x0", scale = 1 })
hl.monitor({ output = "desc:LG Electronics LG ULTRAGEAR 308MAVD9YD63", mode = "2560x1440@144", position = "2560x0", scale = 1 })
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

-- Disable the internal display on lid close only while an external monitor
-- is connected (docked case, where logind ignores the lid). Undocked, the
-- lid close triggers suspend-then-hibernate (modules/hibernate.nix), and
-- tearing down eDP-1 concurrently with the hibernation snapshot leaves
-- amdgpu in an inconsistent state that corrupts the image. The monitor
-- count includes eDP-1 itself, so > 1 means externals are present.
--
-- The guard uses `test`, not `[ ... ]`: Hyprland parses a leading `[` in an
-- exec command as a window-rule prefix and strips it, which would leave the
-- shell with a dangling `&& ...` and silently skip the disable.
--
-- `hyprctl keyword monitor` is dead under the Lua parser ("keyword can't work
-- with non-legacy parsers. Use eval."). Runtime monitor changes go through
-- `hyprctl eval` with the hl.monitor API instead. Re-enable must pass
-- `disabled = false` explicitly; setting mode/position alone leaves the
-- disabled flag latched.
hl.bind(
    "switch:on:Lid Switch",
    hl.dsp.exec_cmd([[test "$(hyprctl monitors | grep -c '^Monitor ')" -gt 1 && hyprctl eval 'hl.monitor({ output = "eDP-1", disabled = true })']]),
    { locked = true }
)
hl.bind(
    "switch:off:Lid Switch",
    hl.dsp.exec_cmd([[hyprctl eval 'hl.monitor({ output = "eDP-1", mode = "2944x1840@90", position = "1824x1440", scale = 2, disabled = false })']]),
    { locked = true }
)
