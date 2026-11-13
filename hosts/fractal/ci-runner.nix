{
  config,
  lib,
  pkgs,
  ...
}:

# Lends fractal to the pidgemail GitLab group as CI runner through `ci-runners`.
# Everything here stays inert until `ci-runners up`.
let
  cacheDir = "/var/lib/gitlab-runner-fractal/cache";
  netns = "docker-ci";
  netnsPath = "/run/netns/${netns}";
  ciDaemonConfig = (pkgs.formats.json { }).generate "docker-ci-daemon.json" (
    config.virtualisation.docker.daemon.settings
    // {
      hosts = [ "unix:///run/docker-ci.sock" ];
      data-root = "/var/lib/docker-ci";
      exec-root = "/run/docker-ci";
      pidfile = "/run/docker-ci.pid";
      cgroup-parent = "gitlab-ci.slice";
    }
  );
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
            command = "/run/current-system/sw/bin/systemctl ${action}";
            options = [ "NOPASSWD" ];
          })
          [
            "start sshd.service"
            "stop sshd.service"
            "start docker-ci.service"
            "stop docker-ci.service"
          ];
    }
  ];

  # CI Docker daemon in network namespace of its own.
  # Each container adds veth plus IPv6 link-local address to daemon's namespace.
  # In root namespace, Chrome aborts requests in flight with ERR_NETWORK_CHANGED on every such change.
  # pasta carries egress over host sockets: root namespace sees no link or address of CI.
  systemd.services.docker-ci-netns = {
    description = "Network namespace of the CI Docker daemon";
    partOf = [ "docker-ci.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      # Clears a namespace that a crash left behind.
      ExecStartPre = "-${pkgs.iproute2}/bin/ip netns delete ${netns}";
      ExecStart = "${pkgs.iproute2}/bin/ip netns add ${netns}";
      ExecStop = "${pkgs.iproute2}/bin/ip netns delete ${netns}";
    };
  };
  systemd.services.docker-ci-pasta = {
    description = "Internet access for the CI Docker daemon's network namespace";
    bindsTo = [ "docker-ci-netns.service" ];
    after = [ "docker-ci-netns.service" ];
    partOf = [ "docker-ci.service" ];
    serviceConfig = {
      Slice = "gitlab-ci.slice";
      Restart = "on-failure";
      # No port forwarding either way.
      # Without --no-map-gw, a job reaches the host's loopback services through the gateway address.
      ExecStart = "${pkgs.passt}/bin/pasta --foreground --quiet --config-net --no-map-gw -t none -u none -T none -U none --netns ${netnsPath}";
    };
  };
  systemd.services.docker-ci = {
    description = "Docker daemon for CI jobs";
    requires = [
      "docker-ci-netns.service"
      "docker-ci-pasta.service"
    ];
    after = [
      "docker-ci-netns.service"
      "docker-ci-pasta.service"
    ];
    inherit (config.systemd.services.docker) path;
    # Mirrors docker.service from the Docker package.
    serviceConfig = {
      Type = "notify";
      ExecStart = "${config.virtualisation.docker.package}/bin/dockerd --config-file=${ciDaemonConfig}";
      ExecReload = "${pkgs.procps}/bin/kill -s HUP $MAINPID";
      NetworkNamespacePath = netnsPath;
      Slice = "gitlab-ci.slice";
      Restart = "on-failure";
      LimitNPROC = "infinity";
      LimitCORE = "infinity";
      TasksMax = "infinity";
      Delegate = true;
      KillMode = "process";
      OOMScoreAdjust = -500;
    };
  };

  # Holds the CI daemon, its egress and, through its `cgroup-parent`, every container it starts.
  # Caps all jobs together, yields CPU to desktop.
  systemd.slices.gitlab-ci.sliceConfig = {
    MemoryHigh = "22G";
    MemoryMax = "24G";
    CPUWeight = 20;
  };
}
