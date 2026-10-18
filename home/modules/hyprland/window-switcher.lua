-- Alt+Tab window switcher shown by quickshell (windows/WindowSwitcher.qml).
-- `global` runs in-process: Hyprland sends shortcut events to quickshell in key order.
-- Separate `hyprctl dispatch` processes race, and a fast Alt release then lands before its Alt+Tab.
local function qs(name)
    return hl.dsp.global("quickshell:" .. name)
end

-- xkb keycodes, layout-independent.
local KEY_ALT_L = 64
local KEY_TAB = 23

local held = {}
local switching = false

local function finish(name)
    switching = false
    hl.dispatch(qs(name))
    hl.dispatch(hl.dsp.submap("reset"))
end

-- `global` in a bind re-runs that bind on key release.
-- Tab check drops the re-run: after a fast Alt release it would reopen submap.
local function step(name)
    return function()
        if not held[KEY_TAB] then
            return
        end
        switching = true
        hl.dispatch(qs(name))
        hl.dispatch(hl.dsp.submap("alttab"))
    end
end

hl.bind("ALT + Tab", step("alttab-next"))
hl.bind("ALT + SHIFT + Tab", step("alttab-prev"))

-- Escape lives only in submap, so apps keep Alt+Escape outside a switch.
-- Same Tab binds inside: Tab during switch keeps stepping.
hl.define_submap("alttab", function()
    hl.bind("ALT + Tab", step("alttab-next"))
    hl.bind("ALT + SHIFT + Tab", step("alttab-prev"))
    hl.bind("escape", function()
        finish("alttab-cancel")
    end, { ignore_mods = true })
end)

-- Alt release commits selection.
-- Hyprland drops an `ALT + Alt_L` release bind while Tab still held,
-- the usual order for a fast Alt+Tab tap.
-- Key listener sees every key event before bind matching and leaves it to the client.
hl.on("input.keyboard.key", function(code, _, state)
    held[code] = state == 1 or nil
    if code == KEY_ALT_L and state == 0 and switching then
        finish("alttab-commit")
    end
end)
