-- Workaround: `hl.bind("SUPER + Super_L", hl.dsp.global("quickshell:launcher"))`
-- registers in Hyprland and fires reliably, but the `global` dispatcher invoked
-- from a keybind does not reach the quickshell client (while `hyprctl dispatch`
-- does). Routing through exec works.
-- `hyprctl dispatch` argument is a Lua expression, not hyprlang words.
--
-- release = true is what a modkey-only bind takes.
-- Without it the bind carries no non-mod key, so Hyprland defers it to the SUPER release
-- and fires it there even when a SUPER + key bind ran during the hold.
-- The release flag instead shadows the bind as soon as another key or button
-- releases while SUPER is held (hyprwm/Hyprland#15904).
hl.bind("SUPER + Super_L", hl.dsp.exec_cmd([[hyprctl dispatch 'hl.dsp.global("quickshell:launcher")']]), { release = true })

-- ignore_alpha skips blur at or below the threshold, so the transparent
-- fullscreen overlay stays unblurred and only the centered card (~0.05 white)
-- frosts.
-- no_anim stops the surface stretching on resize.
hl.layer_rule({
    match = { namespace = "quickshell-launcher" },
    ignore_alpha = 0.01,
    no_anim = true,
})
