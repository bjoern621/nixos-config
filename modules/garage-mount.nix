{ config, ... }:

# Credentials for the Garage S3 bucket mounted on this host. The mount itself is
# a user service in home/modules/garage-mount.nix; the split exists because
# sops.secrets and sops.templates are NixOS options that Home Manager cannot
# declare, while the mount belongs to the session that browses it.
#
# Change the keys with: sops secrets/garage.yaml

{
  sops.secrets.garage-s3-access-key-id.sopsFile = ../secrets/garage.yaml;
  sops.secrets.garage-s3-secret-access-key.sopsFile = ../secrets/garage.yaml;

  # rclone takes a remote from RCLONE_CONFIG_<REMOTE>_* variables, so the
  # credentials reach it as an EnvironmentFile. A generated rclone.conf would
  # put the secret key in the world-readable Nix store instead.
  #
  # Owned by bjoern because the consumer is a user service, which runs with no
  # privilege to read the default root-only rendering.
  sops.templates."garage-rclone.env" = {
    owner = "bjoern";
    content = ''
      RCLONE_CONFIG_GARAGE_ACCESS_KEY_ID=${config.sops.placeholder.garage-s3-access-key-id}
      RCLONE_CONFIG_GARAGE_SECRET_ACCESS_KEY=${config.sops.placeholder.garage-s3-secret-access-key}
    '';
  };
}
