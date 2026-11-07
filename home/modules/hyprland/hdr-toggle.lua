-- https://wiki.hypr.land/Configuring/Variables/#render
-- Default 1 switches monitor to hdr preset when fullscreen client requests HDR (Chrome video).
-- Switch is a modeset and blacks out screen.
-- HDR stays manual via hdr-toggle.
hl.config({
    render = {
        cm_auto_hdr = 0,
    },
})
