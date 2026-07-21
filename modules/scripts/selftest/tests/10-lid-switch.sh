# selftest: manual
# selftest-desc: Docked lid close disables eDP-1; lid open restores it.
#
# End-to-end: exercises the physical Lid Switch event and the Hyprland switch
# bind in monitors.lua. Docked only (logind ignores the lid when docked).

run() {
  need hyprctl
  require_docked

  local before after
  before=$(mon_count)

  ask "Close the laptop lid, then press Enter."
  after=$(mon_count)
  [ "$after" -lt "$before" ] || fail "eDP-1 still in layout after lid close ($before -> $after)"
  note "eDP-1 dropped ($before -> $after)."

  ask "Open the lid again, then press Enter."
  after=$(mon_count)
  [ "$after" -eq "$before" ] || fail "eDP-1 did not return after lid open (was $before, now $after)"
  note "eDP-1 restored ($after)."
}
