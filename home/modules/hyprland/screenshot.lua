local mainMod = "SUPER"

-- Screenshot
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd('grim -g "$(slurp)" - | swappy -f -'))
-- Screenshot with frozen screen (Windows-style)
hl.bind(
    mainMod .. " + CTRL + SHIFT + S",
    hl.dsp.exec_cmd('FILE=/tmp/frozen-screenshot.png; wayfreeze --hide-cursor & PID=$!; sleep .1; grim -g "$(slurp)" "$FILE"; kill $PID; swappy -f "$FILE"; rm "$FILE"')
)
