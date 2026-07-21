#!/usr/bin/env bash
# sysconf-selftest runner. Discover tests, run manual phase first, then
# automated, summarize. Exit non-zero if any test FAILs.
set -uo pipefail

LIB="${SELFTEST_LIB:?}"
TESTS_DIR="${SELFTEST_TESTS:?}"

usage() {
  cat <<'EOF'
sysconf-selftest - live health checks for the running system.

Usage:
  sysconf-selftest [FILTER]     run all tests (only names/desc matching FILTER)
  sysconf-selftest --list       list tests without running
  sysconf-selftest --no-manual  skip tests needing human intervention

Manual tests run first, then automated tests.
Non-tty stdin implies --no-manual. Exit non-zero if any test FAILs.
EOF
}

NO_MANUAL=0; LIST=0; FILTER=""
while [ $# -gt 0 ]; do
  case "$1" in
    --no-manual) NO_MANUAL=1 ;;
    --list|-l)   LIST=1 ;;
    -h|--help)   usage; exit 0 ;;
    -*)          echo "unknown option: $1" >&2; usage >&2; exit 2 ;;
    *)           FILTER="$1" ;;
  esac
  shift
done

# Manual tests prompt on stdin; a pipe/cron has none.
[ -t 0 ] || NO_MANUAL=1

c()  { [ -t 1 ] && tput setaf "$1" 2>/dev/null || true; }
c0() { [ -t 1 ] && tput sgr0 2>/dev/null || true; }

is_manual() { grep -qE '^# selftest: manual' "$1"; }
desc()      { sed -n 's/^# selftest-desc: //p' "$1" | head -1; }
tname()     { basename "$1" .sh; }

matches() {
  [ -z "$FILTER" ] && return 0
  tname "$1" | grep -qiF "$FILTER" && return 0
  desc "$1"   | grep -qiF "$FILTER"
}

manual=(); auto=()
for f in "$TESTS_DIR"/*.sh; do
  [ -e "$f" ] || continue
  matches "$f" || continue
  if is_manual "$f"; then manual+=("$f"); else auto+=("$f"); fi
done

if [ "$LIST" = 1 ]; then
  for f in "${manual[@]}" "${auto[@]}"; do
    tag=auto; is_manual "$f" && tag=manual
    printf '  [%-6s] %-24s %s\n' "$tag" "$(tname "$f")" "$(desc "$f")"
  done
  exit 0
fi

PASS=0; FAIL=0; SKIP=0

run_one() {
  local f="$1" rc=0
  printf '%s%s%s  %s\n' "$(c 4)" "$(tname "$f")" "$(c0)" "$(desc "$f")"
  # Isolate each test: helpers + body in a subshell, exit code = verdict.
  ( set +e; source "$LIB"; source "$f"
    declare -f run >/dev/null || fail "no run() defined"
    run; exit 0 ); rc=$?
  case "$rc" in
    0) PASS=$((PASS+1)); printf '  %sPASS%s\n' "$(c 2)" "$(c0)" ;;
    2) SKIP=$((SKIP+1)) ;;
    *) FAIL=$((FAIL+1)) ;;
  esac
}

if [ "${#manual[@]}" -gt 0 ]; then
  if [ "$NO_MANUAL" = 1 ]; then
    for f in "${manual[@]}"; do
      SKIP=$((SKIP+1))
      printf '%s%s%s  %s\n  %sSKIP%s manual, not run\n' \
        "$(c 4)" "$(tname "$f")" "$(c0)" "$(desc "$f")" "$(c 3)" "$(c0)"
    done
  else
    printf '%s== manual (human intervention) ==%s\n' "$(c 6)" "$(c0)"
    for f in "${manual[@]}"; do run_one "$f"; done
  fi
fi

if [ "${#auto[@]}" -gt 0 ]; then
  printf '%s== automated ==%s\n' "$(c 6)" "$(c0)"
  for f in "${auto[@]}"; do run_one "$f"; done
fi

printf '\n%d passed, %d failed, %d skipped\n' "$PASS" "$FAIL" "$SKIP"
[ "$FAIL" -eq 0 ]
