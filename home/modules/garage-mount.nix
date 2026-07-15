{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:

# Mounts the Garage S3 bucket as a directory so Nautilus browses it like any
# other folder. Credentials come from sops, which is system-level: see
# modules/garage-mount.nix.

let
  mountPoint = "${config.home.homeDirectory}/mnt/garage";
  bucket = "backup";
in
{
  home.packages = [ pkgs.rclone ];

  systemd.user.services.garage-mount = {
    Unit = {
      Description = "Garage S3 bucket ${bucket} mounted at ${mountPoint}";

      # The endpoint is a MagicDNS name, so it resolves only after tailscaled has
      # set up DNS. Rather than ordering against a system unit, which a user
      # manager cannot do, the service fails and retries until the name resolves.
      # The default start rate limit would give up during a slow boot.
      StartLimitIntervalSec = 0;
    };

    Service = {
      # rclone signals readiness once the mount is answering, so dependants and
      # `systemctl --user start` block until the tree is actually browsable.
      Type = "notify";

      EnvironmentFile = osConfig.sops.templates."garage-rclone.env".path;

      Environment = [
        "RCLONE_CONFIG_GARAGE_TYPE=s3"
        "RCLONE_CONFIG_GARAGE_PROVIDER=Other"
        # The tailnet name of the Garage sidecar. Reaching it needs the tailnet
        # ACL to grant this account port 3900 on tag:k8s-distributed-s3; the tag
        # otherwise only carries the node-to-node grant for RPC on 3901.
        "RCLONE_CONFIG_GARAGE_ENDPOINT=http://garage-k8s:3900"
        # Matches s3_region in the cluster's garage.toml.
        "RCLONE_CONFIG_GARAGE_REGION=garage"
        # garage.toml leaves root_domain unset, so buckets are addressed as
        # endpoint/bucket rather than as a subdomain of the endpoint.
        "RCLONE_CONFIG_GARAGE_FORCE_PATH_STYLE=true"
      ];

      ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p ${mountPoint}";

      ExecStart = lib.concatStringsSep " " [
        "${pkgs.rclone}/bin/rclone mount garage:${bucket} ${mountPoint}"
        # S3 has no partial writes: an object is replaced whole. Without a write
        # cache, anything that opens a file for update rather than streaming it
        # start to finish fails, which covers most of what a file manager does.
        "--vfs-cache-mode writes"
        # Objects changed elsewhere show up within this window instead of being
        # served from a stale listing.
        "--dir-cache-time 30s"
      ];

      # rclone unmounts on SIGTERM. This only covers a crash that leaves the
      # mount point occupied, which would otherwise block the next start.
      ExecStop = "-${pkgs.fuse3}/bin/fusermount3 -u -z ${mountPoint}";

      Restart = "on-failure";
      RestartSec = "5s";
    };

    Install.WantedBy = [ "default.target" ];
  };

  # Puts the mount in the Nautilus sidebar. The option is a lines type, so this
  # appends to the bookmarks in file-manager.nix rather than replacing them.
  xdg.configFile."gtk-3.0/bookmarks".text = lib.mkAfter ''
    file://${mountPoint} Garage
  '';
}
