# sysconf-selftest test contract + helpers.
# Sourced into each test subshell by runner.sh.
#
# Test file = magic-comment metadata + run():
#   # selftest: manual         -> human intervention; runs in first phase
#   # selftest-desc: <text>     -> one-line description (shown + --list + filter)
# run() ends by returning (PASS) or calling skip/fail (SKIP/FAIL).

# Color only on a tty.
_c()  { [ -t 1 ] && tput setaf "$1" 2>/dev/null || true; }
_c0() { [ -t 1 ] && tput sgr0 2>/dev/null || true; }

# Verdicts. Print one line, exit the test subshell.
# fail -> 1, skip -> 2, return -> 0 (PASS).
fail() { printf '  %sFAIL%s %s\n' "$(_c 1)" "$(_c0)" "$*"; exit 1; }
skip() { printf '  %sSKIP%s %s\n' "$(_c 3)" "$(_c0)" "$*"; exit 2; }
note() { printf '       %s\n' "$*"; }

# Guards. Skip (not fail) when a precondition is absent.
need() { for b in "$@"; do command -v "$b" >/dev/null 2>&1 || skip "missing $b"; done; }
mon_count() { hyprctl monitors 2>/dev/null | grep -c '^Monitor ' || true; }
require_docked() { [ "$(mon_count)" -gt 1 ] || skip "not docked (needs external monitor)"; }

# wait_until <secs> <cmd...>: poll every 0.1s until cmd succeeds; non-zero on timeout.
# hyprctl state settles asynchronously, so poll instead of a fixed sleep.
wait_until() { local n=$(( ${1} * 10 )); shift; while [ "$n" -gt 0 ]; do "$@" && return 0; sleep 0.1; n=$((n-1)); done; return 1; }

# Assertions.
# bind_exists <modmask> <key>: bind registered. modmask 64 = SUPER, 0 = none.
# `hyprctl binds` splits modmask and key across lines, so match the JSON pair.
bind_exists()  { hyprctl binds -j 2>/dev/null | jq -e --argjson m "$1" --arg k "$2" 'any(.[]; .modmask == $m and .key == $k)' >/dev/null 2>&1; }
layer_exists() { hyprctl layers 2>/dev/null | grep -qF "$1"; }

# Manual interaction. Only reached in the manual phase, where stdin is a tty.
ask()     { printf '  %s>%s %s' "$(_c 6)" "$(_c0)" "$*"; read -r _; }
confirm() { local a; printf '  %s>%s %s [y/N] ' "$(_c 6)" "$(_c0)" "$*"; read -r a; [ "$a" = y ] || [ "$a" = Y ]; }
