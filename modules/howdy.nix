{ config, pkgs, ... }:

{
  # Howdy is a face recognition authentication system for Linux. It can be used as a PAM (Pluggable Authentication Modules) module to allow users to log in using their face.
  services.howdy = {
    enable = true;
    control = "sufficient"; # Face recognition is enough to authenticate (password as fallback)
    settings = {
      video = {
        device_path = "/dev/video2"; # Integrated IR camera
        dark_threshold = 30;
        timeout = 5; # Seconds to wait for a face to be recognized
      };
      core = {
        abort_if_lid_closed = true;
        abort_if_ssh = true;
      };
    };
  };

  # IR emitter must be enabled for the IR camera to work in the dark.
  # Run `sudo -E linux-enable-ir-emitter configure -m` after first rebuild to calibrate.
  services.linux-enable-ir-emitter.enable = true;
}
