{ lib, ... }:

# Host side of ~/Desktop/ci-runners, which runs the GitLab runner container itself.
# Everything here stays inert until `ci-runners up`.
{
  services.openssh = {
    enable = true;
    ports = [ 22 ];
    openFirewall = false;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      AllowUsers = [ "bjoern" ];
    };
  };
  # Off after every boot; `ci-runners up` starts it.
  systemd.services.sshd.wantedBy = lib.mkForce [ ];
  users.users.bjoern.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKjTT3sunIot4AmUwDX3NbdS44g+oz9/enIXuxH2knmq"
  ];
  networking.firewall.interfaces.enp113s0.allowedTCPPorts = [ 22 ];

  security.sudo.extraRules = [
    {
      users = [ "bjoern" ];
      commands =
        map
          (action: {
            command = "/run/current-system/sw/bin/systemctl ${action} sshd.service";
            options = [ "NOPASSWD" ];
          })
          [
            "start"
            "stop"
          ];
    }
  ];

  # Job containers land here via runner `cgroup_parent`.
  # Caps all jobs together, yields CPU to desktop.
  systemd.slices.gitlab-ci.sliceConfig = {
    MemoryHigh = "22G";
    MemoryMax = "24G";
    CPUWeight = 20;
  };
}
