hl.bind("SUPER + P", hl.dsp.window.pin())

-- White border marks pinned windows.
hl.window_rule({ match = { pin = true }, border_color = "rgb(ffffff)" })
