-- Spawns once per session (hyprland.start).
-- Old hyprlang `exec` re-ran on every config reload; nm-applet single-instances,
-- so the difference is invisible.
hl.on("hyprland.start", function()
    hl.exec_cmd("nm-applet --indicator")
end)
