{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:

# Mounts the Garage S3 remote at its root so Nautilus browses it like any other
# folder. Credentials come from sops, which is system-level: see
# modules/garage-mount.nix.

let
  mountPoint = "${config.home.homeDirectory}/mnt/garage";

  # Unmounting FUSE needs the setuid wrapper. The binary in the fuse3 package is
  # not setuid, so calling it directly always fails with EPERM.
  fusermount3 = "${osConfig.security.wrapperDir}/fusermount3";
in
{
  home.packages = [ pkgs.rclone ];

  systemd.user.services.garage-mount = {
    Unit = {
      Description = "Garage S3 buckets mounted at ${mountPoint}";

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

      ExecStartPre = [
        # An rclone that died without unmounting, which happens when a file
        # manager or indexer holds the mount open past SIGTERM, leaves the mount
        # point stale. mkdir cannot even stat a stale mount point, so it fails
        # with ENOTCONN and the restart loop then repeats that failure forever.
        # The lazy unmount detaches a stale mount regardless of who holds it, and
        # is a no-op when nothing is mounted.
        "-${fusermount3} -u -z ${mountPoint}"
        "${pkgs.coreutils}/bin/mkdir -p ${mountPoint}"
      ];

      ExecStart = lib.concatStringsSep " " [
        # A remote with no bucket mounts the bucket list itself, so every bucket
        # the key is granted appears as a top-level directory. Grants live on the
        # cluster rather than in this repo, so a bucket added there shows up here
        # without a rebuild. S3 ListBuckets returns only granted buckets, so this
        # is never a view of the whole server.
        "${pkgs.rclone}/bin/rclone mount garage: ${mountPoint}"
        # S3 has no partial writes: an object is replaced whole. Without a write
        # cache, anything that opens a file for update rather than streaming it
        # start to finish fails, which covers most of what a file manager does.
        "--vfs-cache-mode writes"
        # Objects changed elsewhere show up within this window instead of being
        # served from a stale listing.
        "--dir-cache-time 30s"
      ];

      # rclone unmounts on SIGTERM, so this covers only the case where it exits
      # without doing so. A lazy unmount reports success before the mount point
      # is reusable, so the ExecStartPre above repeats it rather than trusting
      # this to have finished.
      ExecStop = "-${fusermount3} -u -z ${mountPoint}";

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
