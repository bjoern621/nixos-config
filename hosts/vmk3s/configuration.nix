{ pkgs, modulesPath, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/scripts/default.nix
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/vda";

  networking.hostName = "vmk3s";

  time.timeZone = "Europe/Berlin";
  i18n.defaultLocale = "de_DE.UTF-8";
  console.keyMap = "de";

  users.users.ops = {
    isNormalUser = true;
    description = "Operations";
    shell = pkgs.zsh;
    initialPassword = "1234";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILZtmzMiCFldBIJpMZAlaTgKOHrZypm7J8YHGnsSzhPC bjoern@nixos"
    ];
    extraGroups = [
      "wheel"
    ];
  };

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  nixpkgs.config.allowUnfree = true;
  system.stateVersion = "25.11";

  # Additional configuration:

  programs.zsh.enable = true;

  services.openssh.enable = true;

  # Kubernetes API server for remote kubectl and GitOps controllers.
  # Argo CD UI is exposed as NodePort on 32443.
  networking.firewall.allowedTCPPorts = [ 6443 32443 31478 31553 ];

  services.k3s = {
    enable = true;
    role = "server";
  };

  environment.systemPackages = with pkgs; [
    k3s
    kubectl
    tldr
  ];
}
