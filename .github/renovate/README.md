# Patched Renovate

Renovate's nix manager relocks flake inputs to the branch tip and has no way to hold revisions back.
The `Renovate` workflow therefore runs Renovate from source with `nix-aged-lock-maintenance.patch` applied.

The patch makes nix lock file maintenance honor `lockFileMaintenance.minimumReleaseAge` (set in `renovate.json`):
each direct github input is relocked to the newest revision at least that old, resolved through the GitHub commits API.
Only the named github inputs are updated,
so inputs a runner cannot resolve (e.g. `path:`) stay untouched.

The patch targets the Renovate tag pinned in `renovate.yml` and includes its own tests.
