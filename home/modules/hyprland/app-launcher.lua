-- Workaround: `hl.bind("SUPER + Super_L", hl.dsp.global("quickshell:launcher"))`
-- registers in Hyprland and fires reliably, but the `global` dispatcher invoked
-- from a keybind does not reach the quickshell client (while `hyprctl dispatch`
-- does). Routing through exec works.
-- `hyprctl dispatch` argument is a Lua expression, not hyprlang words.
hl.bind("SUPER + Super_L", hl.dsp.exec_cmd([[hyprctl dispatch 'hl.dsp.global("quickshell:launcher")']]))

hl.layer_rule({
    match = { namespace = "quickshell-launcher" },
    blur = true,
    ignore_alpha = 0.01,
    no_anim = true,
})
