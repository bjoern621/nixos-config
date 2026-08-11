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

      pi-4b-hh = {
        HostName = "pi-4b-hh";
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

      # netcup VPS. Reached by rDNS name, not by address: the name is what SCP
      # keeps pointing at the machine.
      # root, because `nixos-rebuild --target-host` activates as root and the host
      # declares no other account.
      netcup-g12 = {
        HostName = "v2202608396017497611.powersrv.de";
        User = "root";
        IdentityFile = "/home/bjoern/.ssh/id_ed25519";
        IdentitiesOnly = true;
      };
    };
  };
}
