-- Alt+Tab window switcher shown by quickshell (windows/WindowSwitcher.qml).
-- Routed via exec + `hyprctl dispatch`: `global` dispatcher from keybind never reaches quickshell.
-- `hyprctl dispatch` argument is a Lua expression, not hyprlang words.
local function qs(name)
    return hl.dsp.exec_cmd([[hyprctl dispatch 'hl.dsp.global("quickshell:]] .. name .. [[")']])
end

-- Global map starts a switch.
-- Quickshell then enters submap `alttab` and resets it on close.
hl.bind("ALT + Tab", qs("alttab-next"))
hl.bind("ALT + SHIFT + Tab", qs("alttab-prev"))

-- Escape lives only in submap, so apps keep Alt+Escape outside a switch.
-- Same Tab binds inside: Tab during switch keeps stepping.
-- Reset here too, not only in quickshell: crashed shell must not strand keys in submap.
hl.define_submap("alttab", function()
    hl.bind("ALT + Tab", qs("alttab-next"))
    hl.bind("ALT + SHIFT + Tab", qs("alttab-prev"))
    hl.bind("escape", function()
        hl.dispatch(qs("alttab-cancel"))
        hl.dispatch(hl.dsp.submap("reset"))
    end, { ignore_mods = true })
end)

-- Alt release commits selection.
-- submap_universal: fires in global map (quick tap before submap entered) and in `alttab`.
-- transparent: Tab release during hold would otherwise shadow release bind (hyprwm/Hyprland#15904).
-- non_consuming: client still sees Alt release, so no stuck modifier and Firefox menu-bar tap keeps working.
-- ignore_mods: still fires while Shift held from Alt+Shift+Tab.
-- Fires on every Alt release; quickshell ignores it outside a switch, reset is a no-op in global map.
hl.bind("ALT + Alt_L", function()
    hl.dispatch(qs("alttab-commit"))
    hl.dispatch(hl.dsp.submap("reset"))
end, {
    release = true,
    transparent = true,
    non_consuming = true,
    ignore_mods = true,
    submap_universal = true,
})
