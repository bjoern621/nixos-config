{ inputs, pkgs, ... }:

# Secrets live encrypted in secrets/, decrypted to /run/secrets at activation.
# Consumers declare sops.secrets.<name> themselves and read
# config.sops.secrets.<name>.path. See modules/cachix-push.nix.
#
# Two age keys, public halves in .sops.yaml:
#   /var/lib/sops-nix/key.txt    host, generated on first activation, decrypts
#   ~/.config/sops/age/keys.txt  admin, edits: sops secrets/<file>.yaml
#
# A new host prints its public key into its own key file: grep it out with
#   sudo grep 'public key' /var/lib/sops-nix/key.txt

{
  imports = [ inputs.sops-nix.nixosModules.sops ];

  environment.systemPackages = [ pkgs.sops ];

  sops.age = {
    keyFile = "/var/lib/sops-nix/key.txt";

    # Creates the key on first activation if absent, so a reinstall only needs
    # the new public key added to .sops.yaml plus `sops updatekeys`.
    generateKey = true;
  };
}
