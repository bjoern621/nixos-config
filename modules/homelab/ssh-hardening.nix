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
      # 139 # NetBIOS Session Service (legacy SMB/CIFS over NetBIOS)
      # 445 # SMB/CIFS over TCP (Windows file sharing)
    ];
    allowedUDPPorts = [
      # 137 # NetBIOS Name Service (name resolution for SMB/CIFS)
      # 138 # NetBIOS Datagram Service (browser announcements/legacy SMB traffic)
    ];
  };

  services.journald.extraConfig = ''
    SystemMaxUse=1G
    RuntimeMaxUse=256M
    MaxFileSec=1month
  '';
}
