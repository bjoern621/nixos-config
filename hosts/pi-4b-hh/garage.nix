{ config, pkgs, ... }:

# Third node of the Garage cluster behind the nix cache (hh-cluster-infra, argocd/applications/garage).
# Same site as garage-0 on vmk3s, which reaches it over a direct LAN path of the tailnet.
# Joining the layout stays a manual step on garage-0 (argocd/applications/garage/docs.md).
#
# Blocks live on the LUKS volume of pi-backup, metadata on the SD card.
# LMDB's small random writes saturate the USB disk until the pings to the peers time out.
# Without the volume mounted the service does not start.

let
  storage = config.services.pi-backup.storage;
  root = "${storage.mountPoint}/garage";
  metadataDir = "/var/lib/garage/meta";

  # Copies the metadata from the USB volume once, so the node keeps its key and layout.
  # The copy lands under a temporary name, so an interrupted run starts over without a half database.
  moveMetadata = pkgs.writeShellScript "garage-move-metadata" ''
    set -euo pipefail
    if [[ ! -e ${metadataDir} && -e ${root}/meta/node_key ]]; then
      ${pkgs.rsync}/bin/rsync -a --exclude snapshots ${root}/meta/ ${metadataDir}.partial/
      mv ${metadataDir}.partial ${metadataDir}
    fi
  '';

  # Sets the bloated database aside once, so the node syncs a compact one from its peers.
  # LMDB never shrinks its file, so retries on the slow USB disk grew it far past its rows.
  # Node key, layout and peer list stay, so the node keeps its place in the cluster.
  rebuildMetadata = pkgs.writeShellScript "garage-rebuild-metadata" ''
    set -euo pipefail
    if [[ -d ${metadataDir}/db.lmdb && ! -e ${metadataDir}/db.lmdb.old ]]; then
      mv ${metadataDir}/db.lmdb ${metadataDir}/db.lmdb.old
    fi
  '';
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
      metadata_dir = metadataDir;
      # A snapshot copies the whole database, which the SD card should not take every 6 hours.
      metadata_snapshots_dir = "${root}/meta/snapshots";
      data_dir = "${root}/data";
      db_engine = "lmdb";
      # An fsync per metadata write multiplies the small writes that wear the SD card.
      # Without it a power cut can corrupt LMDB's free list (deuxfleurs/garage#1484).
      # The snapshot restores the metadata. The peers hold every block.
      metadata_fsync = false;
      metadata_auto_snapshot_interval = "6h";

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
      ExecStartPre = [
        "+${moveMetadata}"
        "+${rebuildMetadata}"
      ];
      # The first start copies the metadata off a slow disk.
      TimeoutStartSec = "30min";
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
