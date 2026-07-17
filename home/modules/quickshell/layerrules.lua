-- ignore_alpha skips blur at or below the threshold, so the transparent
-- PanelWindow background stays unblurred and only the pill blurs.
-- A pill slid off-screen is clipped, leaving transparent background, so blur
-- disappears with no extra logic.
--
-- no_anim stops Hyprland animating the layer surface.
-- Bar resizes 1px <-> 1000px on hover, and Hyprland stretches the client buffer
-- into the still-animating box, distorting the pill for a few frames under load.
-- Quickshell animates its own show/hide in QML.
hl.layer_rule({
    match = { namespace = "quickshell" },
    blur = true,
    ignore_alpha = 0.01,
    no_anim = true,
})
