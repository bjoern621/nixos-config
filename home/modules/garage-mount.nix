{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:

# Mounts Garage S3 buckets as a normal folder tree.
# One dir per access key.
# Credentials from sops, system level: see modules/garage-mount.nix.

let
  mountPoint = "${config.home.homeDirectory}/mnt/garage";

  # FUSE unmount needs the setuid wrapper.
  # fuse3 package binary is not setuid, direct call always EPERM.
  fusermount3 = "${osConfig.security.wrapperDir}/fusermount3";

  # One remote per access key.
  # Remote carries one credential pair, ListBuckets returns only that key's
  # buckets.
  s3Remote = remote: [
    "RCLONE_CONFIG_${remote}_TYPE=s3"
    "RCLONE_CONFIG_${remote}_PROVIDER=Other"
    # Tailnet name of the Garage sidecar.
    "RCLONE_CONFIG_${remote}_ENDPOINT=http://garage-k8s:3900"
    # Matches s3_region in cluster garage.toml.
    "RCLONE_CONFIG_${remote}_REGION=garage"
    # garage.toml leaves root_domain unset.
    # Buckets address as endpoint/bucket, not endpoint subdomain.
    "RCLONE_CONFIG_${remote}_FORCE_PATH_STYLE=true"
  ];
in
{
  home.packages = [ pkgs.rclone ];

  systemd.user.services.garage-mount = {
    Unit = {
      Description = "Garage S3 buckets mounted at ${mountPoint}";

      # Endpoint is a MagicDNS name, resolves only after tailscaled sets up DNS.
      # User manager cannot order against a system unit, so service fails and
      # retries until name resolves.
      # Default start rate limit gives up during slow boot.
      StartLimitIntervalSec = 0;
    };

    Service = {
      # rclone signals readiness once mount answers.
      # Dead mount reports failed, not active.
      # Type=simple reports active at fork.
      Type = "notify";

      EnvironmentFile = osConfig.sops.templates."garage-rclone.env".path;

      Environment =
        s3Remote "LAPTOP"
        ++ s3Remote "TEAM"
        ++ [
          # combine puts each key's buckets under a dir named after the key.
          "RCLONE_CONFIG_GARAGE_TYPE=combine"
          # Quoted: systemd splits Environment= on whitespace, dropping every
          # upstream after the first.
          ''"RCLONE_CONFIG_GARAGE_UPSTREAMS=bjoern-laptop=laptop: team=team:"''
        ];

      ExecStartPre = [
        # rclone dying without unmount leaves mount point stale.
        # Happens when a file manager holds it open past SIGTERM.
        # mkdir cannot stat stale point, fails ENOTCONN, restart loops forever.
        # Lazy unmount detaches regardless of holder.
        # No-op when nothing mounted.
        "-${fusermount3} -u -z ${mountPoint}"
        "${pkgs.coreutils}/bin/mkdir -p ${mountPoint}"
      ];

      ExecStart = lib.concatStringsSep " " [
        # Upstreams have no bucket, each mounts own bucket list.
        # Grants live on cluster, new bucket appears without rebuild.
        "${pkgs.rclone}/bin/rclone mount garage: ${mountPoint}"
        # S3 has no partial writes, object replaced whole.
        # Without write cache, opening a file for update instead of streaming
        # start to finish fails.
        # Covers most of what a file manager does.
        "--vfs-cache-mode writes"
        # Objects changed elsewhere appear within this window, not served from a
        # stale listing.
        "--dir-cache-time 30s"
        # Unreachable endpoint blocks the caller, it does not error.
        # Each op retries --low-level-retries times, every attempt waits
        # --contimeout for the connect.
        # Defaults 10 x 60s stall a single stat for ~10 min, and every tool
        # walking $HOME stalls with it.
        "--contimeout 5s"
        "--low-level-retries 3"
        # Idle timeout, not total. Flowing transfer keeps resetting it.
        "--timeout 30s"
      ];

      # rclone unmounts on SIGTERM.
      # Covers only exit without unmount.
      # Lazy unmount reports success before mount point is reusable, so
      # ExecStartPre repeats it.
      ExecStop = "-${fusermount3} -u -z ${mountPoint}";

      Restart = "on-failure";
      RestartSec = "5s";
    };

    Install.WantedBy = [ "default.target" ];
  };

  # Puts mount in Nautilus sidebar.
  # Option is a lines type, appends to bookmarks in file-manager.nix instead of
  # replacing.
  xdg.configFile."gtk-3.0/bookmarks".text = lib.mkAfter ''
    file://${mountPoint} Garage
  '';
}
