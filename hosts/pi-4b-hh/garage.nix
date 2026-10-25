{ config, pkgs, ... }:

# Third node of the Garage cluster behind the nix cache (hh-cluster-infra, argocd/applications/garage).
# Same site as garage-0 on vmk3s, which reaches it over a direct LAN path of the tailnet.
# Joining the layout stays a manual step on garage-0 (argocd/applications/garage/docs.md).
#
# Data lives on the LUKS volume of pi-backup, never on the SD card.
# Without that volume mounted the service does not start.

let
  storage = config.services.pi-backup.storage;
  root = "${storage.mountPoint}/garage";
in
{
  assertions = [
    {
      assertion = storage.enable;
      message = "The Garage node needs services.pi-backup.storage: without the volume its data would land on the SD card.";
    }
  ];

  sops.secrets.garage-rpc-secret.sopsFile = ../../secrets/garage.yaml;

  sops.templates."garage.env" = {
    restartUnits = [ "garage.service" ];
    content = ''
      GARAGE_RPC_SECRET=${config.sops.placeholder.garage-rpc-secret}
    '';
  };

  services.garage = {
    enable = true;
    # garage_2 trails garage-0's v2.5.0. Every v2.x node peers with every other.
    package = pkgs.garage_2;
    environmentFile = config.sops.templates."garage.env".path;
    settings = {
      metadata_dir = "${root}/meta";
      data_dir = "${root}/data";
      db_engine = "lmdb";
      # A power cut with unsynced LMDB writes can corrupt its free list (deuxfleurs/garage#1484).
      metadata_fsync = true;

      # Byte-identical to garage-0's garage.toml, or the nodes refuse each other.
      replication_factor = 3;
      consistency_mode = "degraded";

      rpc_bind_addr = "[::]:3901";
      rpc_public_addr = "100.101.226.93:3901";

      s3_api = {
        s3_region = "garage";
        api_bind_addr = "[::]:3900";
      };
      # Metrics for the local telemetry agent. No admin_token, so the admin API refuses every other call.
      admin.api_bind_addr = "127.0.0.1:3903";
    };
  };

  users.users.garage = {
    isSystemUser = true;
    group = "garage";
  };
  users.groups.garage = { };

  services.pi-backup.storage.directories = {
    garage = {
      user = "garage";
      group = "garage";
    };
    "garage/meta" = {
      user = "garage";
      group = "garage";
    };
    "garage/data" = {
      user = "garage";
      group = "garage";
    };
  };

  systemd.services.garage = {
    requires = [ "pi-backup-volume.service" ];
    after = [ "pi-backup-volume.service" ];
    unitConfig = {
      RequiresMountsFor = [ root ];
      ConditionPathIsMountPoint = storage.mountPoint;
    };
    serviceConfig = {
      # The data sits on the backup volume, whose root a dynamic user cannot own.
      DynamicUser = false;
      User = "garage";
      Group = "garage";
      # The pi runs the observability stack next to it.
      MemoryMax = "1G";
    };
  };

  # RPC from the other Garage nodes and S3 from the tailnet. The tailnet policy decides who reaches them.
  networking.firewall.interfaces."tailscale0".allowedTCPPorts = [
    3900
    3901
  ];

  # garage-0 sits behind its node's SNAT and reaches this host only by sending to its LAN address first.
  # The stateful firewall would drop that first packet.
  services.tailscale.openFirewall = true;
}
