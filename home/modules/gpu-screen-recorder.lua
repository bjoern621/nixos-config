-- SIGUSR1 saves whole replay buffer.
hl.bind("ALT + F10", hl.dsp.exec_cmd("systemctl --user kill --kill-whom=main --signal=SIGUSR1 gpu-screen-recorder-replay.service"))
