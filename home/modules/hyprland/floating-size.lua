-- Floating windows open at 60% monitor width, 70% height (monitor-local).
-- Windows tagged own-size keep their app-specific size (rules.40-mozza-mail).
-- Window rule cannot do this: size is static, evaluated at open before float
-- effects of other rules land, so match={float=true} never fires.
-- window.open fires after rules are applied.
-- resize dispatcher silently ignores rule expressions and "50%" strings; pass numbers.
-- monitor.size is physical pixels; divide by scale for logical.

local function has_own_size(w)
    if type(w.tags) ~= "table" then return false end
    for _, t in pairs(w.tags) do
        -- Dynamic tags carry a "*" suffix.
        if t == "own-size" or t == "own-size*" then return true end
    end
    return false
end

-- resize dispatcher ignores client size limits.
-- Next client commit clamps to them, window snaps back.
-- Fixed-size window (min == max) keeps its own size.
-- min_size/max_size come from hyprland-lua-window-size-limits.patch. nil without it.
local function clamp_to_client_limits(w, x, y)
    local min, max = w.min_size, w.max_size
    if min then x, y = math.max(x, min.x), math.max(y, min.y) end
    if max then x, y = math.min(x, max.x), math.min(y, max.y) end
    return x, y
end

hl.on("window.open", function(w)
    if w == nil or not w.floating or has_own_size(w) then return end
    local m = w.monitor
    if m == nil then return end
    local x, y = clamp_to_client_limits(w, m.size.width / m.scale * 0.6, m.size.height / m.scale * 0.7)
    hl.dispatch(hl.dsp.window.resize({ x = x, y = y, window = w }))
end)
