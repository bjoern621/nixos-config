# Key, token and index service for the screen-sharing relay (cmd/groupd there).
#
# Beside the relay: the signing key lives here and the relay fetches the public half from
# here. One repository, so the path derivation is one copy.
#
# Loopback only. Proxy fronts /groups, /tokens, /streams, /jwks.json.

{
  inputs,
  lib,
  pkgs,
  ...
}:

{
  # Same overlay the relay module applies, named again rather than inherited: this unit's
  # package comes from it, and taking that on faith breaks when the other module moves.
  nixpkgs.overlays = [ inputs.screen-sharing.overlays.default ];

  systemd.services.groupd = {
    description = "screen-sharing group key, token and index service";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];

    serviceConfig = {
      ExecStart = lib.concatStringsSep " " [
        (lib.getExe pkgs.screenshare-groupd)
        "-listen=127.0.0.1:9443"
        # Drawn on first start, kept after. A new key invalidates every token in flight and
        # the relay's cached key set at once.
        "-key=%S/groupd/signing-key.pem"
        # Where the index reads the live stream list. Which streams exist is the relay's
        # fact, so nothing is written here when one starts.
        "-relay-host=127.0.0.1"
        "-relay-api-port=9997"
      ];

      DynamicUser = true;
      StateDirectory = "groupd";
      StateDirectoryMode = "0700";
      Restart = "on-failure";
      RestartSec = "5s";

      # Answers JSON over loopback, reads one file. Nothing else reachable.
      NoNewPrivileges = true;
      CapabilityBoundingSet = "";
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateDevices = true;
      PrivateTmp = true;
      RestrictAddressFamilies = [
        "AF_INET"
        "AF_INET6"
      ];
      RestrictNamespaces = true;
      LockPersonality = true;
      SystemCallFilter = [ "@system-service" ];
      SystemCallArchitectures = "native";
    };
  };
}
