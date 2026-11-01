-- Keeps card profiles routing to hidden displays unselected.
-- GPU HDMI controller offers one display port per profile.
-- Disabling whole controller would hide every other display on it.
-- Display name comes from HDMI ELD, route info key `device.product.name`.

cutils = require ("common-utils")
putils = require ("profile-utils")
log = Log.open_topic ("s-device")

-- Monitor speakers unused.
local hiddenDisplays = {
  ["LG ULTRAGEAR"] = true,
}

-- Route info: entry count, then key/value pairs.
local function displayName (route)
  local info = route.info or {}
  for i = 2, #info - 1, 2 do
    if info [i] == "device.product.name" then
      return info [i + 1]
    end
  end
  return nil
end

-- Profile counts as hidden once every connected output it offers is hidden.
local function hiddenProfileIndices (routes)
  local hidden = {}
  local shown = {}
  for _, route in ipairs (routes) do
    if route.direction == "Output" and route.available == "yes" and route.profiles then
      local target = hiddenDisplays [displayName (route) or ""] and hidden or shown
      for _, index in ipairs (route.profiles) do
        target [tonumber (index)] = true
      end
    end
  end
  for index in pairs (shown) do
    hidden [index] = nil
  end
  return hidden
end

SimpleEventHook {
  name = "device/skip-hidden-display-profile",
  after = "device/find-best-profile",
  before = "device/apply-profile",
  interests = {
    EventInterest {
      Constraint { "event.type", "=", "select-profile" },
    },
  },
  execute = function (event)
    local selected = event:get_data ("selected-profile")
    if not selected then
      return
    end

    local device = event:get_subject ()
    local routes = {}
    for r in device:iterate_params ("EnumRoute") do
      local route = cutils.parseParam (r, "EnumRoute")
      if route then
        table.insert (routes, route)
      end
    end

    local hidden = hiddenProfileIndices (routes)
    if not hidden [tonumber (selected.index)] then
      return
    end

    -- Same ranking as device/find-best-profile, hidden profiles left out.
    local scores = putils.buildOutputRouteScores (routes)
    local best, unknown, off
    for p in device:iterate_params ("EnumProfile") do
      local profile = cutils.parseParam (p, "EnumProfile")
      if not profile or profile.name == "pro-audio" or hidden [tonumber (profile.index)] then
        goto continue
      end
      if profile.name == "off" then
        off = profile
      elseif profile.available == "yes" then
        if best == nil or putils.compareProfiles (profile, best, scores) then
          best = profile
        end
      elseif profile.available ~= "no" then
        if unknown == nil or putils.compareProfiles (profile, unknown, scores) then
          unknown = profile
        end
      end
      ::continue::
    end

    local replacement = best or unknown or off
    if replacement then
      log:info (device, string.format (
          "Profile '%s' feeds hidden display, selecting '%s'",
          selected.name, replacement.name))
      event:set_data ("selected-profile", replacement)
    end
  end
}:register ()
