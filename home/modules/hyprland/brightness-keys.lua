-- Only these keys change brightness, and brightnessctl emits no change event.
-- Notify is load-bearing: without it the OSD must poll. See osd/BrightnessOsd.qml.
--
-- `hyprctl dispatch global` reaches the resident quickshell.
-- `qs ipc call brightness show` cold-starts a Qt binary per keypress (~125ms),
-- and the OSD waits behind it.
-- `global` from a bind never reaches the client, so it goes through exec.
-- Same workaround as app-launcher.lua.
-- `hyprctl dispatch` argument is a Lua expression, not hyprlang words.
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd([[brightnessctl set +10% && hyprctl dispatch 'hl.dsp.global("quickshell:brightness")']]))
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd([[brightnessctl set 10%- && hyprctl dispatch 'hl.dsp.global("quickshell:brightness")']]))
