{ config, lib, ... }:

let
  cfg = config.services.admin-ssh-keys;

  adminKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKjTT3sunIot4AmUwDX3NbdS44g+oz9/enIXuxH2knmq laptop"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINoKgh7gTGHoM9dXQK/2VMJAf/IaExYsCX1/trFrw1qS pc"
  ];
in
{
  options.services.admin-ssh-keys.users = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    example = [ "ops" ];
    description = ''
      Local accounts that receive the admin SSH public keys (laptop + pc).
      The named users must already be declared elsewhere; this module only
      contributes additional `openssh.authorizedKeys.keys` entries.
    '';
  };

  config = {
    users.users = lib.genAttrs cfg.users (_: {
      openssh.authorizedKeys.keys = adminKeys;
    });
  };
}
