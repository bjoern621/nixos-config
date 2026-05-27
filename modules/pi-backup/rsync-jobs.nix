{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.pi-backup;
  storage = cfg.storage;

  jobModule = lib.types.submodule (
    { name, ... }:
    {
      options = {
        host = lib.mkOption {
          type = lib.types.str;
          example = "vmk3s";
          description = "Source host (tailnet hostname or IP).";
        };

        remoteUser = lib.mkOption {
          type = lib.types.str;
          default = "backup-pull";
          description = "SSH user on the source host.";
        };

        remotePath = lib.mkOption {
          type = lib.types.str;
          example = "/var/backups/bitwarden/";
          description = ''
            Source-relative path under the rrsync read-only root.
            If the source's rrsync root is `/var/backups/bitwarden`, this should be `./`
            (rrsync rewrites the request relative to the root).
          '';
        };

        schedule = lib.mkOption {
          type = lib.types.str;
          default = "*-*-* 03:30:00";
          description = "systemd OnCalendar expression for the backup timer.";
        };

        randomizedDelay = lib.mkOption {
          type = lib.types.str;
          default = "30min";
          description = "Spread multiple Pis so they don't hit the source simultaneously.";
        };

        keepDaily = lib.mkOption {
          type = lib.types.int;
          default = 30;
          description = "Keep this many daily snapshots before pruning.";
        };

        keepWeekly = lib.mkOption {
          type = lib.types.int;
          default = 12;
          description = "Keep at most this many additional weekly snapshots beyond the daily window.";
        };

        sshKey = lib.mkOption {
          type = lib.types.str;
          default = "/home/ops/.ssh/backup_pull_id_ed25519";
          description = ''
            Filesystem path to the private SSH key for the pull.
            Deployed out-of-band; ops:ops, mode 0400.
            String type (not `path`) so it is not copied into the Nix store.
          '';
        };

        extraRsyncArgs = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Extra arguments appended to the rsync invocation.";
        };

        _name = lib.mkOption {
          type = lib.types.str;
          default = name;
          internal = true;
        };
      };
    }
  );

  pruneScript =
    job:
    pkgs.writeShellApplication {
      name = "pi-backup-prune-${job._name}";
      runtimeInputs = with pkgs; [
        coreutils
        findutils
      ];
      text = ''
        set -euo pipefail

        snap_root=${lib.escapeShellArg "${storage.mountPoint}/snapshots/${job._name}"}
        keep_daily=${toString job.keepDaily}
        keep_weekly=${toString job.keepWeekly}

        if [[ ! -d "$snap_root" ]]; then
          exit 0
        fi

        cd "$snap_root"

        # snapshots are named YYYY-MM-DDTHHMMSSZ; lexicographic == chronological.
        mapfile -t snaps < <(find . -mindepth 1 -maxdepth 1 -type d -name '????-??-??T??????Z' -printf '%f\n' | sort)

        if (( ''${#snaps[@]} <= keep_daily )); then
          exit 0
        fi

        # Keep the newest `keep_daily` unconditionally.
        kept_daily_start=$(( ''${#snaps[@]} - keep_daily ))
        daily_kept=("''${snaps[@]:$kept_daily_start}")

        # From the remainder, keep one per ISO week, up to keep_weekly.
        candidates=("''${snaps[@]:0:$kept_daily_start}")
        weekly_kept=()
        declare -A seen_weeks=()
        # Walk newest-first through the candidates so we keep the latest snapshot per week.
        for (( i = ''${#candidates[@]} - 1; i >= 0; i-- )); do
          snap="''${candidates[i]}"
          date_part="''${snap%%T*}"
          week=$(date -u -d "$date_part" +%G-W%V)
          if [[ -z "''${seen_weeks[$week]:-}" ]]; then
            seen_weeks[$week]=1
            weekly_kept+=("$snap")
            if (( ''${#weekly_kept[@]} >= keep_weekly )); then
              break
            fi
          fi
        done

        # Build the "keep" set as an associative array for O(1) lookup.
        declare -A keep=()
        for s in "''${daily_kept[@]}" "''${weekly_kept[@]}"; do
          keep[$s]=1
        done

        for s in "''${snaps[@]}"; do
          if [[ -z "''${keep[$s]:-}" ]]; then
            echo "[prune] removing $s"
            rm -rf -- "$s"
          fi
        done
      '';
    };

  backupScript =
    job:
    pkgs.writeShellApplication {
      name = "pi-backup-${job._name}";
      runtimeInputs = with pkgs; [
        coreutils
        rsync
        openssh
      ];
      text = ''
        set -euo pipefail

        dest=${lib.escapeShellArg "${storage.mountPoint}/snapshots/${job._name}"}
        mkdir -p "$dest"

        stamp=$(date -u +%Y-%m-%dT%H%M%SZ)
        target="$dest/$stamp"
        latest="$dest/latest"

        link_dest_arg=()
        if [[ -d "$latest" ]]; then
          link_dest_arg=(--link-dest="$latest")
        fi

        known_hosts=/var/lib/pi-backup/known_hosts
        mkdir -p /var/lib/pi-backup
        touch "$known_hosts"

        ssh_opts=(
          -i ${lib.escapeShellArg job.sshKey}
          -o StrictHostKeyChecking=accept-new
          -o UserKnownHostsFile="$known_hosts"
          -o BatchMode=yes
          -o ConnectTimeout=15
        )

        rsync \
          -aAX \
          --numeric-ids \
          --delete \
          --partial-dir=.rsync-partial \
          "''${link_dest_arg[@]}" \
          -e "ssh ''${ssh_opts[*]}" \
          ${lib.escapeShellArg "${job.remoteUser}@${job.host}:${job.remotePath}"} \
          "$target/" \
          ${lib.escapeShellArgs job.extraRsyncArgs}

        ln -snf "$stamp" "$latest"
      '';
    };

  mkService = job: {
    description = "Pull backup snapshot from ${job.host} (${job._name})";

    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];

    unitConfig = {
      # Only attempt to run if the backup volume is actually mounted.
      # The unit succeeds without doing anything if the drive is missing,
      # which is exactly what we want (boot resilience: drive can be absent).
      ConditionPathIsMountPoint = storage.mountPoint;
    };

    serviceConfig = {
      Type = "oneshot";
      User = "root";
      ExecStart = "${backupScript job}/bin/pi-backup-${job._name}";
      ExecStartPost = "${pruneScript job}/bin/pi-backup-prune-${job._name}";

      PrivateTmp = true;
      ProtectSystem = "strict";
      # The key lives under /home/ops/.ssh, so home must stay visible. Read-only
      # keeps the unit from writing anywhere in /home while still allowing
      # the SSH key file to be read.
      ProtectHome = "read-only";
      ReadWritePaths = [
        "${storage.mountPoint}/snapshots/${job._name}"
        "/var/lib/pi-backup"
      ];
      NoNewPrivileges = true;
    };
  };

  mkTimer = job: {
    description = "Schedule for pi-backup-${job._name}";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = job.schedule;
      Persistent = true;
      RandomizedDelaySec = job.randomizedDelay;
    };
  };

  jobsList = lib.attrValues cfg.jobs;
  enabled = storage.enable && cfg.jobs != { };
in
{
  options.services.pi-backup = {
    jobs = lib.mkOption {
      type = lib.types.attrsOf jobModule;
      default = { };
      description = ''
        Per-source backup jobs. Each entry produces one systemd service + timer that
        pulls from `<remoteUser>@<host>:<remotePath>` into
        `<mountPoint>/snapshots/<name>/<UTC-timestamp>/`, with `--link-dest` against
        the previous snapshot for hardlink-based history.
      '';
      example = lib.literalExpression ''
        {
          bitwarden = {
            host = "vmk3s";
            remotePath = "./";
          };
        }
      '';
    };
  };

  config = lib.mkIf enabled {
    # Shared state dir for known_hosts and rsync partial files. 0700 because
    # known_hosts identifies sources we trust, nothing else should read it.
    systemd.tmpfiles.rules = [
      "d /var/lib/pi-backup 0700 root root - -"
    ];

    systemd.services = lib.listToAttrs (
      map (job: {
        name = "pi-backup-${job._name}";
        value = mkService job;
      }) jobsList
    );

    systemd.timers = lib.listToAttrs (
      map (job: {
        name = "pi-backup-${job._name}";
        value = mkTimer job;
      }) jobsList
    );
  };
}
