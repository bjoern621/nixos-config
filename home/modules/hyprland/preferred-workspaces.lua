hl.window_rule({ match = { class = "google-chrome" }, workspace = "1", tile = true })
hl.window_rule({ match = { class = "code" }, workspace = "2", tile = true })
hl.window_rule({ match = { class = "spotify" }, workspace = "3", tile = true })
hl.window_rule({ match = { class = "discord" }, workspace = "3", tile = true })

hl.workspace_rule({ workspace = "1", monitor = "desc:LG Electronics LG ULTRAGEAR 308MAPN9YD64", default = true, persistent = true })
hl.workspace_rule({ workspace = "2", monitor = "desc:LG Electronics LG ULTRAGEAR 308MAVD9YD63", default = true, persistent = true })
hl.workspace_rule({ workspace = "3", persistent = true })
