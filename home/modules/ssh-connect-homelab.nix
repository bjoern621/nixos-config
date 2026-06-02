{ ... }:

{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    extraConfig = ''
      Include ~/.ssh/config.local
    '';
    matchBlocks = {
      "*" = {
        addKeysToAgent = "no";
        compression = false;
        forwardAgent = false;
        hashKnownHosts = true;
        serverAliveCountMax = 3;
        serverAliveInterval = 0;
      };

      homelab = {
        hostname = "homelab.local";
        user = "ops";
        identityFile = "/home/bjoern/.ssh/id_ed25519";
        identitiesOnly = true;
      };

      vmk3s = {
        hostname = "vmk3s.local";
        user = "ops";
        identityFile = "/home/bjoern/.ssh/id_ed25519";
        identitiesOnly = true;
      };

      pi-backup-01 = {
        hostname = "pi-backup-01.local";
        user = "ops";
        identityFile = "/home/bjoern/.ssh/id_ed25519";
        identitiesOnly = true;
      };

      vm112 = {
        hostname = "vm112.kss.ful.inf.haw-hamburg.de";
        user = "padawan";
        identityFile = "/home/bjoern/.ssh/id_ed25519";
        identitiesOnly = true;
      };
    };
  };
}
