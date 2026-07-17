-- https://wiki.hypr.land/Configuring/Variables/#decoration
hl.config({
    decoration = {
        rounding = 12,
        shadow = {
            enabled = false,
            range = 10,
            render_power = 2,
            color = "0xee1a1a1a",
            color_inactive = "0x221a1a1a",
        },
        blur = {
            enabled = true,
            size = 6,
            passes = 3,
            contrast = 1.0,
            brightness = 1.0,
        },
    },
})
