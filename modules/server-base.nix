# Baseline for a headless server: what a machine needs before it has a job.
#
# Imported by both the bootstrap image and the running system, so the image is the
# final system minus its services.
# Nothing here names a machine, a network or a service, so an unrelated host reuses
# it by writing its own machine file.

{ modulesPath, ... }:

{
  imports = [
    (modulesPath + "/profiles/minimal.nix")
    ./admin-ssh-keys.nix
  ];

  # Deploys arrive as root over ssh: `nixos-rebuild --target-host` copies the closure
  # and runs the activation script that way.
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };
  services.admin-ssh-keys.users = [ "root" ];

  # No account has a password, so the keys above are the only way in.
  # Way back after a network config that does not come up: netcup's rescue system,
  # or re-importing a corrected image.
  users.mutableUsers = false;

  # A remote rebuild evaluates the host flake, and `nix` is the only recovery tool a
  # minimal image carries.
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Journal on a server outlives the session that caused the question.
  services.journald.extraConfig = "SystemMaxUse=500M";

  # Both consoles, because a boot that fails before sshd is only visible on one of
  # them and which one depends on the hypervisor.
  # tty0 comes last, so it stays the console init talks to and the one a VNC-style
  # remote console shows.
  boot.kernelParams = [
    "console=ttyS0,115200"
    "console=tty0"
  ];
}
