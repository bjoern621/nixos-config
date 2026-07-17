-- Float common dialog windows (file pickers, save dialogs, etc.)
hl.window_rule({
    match = { title = "(Datei öffnen|Speichern unter|Ordner öffnen|Open File|Open Folder|Save As|Save File)" },
    float = true,
})
hl.window_rule({ match = { class = ".blueman-manager-wrapped" }, float = true })
