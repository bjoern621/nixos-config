-- Watch for new clipboard content and store it in the history.
hl.on("hyprland.start", function()
    hl.exec_cmd("wl-paste -t text --watch cliphist -max-items 100 store")
    hl.exec_cmd("wl-paste -t image --watch cliphist -max-items 100 store")
end)

-- Routed via Hyprland's `global` dispatcher to the running quickshell.
-- ~125ms faster than `qs ipc call` (cold-start avoidance).
-- Selecting an entry copies it to the clipboard and pastes via Ctrl+Shift+V.
-- `hyprctl dispatch` argument is a Lua expression, not hyprlang words.
hl.bind("SUPER + V", hl.dsp.exec_cmd([[hyprctl dispatch 'hl.dsp.global("quickshell:clipboard")']]))

hl.layer_rule({
    match = { namespace = "quickshell-clipboard" },
    blur = true,
    ignore_alpha = 0.01,
    no_anim = true,
})
