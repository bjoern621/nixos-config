# selftest-desc: Expected keybinds and lid switch binds are registered.
#
# Proves the wiring exists (bind present), not that the target reacts.
# Keys mirror the .lua files in home/modules/hyprland/.

run() {
  need hyprctl jq

  # modmask 64 = SUPER, 0 = none. Pairs mirror home/modules/hyprland/.
  local binds=(
    "0:switch:on:Lid Switch"    # monitors.lua
    "0:switch:off:Lid Switch"   # monitors.lua
    "64:Super_L"                # app-launcher.lua
    "64:V"                      # clipboard-history.lua
    "64:period"                 # emoji-picker.lua
  )

  local missing=() b mask key
  for b in "${binds[@]}"; do
    mask=${b%%:*}
    key=${b#*:}
    bind_exists "$mask" "$key" || missing+=("$b")
  done
  [ "${#missing[@]}" -eq 0 ] || fail "missing binds: ${missing[*]}"
  note "${#binds[@]} binds present."
}
