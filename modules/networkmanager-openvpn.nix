{
  config,
  pkgs,
  lib,
  ...
}:

# CyberGhost full-tunnel profiles, one per country, declared for every host importing this module.
# Each country holds its own CyberGhost device: own client cert, key and login.
# Change certs or logins: sops secrets/cyberghost.yaml
# Profiles live in /run/NetworkManager/system-connections.
# Edit one in nm-connection-editor and NM copies it to /etc, so menu shows it twice.

let
  servers = {
    netherlands = {
      name = "CyberGhost Niederlande";
      remote = "87-1-nl.cg-dialup.net";
      tcp = false;
    };
    switzerland = {
      name = "CyberGhost Schweiz";
      remote = "87-1-ch.cg-dialup.net";
      tcp = false;
    };
    germany = {
      name = "CyberGhost Deutschland";
      remote = "97-1-de.cg-dialup.net";
      tcp = true;
    };
  };

  envName = country: field: "CYBERGHOST_${lib.toUpper country}_${field}";
  secretPath = name: config.sops.secrets."cyberghost-${name}".path;

  profile = country: server: {
    connection = {
      # Network menu reads transport off this suffix.
      id = "${server.name} ${if server.tcp then "TCP" else "UDP"}";
      type = "vpn";
      autoconnect = false;
    };
    vpn = {
      service-type = "org.freedesktop.NetworkManager.openvpn";
      connection-type = "password-tls";
      remote = server.remote;
      port = 443;
      proto-tcp = if server.tcp then "yes" else "no";
      # Kill switch and VPN proxy module match this name.
      dev = "tun-cyberghost";
      dev-type = "tun";
      auth = "SHA256";
      data-ciphers = "AES-256-GCM:AES-128-GCM:AES-256-CBC";
      data-ciphers-fallback = "AES-256-CBC";
      remote-cert-tls = "server";
      ping = 5;
      ca = secretPath "ca";
      cert = secretPath "${country}-cert";
      key = secretPath "${country}-key";
      # 4: key carries no passphrase, NM asks for none.
      cert-pass-flags = 4;
      username = "$" + envName country "USERNAME";
      # 0: password stored in the profile, no secret agent asked.
      password-flags = 0;
    };
    vpn-secrets.password = "$" + envName country "PASSWORD";
  };

  secretKeys = [
    "ca"
  ]
  ++ lib.concatMap (country: [
    "${country}-cert"
    "${country}-key"
    "${country}-username"
    "${country}-password"
  ]) (lib.attrNames servers);
in
{
  networking.networkmanager.plugins = [ pkgs.networkmanager-openvpn ];

  sops.secrets = lib.listToAttrs (
    map (
      key:
      lib.nameValuePair "cyberghost-${key}" {
        sopsFile = ../secrets/cyberghost.yaml;
        inherit key;
      }
    ) secretKeys
  );

  sops.templates."cyberghost-nm.env" = {
    restartUnits = [ "NetworkManager-ensure-profiles.service" ];
    content = lib.concatStrings (
      lib.mapAttrsToList (country: _: ''
        ${envName country "USERNAME"}=${config.sops.placeholder."cyberghost-${country}-username"}
        ${envName country "PASSWORD"}=${config.sops.placeholder."cyberghost-${country}-password"}
      '') servers
    );
  };

  networking.networkmanager.ensureProfiles = {
    environmentFiles = [ config.sops.templates."cyberghost-nm.env".path ];
    profiles = lib.mapAttrs' (
      country: server: lib.nameValuePair "cyberghost-${country}" (profile country server)
    ) servers;
  };
}
