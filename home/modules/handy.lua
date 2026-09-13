-- Handy grabs its own hotkey through X11, which Hyprland never feeds.
-- CLI flag reaches the running instance over its single-instance socket
-- and toggles regardless of push_to_talk.
-- No instance running: this opens the app window instead of recording.
hl.bind("SUPER + S", hl.dsp.exec_cmd("handy --toggle-transcription"))
