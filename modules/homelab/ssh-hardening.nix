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
    ];
  };

  services.journald.settings.Journal = {
    SystemMaxUse = "1G";
    RuntimeMaxUse = "256M";
    MaxFileSec = "1month";
  };
}
