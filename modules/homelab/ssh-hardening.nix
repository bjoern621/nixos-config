{ ... }:

{
  services.openssh = {
    enable = true;
    openFirewall = false;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      PubkeyAuthentication = true;
      AllowUsers = [ "ops" ];
    };
    allowSFTP = true;
  };

  services.fail2ban.enable = false;

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      22 # SSH (remote shell and SFTP)
      139 # NetBIOS Session Service (legacy SMB/CIFS over NetBIOS)
      445 # SMB/CIFS over TCP (Windows file sharing)
    ];
    allowedUDPPorts = [
      137 # NetBIOS Name Service (name resolution for SMB/CIFS)
      138 # NetBIOS Datagram Service (browser announcements/legacy SMB traffic)
    ];
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
