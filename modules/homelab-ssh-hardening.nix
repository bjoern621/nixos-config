{ ... }:

let
  allowedUsers = [ "bjoern" ];
  enableFail2ban = false;
  allowedTcpPorts = [
    22
    139
    445
  ];
  allowedUdpPorts = [
    137
    138
  ];
in
{
  services.openssh = {
    enable = true;
    openFirewall = false;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      PubkeyAuthentication = true;
      AllowUsers = allowedUsers;
    };
    allowSFTP = true;
  };

  services.fail2ban.enable = enableFail2ban;

  networking.firewall = {
    enable = true;
    allowedTCPPorts = allowedTcpPorts;
    allowedUDPPorts = allowedUdpPorts;
  };

  services.journald.extraConfig = ''
    SystemMaxUse=1G
    RuntimeMaxUse=256M
    MaxFileSec=1month
  '';

  system.autoUpgrade = {
    enable = true;
    dates = "03:30";
    randomizedDelaySec = "45min";
    allowReboot = false;
    flake = "/etc/nixos/config";
  };

  environment.etc."homelab/service-placement.md".text = ''
    Service placement policy:
    - Run host-coupled or short-lived services directly in Docker on the host.
    - Preferred direct Docker examples: jellyfin, dyndns, temporary utilities.
    - Run larger multi-service stacks with prod/stage/dev lifecycle in k3s via Argo CD.
  '';
}
