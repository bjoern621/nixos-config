-- Workspace 2 windows open floating unless class starts with `code`.
-- Requires as rules.10, before rules.20-preferred-workspaces: its `tile`
-- rules overwrite floating for apps that don't want float.
hl.window_rule({
    name = "exclusive-ws2-float",
    match = { workspace = "2", class = "negative:^code" },
    float = true,
})
