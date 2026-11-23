-- Yazi has no double-click event.
-- Two left clicks on one file within DOUBLE_CLICK_SECONDS count as one.
local DOUBLE_CLICK_SECONDS = 0.4

local last_url, last_time

function Entity:click(event, up)
	if up or event.is_middle then
		return
	end

	local file = self._file
	ya.emit("reveal", { file.url })

	if event.is_right then
		ya.emit("open", {})
		return
	end

	local now = ya.time()
	if last_url == tostring(file.url) and now - last_time < DOUBLE_CLICK_SECONDS then
		last_url = nil
		ya.emit(file.cha.is_dir and "enter" or "open", { hovered = true })
	else
		last_url, last_time = tostring(file.url), now
	end
end
