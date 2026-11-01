{ lib, pkgs, ... }:

# Lends fractal to the pidgemail GitLab group as CI runner through `ci-runners`.
# Everything here stays inert until `ci-runners up`.
let
  cacheDir = "/var/lib/gitlab-runner-fractal/cache";
  ciRunners = pkgs.writeShellApplication {
    name = "ci-runners";
    # docker comes from the system, since it has to match the daemon.
    runtimeInputs = [
      pkgs.coreutils
      pkgs.findutils
      pkgs.glab
      pkgs.gnugrep
      pkgs.gnused
    ];
    text = builtins.readFile ./ci-runners.sh;
  };
  # The window stays open: `down` waits for running jobs and prints its progress.
  ciRunnersToggle = pkgs.makeDesktopItem {
    name = "ci-runners-toggle";
    desktopName = "CI-Runner umschalten";
    comment = "Leiht fractal der pidgemail-Gruppe als GitLab-Runner oder holt ihn zurück";
    exec = "kitty --hold --title CI-Runner ci-runners toggle";
    icon = "gitlab";
    categories = [ "Development" ];
    keywords = [
      "ci"
      "gitlab"
      "runner"
      "pidgemail"
    ];
  };
in
{
  environment.systemPackages = [
    ciRunners
    ciRunnersToggle
  ];

  # Every job slot mounts this at /cache. Nothing caps its size, so the timer below prunes it.
  systemd.tmpfiles.rules = [ "d ${cacheDir} 0755 root root -" ];
  systemd.services.gitlab-ci-cache-prune = {
    description = "Drop CI cache archives no job has read for 14 days";
    serviceConfig.Type = "oneshot";
    script = ''
      ${pkgs.findutils}/bin/find ${cacheDir} -type f -atime +14 -delete
      ${pkgs.findutils}/bin/find ${cacheDir} -mindepth 1 -type d -empty -delete
    '';
  };
  systemd.timers.gitlab-ci-cache-prune = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
    };
  };

  services.openssh = {
    enable = true;
    ports = [ 22 ];
    openFirewall = false;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      AllowUsers = [ "bjoern" ];
    };
  };
  # Off after every boot; `ci-runners up` starts it.
  systemd.services.sshd.wantedBy = lib.mkForce [ ];
  users.users.bjoern.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKjTT3sunIot4AmUwDX3NbdS44g+oz9/enIXuxH2knmq"
  ];
  networking.firewall.interfaces.enp113s0.allowedTCPPorts = [ 22 ];

  security.sudo.extraRules = [
    {
      users = [ "bjoern" ];
      commands =
        map
          (action: {
            command = "/run/current-system/sw/bin/systemctl ${action} sshd.service";
            options = [ "NOPASSWD" ];
          })
          [
            "start"
            "stop"
          ];
    }
  ];

  # Job containers land here via runner `cgroup_parent`.
  # Caps all jobs together, yields CPU to desktop.
  systemd.slices.gitlab-ci.sliceConfig = {
    MemoryHigh = "22G";
    MemoryMax = "24G";
    CPUWeight = 20;
  };
}
