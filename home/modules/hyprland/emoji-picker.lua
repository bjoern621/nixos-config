-- Emoji picker (Super+.) shown by quickshell.
-- Routed via Hyprland's `global` dispatcher to the running quickshell.
-- Selecting an emoji copies it to the clipboard and pastes via Ctrl+Shift+V.
-- `hyprctl dispatch` argument is a Lua expression, not hyprlang words.
hl.bind("SUPER + period", hl.dsp.exec_cmd([[hyprctl dispatch 'hl.dsp.global("quickshell:emoji")']]))

hl.layer_rule({
    match = { namespace = "quickshell-emoji" },
    blur = true,
    ignore_alpha = 0.01,
    no_anim = true,
})
