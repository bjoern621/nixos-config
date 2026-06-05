{ ... }:

{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    extraConfig = ''
      Include ~/.ssh/config.local
    '';
    # `matchBlocks` is deprecated; `settings` uses upstream OpenSSH directive
    # names. The "*" block is always emitted last as the default host config.
    settings = {
      "*" = {
        AddKeysToAgent = "no";
        Compression = false;
        ForwardAgent = false;
        HashKnownHosts = true;
        ServerAliveCountMax = 3;
        ServerAliveInterval = 0;
      };

      homelab = {
        HostName = "homelab";
        User = "ops";
        IdentityFile = "/home/bjoern/.ssh/id_ed25519";
        IdentitiesOnly = true;
      };

      vmk3s = {
        HostName = "vmk3s";
        User = "ops";
        IdentityFile = "/home/bjoern/.ssh/id_ed25519";
        IdentitiesOnly = true;
      };

      pi-backup-01 = {
        HostName = "pi-backup-01";
        User = "ops";
        IdentityFile = "/home/bjoern/.ssh/id_ed25519";
        IdentitiesOnly = true;
      };

      vm112 = {
        HostName = "vm112.kss.ful.inf.haw-hamburg.de";
        User = "padawan";
        IdentityFile = "/home/bjoern/.ssh/id_ed25519";
        IdentitiesOnly = true;
      };
    };
  };
}
