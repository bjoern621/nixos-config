{ ... }:

{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
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
        hostname = "192.168.178.29";
        user = "ops";
        identityFile = "/home/bjoern/.ssh/id_ed25519";
        identitiesOnly = true;
      };

      k3s = {
        hostname = "192.168.178.80";
        user = "ops";
        identityFile = "/home/bjoern/.ssh/id_ed25519";
        identitiesOnly = true;
      };
    };
  };
}
