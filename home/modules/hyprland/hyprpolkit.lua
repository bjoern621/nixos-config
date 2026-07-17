-- https://wiki.hypr.land/Hypr-Ecosystem/hyprpolkitagent/
hl.on("hyprland.start", function()
    hl.exec_cmd("systemctl --user start hyprpolkitagent")
end)
