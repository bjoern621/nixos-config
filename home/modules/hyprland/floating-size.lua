-- Floating windows open at 50% monitor width, 60% height (monitor-local).
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

hl.on("window.open", function(w)
    if w == nil or not w.floating or has_own_size(w) then return end
    local m = w.monitor
    if m == nil then return end
    hl.dispatch(hl.dsp.window.resize({
        x = m.size.width / m.scale * 0.5,
        y = m.size.height / m.scale * 0.6,
        window = w,
    }))
end)
