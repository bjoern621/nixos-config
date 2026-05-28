#!/usr/bin/env bash
set -euo pipefail

# Inputs (set by the systemd unit):
#   KUBECONFIG       - k3s kubeconfig path
#   OUT_DIR          - where the dump file lives
#   NS               - bitwarden namespace
#   PG_POD           - postgres pod name inside NS
#   PG_USER          - postgres user
#   PG_DB            - postgres database
#   PG_AUTH_SECRET   - secret holding postgres credentials (key: password)

mkdir -p "$OUT_DIR"

echo "[bitwarden-dump] starting"

# Logical postgres dump. -Fc is custom format (compressed, pg_restore-friendly).
# The password comes from the kube secret rather than a pod env var, because
# Bitnami's chart renames these env names between releases.
pg_pass=$(kubectl get secret -n "$NS" "$PG_AUTH_SECRET" \
  -o jsonpath='{.data.password}' | base64 -d)

out="$OUT_DIR/postgres.dump"
tmp="$out.partial"

kubectl exec -n "$NS" "$PG_POD" -- \
  env PGPASSWORD="$pg_pass" pg_dump -U "$PG_USER" -d "$PG_DB" -Fc \
  > "$tmp"
mv "$tmp" "$out"

echo "[bitwarden-dump] wrote $out ($(stat -c%s "$out") bytes)"
