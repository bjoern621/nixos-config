-- Mozza Mail dev window: workspace 5, floating, near-fullscreen.
hl.window_rule({
    match = { class = "(electron)" },
    workspace = "5 silent",
    float = true,
    -- own-size: floating-size.lua's default-size handler skips tagged windows.
    tag = "+own-size",
    size = { "(monitor_w*0.85)", "(monitor_h*0.85)" },
    move = { "(monitor_w*0.076)", "(monitor_h*0.076)" },
})
