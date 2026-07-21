# selftest-desc: Quickshell is running (Bar layer mapped).
#
# Bar stays mapped in the `quickshell` namespace whenever the shell is up.
# Its absence means quickshell died or never started.

run() {
  need hyprctl
  layer_exists quickshell || fail "no quickshell layer mapped (shell not running?)"
  note "quickshell layers present."
}
