-- SIGUSR1 saves whole replay buffer. SIGRTMIN+3 saves its last 60 seconds.
local unit = "gpu-screen-recorder-replay.service"

hl.bind("ALT + F10", hl.dsp.exec_cmd("systemctl --user kill --kill-whom=main --signal=SIGUSR1 " .. unit))
hl.bind("ALT + SHIFT + F10", hl.dsp.exec_cmd("systemctl --user kill --kill-whom=main --signal=SIGRTMIN+3 " .. unit))
