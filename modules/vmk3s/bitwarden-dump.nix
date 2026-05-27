{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.bitwarden-dump;

  dumpScript = pkgs.writeShellApplication {
    name = "bitwarden-dump";
    runtimeInputs = with pkgs; [
      coreutils
      kubectl
      zstd
      gnutar
      findutils
    ];
    text = ''
      set -euo pipefail

      export KUBECONFIG=${lib.escapeShellArg cfg.kubeconfig}

      out=${lib.escapeShellArg cfg.outputDir}
      ns=${lib.escapeShellArg cfg.namespace}
      pg_pod=${lib.escapeShellArg cfg.postgresPod}
      pg_user=${lib.escapeShellArg cfg.postgresUser}
      pg_db=${lib.escapeShellArg cfg.postgresDatabase}
      pvc_root=${lib.escapeShellArg cfg.pvcStorageRoot}
      keep=${toString cfg.keepDumps}

      stamp=$(date -u +%Y-%m-%dT%H%M%SZ)
      mkdir -p "$out"

      echo "[bitwarden-dump] $stamp - starting"

      # 1. Postgres logical dump. -Fc is custom format (compressed, pg_restore-friendly).
      #    Fetch the app-user password from the auth secret rather than relying
      #    on a specific env-var name inside the pod (Bitnami's chart has
      #    renamed these between versions).
      pg_pass=$(kubectl get secret -n "$ns" ${lib.escapeShellArg cfg.postgresAuthSecret} \
        -o jsonpath='{.data.password}' | base64 -d)
      pg_dump_file="$out/postgres-$stamp.dump"
      tmp_pg="$pg_dump_file.partial"
      kubectl exec -n "$ns" "$pg_pod" -- \
        env PGPASSWORD="$pg_pass" pg_dump -U "$pg_user" -d "$pg_db" -Fc \
        > "$tmp_pg"
      mv "$tmp_pg" "$pg_dump_file"
      echo "[bitwarden-dump] wrote $pg_dump_file ($(stat -c%s "$pg_dump_file") bytes)"

      # 2. Tar the Bitwarden PVCs from the local-path provisioner.
      #    Local-path names directories as pvc-<uid>_<namespace>_<pvc-name>; filter by namespace.
      pvc_tar="$out/pvcs-$stamp.tar.zst"
      tmp_tar="$pvc_tar.partial"
      mapfile -t pvc_dirs < <(find "$pvc_root" -maxdepth 1 -type d -name "pvc-*_''${ns}_*" -printf '%P\n' | sort)
      if (( ''${#pvc_dirs[@]} == 0 )); then
        echo "[bitwarden-dump] WARNING: no PVC dirs found under $pvc_root for namespace $ns" >&2
      fi
      tar --zstd -cf "$tmp_tar" -C "$pvc_root" "''${pvc_dirs[@]}"
      mv "$tmp_tar" "$pvc_tar"
      echo "[bitwarden-dump] wrote $pvc_tar"

      # 3. Sealed-secrets controller's active master key.
      #    Without this, the in-git sealed secrets cannot be decrypted on restore.
      ss_key="$out/sealed-secrets-key-$stamp.yaml"
      tmp_ss="$ss_key.partial"
      kubectl get secret \
        -n ${lib.escapeShellArg cfg.sealedSecretsNamespace} \
        -l ${lib.escapeShellArg cfg.sealedSecretsKeyLabel} \
        -o yaml > "$tmp_ss"
      mv "$tmp_ss" "$ss_key"
      echo "[bitwarden-dump] wrote $ss_key"

      # 4. Retention: keep the newest <keep> triplets (matched by timestamp).
      mapfile -t stamps < <(find "$out" -maxdepth 1 -name 'postgres-*.dump' -printf '%f\n' \
        | sed -E 's/^postgres-(.+)\.dump$/\1/' | sort)
      total=''${#stamps[@]}
      if (( total > keep )); then
        prune_count=$(( total - keep ))
        for s in "''${stamps[@]:0:$prune_count}"; do
          rm -f -- "$out/postgres-$s.dump" "$out/pvcs-$s.tar.zst" "$out/sealed-secrets-key-$s.yaml"
          echo "[bitwarden-dump] pruned $s"
        done
      fi

      echo "[bitwarden-dump] $stamp - done"
    '';
  };
in
{
  options.services.bitwarden-dump = {
    enable = lib.mkEnableOption "Bitwarden self-host disaster-recovery dump (postgres + PVCs + sealed-secrets key)";

    outputDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/backups/bitwarden";
      description = "Where the timestamped dump triplets are written.";
    };

    kubeconfig = lib.mkOption {
      type = lib.types.path;
      default = "/etc/rancher/k3s/k3s.yaml";
      description = "k3s kubeconfig path. Default fits a k3s server install.";
    };

    namespace = lib.mkOption {
      type = lib.types.str;
      default = "bitwarden";
    };

    postgresPod = lib.mkOption {
      type = lib.types.str;
      default = "bitwarden-postgresql-0";
      description = "Name of the postgres pod inside `namespace`.";
    };

    postgresUser = lib.mkOption {
      type = lib.types.str;
      default = "bitwarden";
    };

    postgresDatabase = lib.mkOption {
      type = lib.types.str;
      default = "vault";
    };

    postgresAuthSecret = lib.mkOption {
      type = lib.types.str;
      default = "bitwarden-postgresql-auth";
      description = ''
        Name of the kubernetes Secret holding the postgres credentials.
        The dump script reads the `password` key (Bitnami chart convention).
      '';
    };

    pvcStorageRoot = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/rancher/k3s/storage";
      description = "Where the local-path provisioner stores PVC contents.";
    };

    sealedSecretsNamespace = lib.mkOption {
      type = lib.types.str;
      default = "kube-system";
      description = "Namespace where the sealed-secrets controller runs.";
    };

    sealedSecretsKeyLabel = lib.mkOption {
      type = lib.types.str;
      default = "sealedsecrets.bitnami.com/sealed-secrets-key=active";
      description = "Label selector matching the active sealed-secrets master key Secret.";
    };

    keepDumps = lib.mkOption {
      type = lib.types.int;
      default = 3;
      description = "Local retention (number of triplets). Pis hold the long history.";
    };

    schedule = lib.mkOption {
      type = lib.types.str;
      default = "*-*-* 03:00:00";
      description = "systemd OnCalendar expression. Should fire before the Pi pull window.";
    };
  };

  config = lib.mkIf cfg.enable {
    # The output dir is created by `services.backup-source` when enabled
    # (mode 0750 root:backup-pull, so the rrsync user can read).
    # The dump script also mkdir -p's it as a safety net.

    systemd.services.bitwarden-dump = {
      description = "Dump Bitwarden self-host for off-host pull backup";

      # Don't fire kubectl until the API server is up. A persistent timer
      # firing on early boot would otherwise spam a failure for nothing.
      after = [
        "k3s.service"
        "network-online.target"
      ];
      wants = [ "network-online.target" ];
      requires = [ "k3s.service" ];

      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = "${dumpScript}/bin/bitwarden-dump";
        # k3s.yaml is root-readable by default; the unit needs that and the PVC tree.
        ReadOnlyPaths = [
          cfg.kubeconfig
          cfg.pvcStorageRoot
        ];
        ReadWritePaths = [ cfg.outputDir ];
        PrivateTmp = true;
        ProtectHome = true;
        NoNewPrivileges = true;
      };
    };

    systemd.timers.bitwarden-dump = {
      description = "Schedule for Bitwarden disaster-recovery dump";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.schedule;
        Persistent = true;
        RandomizedDelaySec = "5min";
      };
    };
  };
}
