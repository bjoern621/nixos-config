-- https://wiki.hypr.land/Configuring/Basics/Binds/
local mainMod = "SUPER"
local terminal = "alacritty"

-- Application shortcuts
hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + W", hl.dsp.window.close())
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen_state({ internal = 2, client = 0, action = "toggle" }))
-- uwsm session: `exit` dispatcher pulls Hyprland out from under its clients.
-- `uwsm stop` brings the graphical session down in order.
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("uwsm stop"))
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("loginctl lock-session"))

-- Move focus with mainMod + arrow keys
hl.bind(mainMod .. " + left", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down", hl.dsp.focus({ direction = "down" }))

-- Move current workspace to another monitor (cycles between monitors)
hl.bind(mainMod .. " + SHIFT + left", hl.dsp.workspace.move({ monitor = "-1" }))
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.workspace.move({ monitor = "+1" }))

-- Switch workspaces with mainMod + [0-9].
-- Move active window to a workspace with mainMod + SHIFT + [0-9].
for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0.
    hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i, follow = true }))
end

-- Alt + Arrow keys -> Home/End/PageUp/PageDown.
-- window omitted -> active window.
hl.bind("ALT + left", hl.dsp.send_shortcut({ mods = "", key = "home" }))
hl.bind("ALT + right", hl.dsp.send_shortcut({ mods = "", key = "end" }))
hl.bind("ALT + up", hl.dsp.send_shortcut({ mods = "", key = "page_up" }))
hl.bind("ALT + down", hl.dsp.send_shortcut({ mods = "", key = "page_down" }))

-- Mouse buttons:
-- LMB -> 272, RMB -> 273, MMB -> 274, extra MB -> 275, 276, ...
hl.config({
    binds = {
        drag_threshold = 10, -- Fire a drag event only after dragging for more than 10px.
    },
})

-- Drag binds (old bindm): move/resize windows by dragging.
hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true, drag = true })
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true, drag = true })
hl.bind("mouse:276", hl.dsp.window.drag(), { mouse = true, drag = true })
hl.bind("mouse:275", hl.dsp.window.resize(), { mouse = true, drag = true })

-- Click binds (old bindc): press and release without crossing drag_threshold.
hl.bind("SUPER + mouse:272", hl.dsp.window.float({ action = "toggle" }), { mouse = true, click = true })
hl.bind("mouse:276", hl.dsp.window.float({ action = "toggle" }), { mouse = true, click = true })
