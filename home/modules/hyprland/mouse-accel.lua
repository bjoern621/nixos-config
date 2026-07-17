hl.config({
    input = {
        accel_profile = "flat", -- No mouse acceleration globally.
    },
})

-- Touchpad keeps acceleration.
-- https://wiki.hypr.land/Configuring/Advanced-and-Cool/Devices/
hl.device({
    name = "syna2ba6:00-06cb:cf00-touchpad",
    accel_profile = "adaptive",
})
