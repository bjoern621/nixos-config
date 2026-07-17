-- https://wiki.hypr.land/Configuring/Basics/Binds/
-- locked: works while an input inhibitor (lockscreen) is active.
-- repeating: repeats while held.
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })

hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })

-- AltGr + key for media controls
hl.bind("MOD5 + P", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("MOD5 + O", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
hl.bind("MOD5 + udiaeresis", hl.dsp.exec_cmd("playerctl next"), { locked = true })
