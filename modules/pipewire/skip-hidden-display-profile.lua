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

local function collectRoutes (device)
  local routes = {}
  for r in device:iterate_params ("EnumRoute") do
    local route = cutils.parseParam (r, "EnumRoute")
    if route then
      table.insert (routes, route)
    end
  end
  return routes
end

local function connectedOutputs (routes)
  local outputs = {}
  for _, route in ipairs (routes) do
    if route.direction == "Output" and route.available == "yes" and route.profiles then
      table.insert (outputs, route)
    end
  end
  return outputs
end

local function routeFeedsProfile (route, index)
  for _, i in ipairs (route.profiles) do
    if tonumber (i) == index then
      return true
    end
  end
  return false
end

-- Profile counts as hidden once every connected output it offers is hidden.
local function hiddenProfileIndices (routes)
  local hidden = {}
  local shown = {}
  for _, route in ipairs (connectedOutputs (routes)) do
    local target = hiddenDisplays [displayName (route) or ""] and hidden or shown
    for _, index in ipairs (route.profiles) do
      target [tonumber (index)] = true
    end
  end
  for index in pairs (shown) do
    hidden [index] = nil
  end
  return hidden
end

local function activeProfileIndex (device)
  for p in device:iterate_params ("Profile") do
    local profile = cutils.parseParam (p, "Profile")
    if profile then
      return tonumber (profile.index)
    end
  end
  return nil
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
    local routes = collectRoutes (device)
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

-- ELD arrives shortly after HDMI hotplug.
-- Profile and sink name by then already rest on port without display name.
-- Sink name gets built once, at node creation.

-- Last display names seen per device bound-id.
local seenDisplays = {}

local function displaySignature (routes)
  local parts = {}
  for _, route in ipairs (connectedOutputs (routes)) do
    table.insert (parts, route.name .. "=" .. (displayName (route) or ""))
  end
  table.sort (parts)
  return table.concat (parts, ";")
end

-- Sink created before ELD arrival holds generic PCM name ("HDMI 2") in `alsa.name`.
local function hasStaleSinkName (source, device, routes, active)
  local nodes_om = source:call ("get-object-manager", "node")
  for _, route in ipairs (connectedOutputs (routes)) do
    local display = displayName (route)
    if display and routeFeedsProfile (route, active) then
      for node in nodes_om:iterate {
        type = "node",
        Constraint { "device.id", "=", tostring (device ["bound-id"]) },
      } do
        local pcm = tonumber (node.properties ["card.profile.device"])
        for _, d in ipairs (route.devices or {}) do
          if tonumber (d) == pcm and node.properties ["alsa.name"] ~= display then
            return true
          end
        end
      end
    end
  end
  return false
end

SimpleEventHook {
  name = "device/recheck-profile-on-display-name",
  interests = {
    EventInterest {
      Constraint { "event.type", "=", "device-params-changed" },
      Constraint { "event.subject.param-id", "=", "EnumRoute" },
    },
  },
  execute = function (event)
    local device = event:get_subject ()
    if device.properties ["device.api"] ~= "alsa" then
      return
    end

    local routes = collectRoutes (device)
    local id = device ["bound-id"]
    local signature = displaySignature (routes)
    if seenDisplays [id] == signature then
      return
    end
    seenDisplays [id] = signature

    local active = activeProfileIndex (device)
    if not active then
      return
    end

    local source = event:get_source ()
    if hiddenProfileIndices (routes) [active] then
      log:info (device, "Active profile feeds hidden display, reselecting")
      source:call ("push-event", "select-profile", device, nil)
    elseif hasStaleSinkName (source, device, routes, active) then
      -- Off and back recreates sink under ELD name.
      log:info (device, "Display name arrived after sink creation, rebuilding sink")
      device:set_param ("Profile", Pod.Object {
        "Spa:Pod:Object:Param:Profile", "Profile", index = 0,
      })
      Core.sync (function ()
        source:call ("push-event", "select-profile", device, nil)
      end)
    end
  end
}:register ()
