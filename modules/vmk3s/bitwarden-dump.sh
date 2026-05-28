#!/usr/bin/env bash
set -euo pipefail

# Inputs (set by the systemd unit):
#   KUBECONFIG       - k3s kubeconfig path
#   OUT_DIR          - where timestamped dump pairs are written
#   NS               - bitwarden namespace
#   PG_POD           - postgres pod name inside NS
#   PG_USER          - postgres user
#   PG_DB            - postgres database
#   PG_AUTH_SECRET   - secret holding postgres credentials (key: password)
#   PVC_ROOT         - local-path provisioner storage root
#   KEEP             - number of dump pairs to retain locally

stamp=$(date -u +%Y-%m-%dT%H%M%SZ)
mkdir -p "$OUT_DIR"

echo "[bitwarden-dump] $stamp - starting"

# 1. Postgres logical dump. -Fc is custom format (compressed, pg_restore-friendly).
#    Fetch the app-user password from the auth secret rather than relying
#    on a specific env-var name inside the pod (Bitnami's chart has
#    renamed these between versions).
pg_pass=$(kubectl get secret -n "$NS" "$PG_AUTH_SECRET" \
  -o jsonpath='{.data.password}' | base64 -d)
pg_dump_file="$OUT_DIR/postgres-$stamp.dump"
tmp_pg="$pg_dump_file.partial"
kubectl exec -n "$NS" "$PG_POD" -- \
  env PGPASSWORD="$pg_pass" pg_dump -U "$PG_USER" -d "$PG_DB" -Fc \
  > "$tmp_pg"
mv "$tmp_pg" "$pg_dump_file"
echo "[bitwarden-dump] wrote $pg_dump_file ($(stat -c%s "$pg_dump_file") bytes)"

# 2. Tar the Bitwarden PVCs from the local-path provisioner.
#    Local-path names directories as pvc-<uid>_<namespace>_<pvc-name>; filter by namespace.
pvc_tar="$OUT_DIR/pvcs-$stamp.tar.zst"
tmp_tar="$pvc_tar.partial"
mapfile -t pvc_dirs < <(find "$PVC_ROOT" -maxdepth 1 -type d -name "pvc-*_${NS}_*" -printf '%P\n' | sort)
if (( ${#pvc_dirs[@]} == 0 )); then
  echo "[bitwarden-dump] WARNING: no PVC dirs found under $PVC_ROOT for namespace $NS" >&2
fi
tar --zstd -cf "$tmp_tar" -C "$PVC_ROOT" "${pvc_dirs[@]}"
mv "$tmp_tar" "$pvc_tar"
echo "[bitwarden-dump] wrote $pvc_tar"

# 3. Retention: keep the newest KEEP dump pairs (matched by timestamp).
mapfile -t stamps < <(find "$OUT_DIR" -maxdepth 1 -name 'postgres-*.dump' -printf '%f\n' \
  | sed -E 's/^postgres-(.+)\.dump$/\1/' | sort)
total=${#stamps[@]}
if (( total > KEEP )); then
  prune_count=$(( total - KEEP ))
  for s in "${stamps[@]:0:$prune_count}"; do
    rm -f -- "$OUT_DIR/postgres-$s.dump" "$OUT_DIR/pvcs-$s.tar.zst"
    echo "[bitwarden-dump] pruned $s"
  done
fi

echo "[bitwarden-dump] $stamp - done"
