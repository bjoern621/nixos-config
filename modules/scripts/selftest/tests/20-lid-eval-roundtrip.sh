# selftest-desc: eDP-1 disable/restore eval round-trips (guards the hyprctl-keyword regression).
#
# `hyprctl keyword monitor` is dead under the Lua parser and silently no-ops;
# monitors.lua switched to `hyprctl eval` + hl.monitor. This runs those exact
# commands headless (no physical lid) and asserts the layout actually changes.
# Restore string mirrors monitors.lua. Docked only; briefly blinks eDP-1.

_restore() {
  hyprctl eval 'hl.monitor({ output = "eDP-1", mode = "2944x1840@90", position = "1824x1440", scale = 2, disabled = false })' >/dev/null 2>&1
}

run() {
  need hyprctl
  require_docked

  local base; base=$(mon_count)
  _dropped() { [ "$(mon_count)" -lt "$base" ]; }
  _back()    { [ "$(mon_count)" -eq "$base" ]; }

  hyprctl eval 'hl.monitor({ output = "eDP-1", disabled = true })' >/dev/null 2>&1 || { _restore; fail "disable eval errored"; }
  wait_until 3 _dropped || { _restore; fail "eDP-1 not disabled by eval (hyprctl keyword regression?)"; }

  _restore
  wait_until 3 _back || fail "eDP-1 not restored (was $base, now $(mon_count))"
  note "disable + restore round-tripped ($base -> $((base-1)) -> $base)."
}
